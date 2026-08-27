/// 3D 射线拾取（纯 Dart，可单测）。
///
/// 屏幕坐标 → 世界射线：对 (proj * view) 求逆，把 NDC 近/远点反投影回
/// 世界空间。命中检测提供水平面求交（地砖平面）与 AABB slab 求交（立牌）。
library;

import 'package:vector_math/vector_math.dart';

class Ray3D {
  Ray3D({required Vector3 origin, required Vector3 direction})
      : origin = origin.clone(),
        direction = direction.normalized();

  final Vector3 origin;
  final Vector3 direction;

  Vector3 at(double t) => origin + direction * t;
}

/// 由屏幕点构造世界射线。
///
/// [screenPoint] 为逻辑像素坐标（左上角原点）；[viewportSize] 为视口
/// 逻辑尺寸；[viewMatrix]/[projectionMatrix] 来自 CameraComponent3D。
Ray3D screenPointToRay({
  required Vector2 screenPoint,
  required Vector2 viewportSize,
  required Matrix4 viewMatrix,
  required Matrix4 projectionMatrix,
}) {
  final ndcX = (screenPoint.x / viewportSize.x) * 2 - 1;
  final ndcY = 1 - (screenPoint.y / viewportSize.y) * 2;

  final vp = projectionMatrix.clone()..multiply(viewMatrix);
  final invVp = Matrix4.zero()..copyInverse(vp);

  Vector3 unproject(double ndcZ) {
    final v = invVp.transform3(Vector3(ndcX, ndcY, ndcZ));
    // vector_math 为列主序：w = 矩阵第 3 行 · (x, y, z, 1)。
    final w = invVp.entry(3, 0) * ndcX +
        invVp.entry(3, 1) * ndcY +
        invVp.entry(3, 2) * ndcZ +
        invVp.entry(3, 3);
    return v / w;
  }

  final near = unproject(-1);
  final far = unproject(1);
  return Ray3D(origin: near, direction: far - near);
}

/// 射线与水平面 y = [planeY] 求交；不相交（平行或反向）返回 null。
double? intersectPlaneY(Ray3D ray, double planeY) {
  final dy = ray.direction.y;
  if (dy.abs() < 1e-9) return null;
  final t = (planeY - ray.origin.y) / dy;
  return t > 0 ? t : null;
}

/// 射线与 AABB 求交（slab 法）；命中返回进入距离 t，否则 null。
double? intersectAabb(Ray3D ray, Aabb3 box) {
  var tMin = 0.0;
  var tMax = double.infinity;
  for (var axis = 0; axis < 3; axis++) {
    final o = ray.origin.storage[axis];
    final d = ray.direction.storage[axis];
    final min = box.min.storage[axis];
    final max = box.max.storage[axis];
    if (d.abs() < 1e-9) {
      if (o < min || o > max) return null;
      continue;
    }
    var t1 = (min - o) / d;
    var t2 = (max - o) / d;
    if (t1 > t2) {
      final tmp = t1;
      t1 = t2;
      t2 = tmp;
    }
    if (t1 > tMin) tMin = t1;
    if (t2 < tMax) tMax = t2;
    if (tMin > tMax) return null;
  }
  return tMin;
}
