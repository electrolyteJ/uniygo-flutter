import 'dart:math' as math;

import 'package:flame_3d/core.dart';
import 'package:flame_3d/resources.dart';

/// 召唤门圆环网格（XZ 平面内的环形片，法线 +Y）。
///
/// flame_3d 无 TorusMesh，用 Surface 手写顶点：内外两圈三角带。
class RingMesh extends Mesh {
  RingMesh({
    required double innerRadius,
    required double outerRadius,
    int segments = 48,
    Material? material,
  }) {
    final vertices = <Vertex>[];
    final indices = <int>[];
    for (var i = 0; i <= segments; i++) {
      final theta = i * math.pi * 2 / segments;
      final c = math.cos(theta);
      final s = math.sin(theta);
      // 外圈 u=0，内圈 u=1（纹理径向渐变可用）
      vertices.add(Vertex(
        position: Vector3(outerRadius * c, 0, outerRadius * s),
        texCoord: Vector2(0, i / segments),
        normal: Vector3(0, 1, 0),
      ));
      vertices.add(Vertex(
        position: Vector3(innerRadius * c, 0, innerRadius * s),
        texCoord: Vector2(1, i / segments),
        normal: Vector3(0, 1, 0),
      ));
    }
    for (var i = 0; i < segments; i++) {
      final a = i * 2;
      indices.addAll([a, a + 1, a + 2, a + 2, a + 1, a + 3]);
    }
    addSurface(
      Surface(vertices: vertices, indices: indices, material: material),
    );
  }
}
