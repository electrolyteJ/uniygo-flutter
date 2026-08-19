import 'dart:convert';
import 'dart:typed_data';

import 'package:flame/flame.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/model.dart';
import 'package:flame_3d/parser.dart';
import 'package:flame_3d/resources.dart';

/// 用 flame_3d 内建解析器加载 cardlive 包内的 glb/gltf 模型。
///
/// 为什么要包一层：
/// 1. 键名前缀：[ModelParser.parse] 经 Flame.assets 读字节，会把默认
///    前缀 assets/ 拼到传入路径前；而 cardlive 包内资产打进宿主 App 后
///    实际键名带 packages/cardlive/ 前缀（如
///    packages/cardlive/assets/models/cyber_dragon.glb），裸路径加载
///    必然报 Unable to load asset。这里解析期间临时切换前缀，
///    finally 还原（仓库内没有其他 Flame.assets 使用方，
///    切换窗口无并发消费者）。
/// 2. 索引回绕：flame_3d Surface 的索引缓冲是 Uint16List，单 Surface
///    顶点数超过 65535 时索引值按 2^16 回绕，渲染成破碎尖刺
///    （电子龙 32 万顶点正属此列）。解析后检测超大 Surface 并重拆，
///    见 [_fixOversizedSurfaces]。
///
/// [packageAssetPath] 相对 cardlive 资产根（assets/ 目录之后），
/// 如 models/cyber_dragon.glb。
Future<Model> loadCardliveModel(String packageAssetPath) async {
  final previous = Flame.assets.prefix;
  Flame.assets.prefix = 'packages/cardlive/assets/';
  try {
    final model = await ModelParser.parse(packageAssetPath);
    await _fixOversizedSurfaces(model, packageAssetPath);
    _clampHighMetallic(model);
    return model;
  } finally {
    Flame.assets.prefix = previous;
  }
}

/// 金属度钳制：flame_3d 无 IBL/emissive，metallic≈1 的材质（如
/// DamagedHelmet）漫反射为零、镜面无环境可反，渲染成纯黑。
/// 鉴赏场景保立体感优先：把高金属度压到 0.25。
void _clampHighMetallic(Model model) {
  for (final node in model.nodes.values) {
    final mesh = node.mesh;
    if (mesh == null) continue;
    for (final surface in mesh.surfaces) {
      final material = surface.material;
      if (material is SpatialMaterial && material.metallic > 0.9) {
        material.metallic = 0.25;
      }
    }
  }
}

/// 单个 Surface 允许的最大顶点数（索引缓冲 Uint16 上限）。
const int _maxVertsPerSurface = 65535;

/// 检测并修复超过 [_maxVertsPerSurface] 顶点的 Surface：
/// 重读 glb 几何（网格局部空间，不烘焙节点变换——ModelComponent
/// 绘制时自带节点变换），按三角形去重拆成多个小 Surface，
/// 材质（含解析器解码好的贴图）沿用解析结果。
///
/// 对应关系假设：解析器按（节点 -> 网格 -> 图元）顺序生成 Surface，
/// 与 glb JSON 中 meshes[].primitives[] 的顺序一一对应。
Future<void> _fixOversizedSurfaces(Model model, String path) async {
  final meshes = [
    for (final node in model.nodes.values)
      if (node.mesh != null) node.mesh!,
  ];
  final oversized = meshes.any(
    (m) => m.surfaces.any((s) => s.vertexCount > _maxVertsPerSurface),
  );
  if (!oversized) return;

  // parse 阶段已把同一键读进 AssetsCache，此处直接命中缓存。
  final bytes = await Flame.assets.readBinaryFile(path);
  final prims = _readGlbGeometry(bytes);

  var cursor = 0;
  for (final mesh in meshes) {
    mesh.updateSurfaces((surfaces) {
      final rebuilt = <Surface>[];
      for (final surface in surfaces) {
        final prim = prims[cursor++];
        if (surface.vertexCount <= _maxVertsPerSurface) {
          rebuilt.add(surface);
        } else {
          rebuilt.addAll(_chunkSurface(prim, surface.material));
        }
      }
      surfaces
        ..clear()
        ..addAll(rebuilt);
    });
  }
}

/// glb 单个图元的几何数据（网格局部空间）。
class _PrimitiveGeo {
  _PrimitiveGeo({
    required this.positions,
    required this.indices,
    this.normals,
    this.uvs,
  });

  /// 顶点坐标（xyz 连续排列）。
  final Float32List positions;

  /// 三角形索引（uint32）。
  final Uint32List indices;

  /// 顶点法线（xyz 连续排列），可空。
  final Float32List? normals;

  /// 顶点 UV（uv 连续排列），可空。
  final Float32List? uvs;
}

/// 从 glb 字节里读所有 meshes[].primitives[] 的几何数组。
/// （flame_3d 解析器交给 Surface 的索引在构造时被截断成 Uint16，
/// 这里从原始字节重新读取完整 uint32 索引。）
List<_PrimitiveGeo> _readGlbGeometry(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (data.getUint32(0, Endian.little) != 0x46546C67) {
    throw const FormatException('不是合法的 glb（magic 非 glTF）');
  }
  final jsonLength = data.getUint32(12, Endian.little);
  final json =
      jsonDecode(utf8.decode(bytes.sublist(20, 20 + jsonLength)))
          as Map<String, Object?>;
  final binStart = 20 + jsonLength + 8;

  final bufferViews = json['bufferViews']! as List;
  final accessors = json['accessors']! as List;

  int accessorOffset(Map accessor) {
    final view = bufferViews[(accessor['bufferView'] as num).toInt()] as Map;
    return binStart +
        ((view['byteOffset'] as num?)?.toInt() ?? 0) +
        ((accessor['byteOffset'] as num?)?.toInt() ?? 0);
  }

  Float32List floats(int accessorIndex) {
    final accessor = accessors[accessorIndex] as Map;
    final count = (accessor['count'] as num).toInt();
    return Float32List.view(
      bytes.buffer,
      bytes.offsetInBytes + accessorOffset(accessor),
      count * _componentCount(accessor['type'] as String),
    );
  }

  Uint32List uints(int accessorIndex) {
    final accessor = accessors[accessorIndex] as Map;
    if ((accessor['componentType'] as num).toInt() != 5125) {
      throw const FormatException('索引 accessor 需为 uint32');
    }
    return Uint32List.view(
      bytes.buffer,
      bytes.offsetInBytes + accessorOffset(accessor),
      (accessor['count'] as num).toInt(),
    );
  }

  final result = <_PrimitiveGeo>[];
  for (final mesh in json['meshes']! as List) {
    final primitives = (mesh as Map)['primitives'] as List;
    for (final primitive in primitives) {
      final map = primitive as Map;
      final attributes = map['attributes'] as Map;
      result.add(
        _PrimitiveGeo(
          positions: floats((attributes['POSITION'] as num).toInt()),
          normals: attributes.containsKey('NORMAL')
              ? floats((attributes['NORMAL'] as num).toInt())
              : null,
          uvs: attributes.containsKey('TEXCOORD_0')
              ? floats((attributes['TEXCOORD_0'] as num).toInt())
              : null,
          indices: uints((map['indices'] as num).toInt()),
        ),
      );
    }
  }
  return result;
}

int _componentCount(String type) => switch (type) {
  'SCALAR' => 1,
  'VEC2' => 2,
  'VEC3' => 3,
  'VEC4' => 4,
  'MAT4' => 16,
  _ => throw FormatException('不支持的 accessor 类型: $type'),
};

/// 把一个超大图元按三角形去重拆成多个 <= [_maxVertsPerSurface] 顶点的
/// Surface，材质沿用 [material]。
List<Surface> _chunkSurface(_PrimitiveGeo prim, Material material) {
  final chunks = <Surface>[];
  var vertices = <Vertex>[];
  var indices = <int>[];
  final remap = <int, int>{};

  void flush() {
    if (vertices.isEmpty) return;
    chunks.add(
      Surface(vertices: vertices, indices: indices, material: material),
    );
    vertices = <Vertex>[];
    indices = <int>[];
    remap.clear();
  }

  for (var t = 0; t < prim.indices.length; t += 3) {
    final a = prim.indices[t];
    final b = prim.indices[t + 1];
    final c = prim.indices[t + 2];
    final newCount = [a, b, c].where((v) => !remap.containsKey(v)).length;
    if (vertices.length + newCount > _maxVertsPerSurface) flush();
    for (final v in [a, b, c]) {
      indices.add(
        remap.putIfAbsent(v, () {
          vertices.add(
            Vertex(
              position: Vector3(
                prim.positions[v * 3],
                prim.positions[v * 3 + 1],
                prim.positions[v * 3 + 2],
              ),
              texCoord: prim.uvs != null
                  ? Vector2(prim.uvs![v * 2], prim.uvs![v * 2 + 1])
                  : Vector2.zero(),
              normal: prim.normals != null
                  ? Vector3(
                      prim.normals![v * 3],
                      prim.normals![v * 3 + 1],
                      prim.normals![v * 3 + 2],
                    )
                  : null,
            ),
          );
          return vertices.length - 1;
        }),
      );
    }
  }
  flush();
  return chunks;
}
