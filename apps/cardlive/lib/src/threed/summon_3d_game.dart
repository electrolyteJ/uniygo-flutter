import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_3d/camera.dart';
import 'package:flame_3d/components.dart';
import 'package:flame_3d/game.dart';
import 'package:flame_3d/graphics.dart';
import 'package:flame_3d/model.dart';

import '../../cardlive.dart';
import 'cyber_dragon_rig.dart';
import 'glb_dragon_rig.dart';

/// 电子龙召唤演出的独立 3D 场景（透明 overlay 叠在 2D 场地上方）。
///
/// 与决斗场地的 Flame 游戏完全隔离：自己的 [World3D] +
/// [CameraComponent3D] + 灯光，默认只活一次演出（约
/// [CyberDragonRig.duration] 秒），演完经 [onDone] 通知页面移除
/// overlay；[loop] 为 true 时循环播放（cardlive 鉴赏模式）。
class Summon3DGame extends FlameGame3D<World3D, CameraComponent3D> {
  Summon3DGame({
    required this.dragonTarget,
    required this.onDone,
    this.loop = false,
    this.metalColor,
    this.jointColor,
    this.glowColor,
    this.modelAsset,
    this.onReady,
  }) : super(
         world: World3D(),
         camera: CameraComponent3D(
           position: Vector3(0, 1.6, 5.4),
           target: Vector3(0, -0.1, 0),
           fovY: 45,
         ),
       );

  /// 龙落地的世界坐标（由页面把卡槽屏幕坐标换算到 z=0 平面）。
  final Vector3 dragonTarget;

  /// 演出结束回调（页面移除 overlay）。[loop] 模式下不会被调用。
  final void Function() onDone;

  /// 鉴赏模式：演出循环播放。
  final bool loop;

  /// 可选换色（null 时用电子龙默认配色）。
  final Color? metalColor;
  final Color? jointColor;
  final Color? glowColor;

  /// 可选 glb 模型资产（相对 cardlive 包根，如
  /// assets/models/cyber_dragon.glb）；非 null 时用 [GlbDragonRig]
  /// 加载真实模型代替程序化机械龙。
  final String? modelAsset;

  /// 场景（含模型加载）就绪回调；鉴赏页用它收起 loading。
  final void Function()? onReady;

  /// 相机参数暴露给页面做屏幕→世界换算。
  static const double cameraDistance =
      5.5; // |(0,1.6,5.4) - (0,-0.1,0)| ≈ 5.66，取近似
  static const double fovYDegrees = 45;

  /// 屏幕坐标 → 相机注视平面（z=0）的世界坐标。
  ///
  /// 透视相机正对原点：可见高 h = 2·dist·tan(fov/2)，宽按 aspect 展开。
  static Vector3 screenToWorld(Offset screenPos, Size size) {
    final h = 2 * cameraDistance * math.tan(fovYDegrees * math.pi / 360);
    final w = h * (size.width / size.height);
    final worldX = (screenPos.dx / size.width - 0.5) * w;
    final worldY =
        (0.5 - screenPos.dy / size.height) * h - 0.1; // 对齐 camera target.y
    return Vector3(worldX, worldY, 0);
  }

  /// 全局只初始化一次的 GpuBackend（幂等）。
  ///
  /// flame_3d 要求渲染前 `await GpuBackend.initialize()`：它会异步预载所有
  /// `.shaderbundle`；漏掉时首帧材质会抛 "Shader library ... has not been
  /// loaded"。
  static Future<void>? _gpuBackendReady;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await (_gpuBackendReady ??= GpuBackend.initialize());
    await world.addAll([
      LightComponent.ambient(intensity: 0.45),
      LightComponent.point(position: Vector3(2.5, 3.5, 3.5), intensity: 1.3),
      LightComponent.point(
        position: Vector3(-2.5, 1.0, -2.0),
        color: const Color(0xFF88AAFF),
        intensity: 0.6,
      ),
    ]);
    await glbshow(world, modelAsset);
    onReady?.call();
  }
}

glbshow(World3D world, String? modelAsset) async {
  if (modelAsset == null) return;
  final model = await loadCardliveModel(modelAsset);
  final targetHeight = 1.7;
  // 归一化：按节点变换后的包围盒缩放到 targetHeight，
  // x/z 居中，底面落在 y=0。
  final bounds = _modelBounds(model);
  final size = bounds.max - bounds.min;
  final fitScale = size.y > 1e-6 ? targetHeight / size.y : 1.0;
  final centerX = (bounds.min.x + bounds.max.x) / 2;
  final centerZ = (bounds.min.z + bounds.max.z) / 2;
  final _model = ModelComponent(
    model: model,
    scale: Vector3.all(fitScale),
    position: Vector3(
      -centerX * fitScale,
      -bounds.min.y * fitScale,
      -centerZ * fitScale,
    ),
  );
  await world.add(_model);
}

Aabb3 _modelBounds(Model model) {
  final processed = model.processNodes(AnimationState());
  var minX = double.infinity;
  var minY = double.infinity;
  var minZ = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  var maxZ = double.negativeInfinity;
  for (final node in processed.values) {
    final mesh = node.node.mesh;
    if (mesh == null) continue;
    final box = mesh.aabb;
    for (final x in [box.min.x, box.max.x]) {
      for (final y in [box.min.y, box.max.y]) {
        for (final z in [box.min.z, box.max.z]) {
          final p = node.combinedTransform.transform3(Vector3(x, y, z));
          minX = math.min(minX, p.x);
          minY = math.min(minY, p.y);
          minZ = math.min(minZ, p.z);
          maxX = math.max(maxX, p.x);
          maxY = math.max(maxY, p.y);
          maxZ = math.max(maxZ, p.z);
        }
      }
    }
  }
  return Aabb3.minMax(Vector3(minX, minY, minZ), Vector3(maxX, maxY, maxZ));
}
