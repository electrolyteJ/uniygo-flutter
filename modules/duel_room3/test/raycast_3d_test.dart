import 'package:duel_room3/scene3d/raycast_3d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  // 与默认相机一致的 view/proj（position (0,7.6,8.8) → target (0,0,-0.4)，fovY 50）。
  final view = Matrix4.identity();
  setViewMatrix(view, Vector3(0, 7.6, 8.8), Vector3(0, 0, -0.4), Vector3(0, 1, 0));
  const aspect = 16 / 9;
  final proj = Matrix4.identity();
  setPerspectiveMatrix(proj, 50 * 3.14159265 / 180, aspect, 0.1, 200);
  final viewport = Vector2(1600, 900);

  group('screenPointToRay', () {
    test('屏幕中心的射线穿过相机 target 附近', () {
      final ray = screenPointToRay(
        screenPoint: Vector2(800, 450),
        viewportSize: viewport,
        viewMatrix: view,
        projectionMatrix: proj,
      );
      final t = intersectPlaneY(ray, 0);
      expect(t, isNotNull);
      final hit = ray.at(t!);
      // target 投影到 y=0 平面上应为 (0, 0, -0.4) 附近
      expect(hit.x, closeTo(0, 1e-3));
      expect(hit.z, closeTo(-0.4, 1e-3));
    });

    test('屏幕左侧点命中世界 x<0', () {
      final ray = screenPointToRay(
        screenPoint: Vector2(200, 450),
        viewportSize: viewport,
        viewMatrix: view,
        projectionMatrix: proj,
      );
      final hit = ray.at(intersectPlaneY(ray, 0)!);
      expect(hit.x, lessThan(-1));
    });
  });

  group('intersectAabb', () {
    test('命中返回正 t，未命中返回 null', () {
      final box = Aabb3.minMax(Vector3(-0.5, 0, -0.5), Vector3(0.5, 1, 0.5));
      final hitRay = Ray3D(origin: Vector3(0, 0.5, 3), direction: Vector3(0, 0, -1));
      expect(intersectAabb(hitRay, box), closeTo(2.5, 1e-6));
      final missRay = Ray3D(origin: Vector3(5, 0.5, 3), direction: Vector3(0, 0, -1));
      expect(intersectAabb(missRay, box), isNull);
      final backRay = Ray3D(origin: Vector3(0, 0.5, -3), direction: Vector3(0, 0, -1));
      expect(intersectAabb(backRay, box), isNull);
    });
  });
}
