/// CameraRig 震屏回归测试（S1/S7）。
///
/// 背景：旧 shake 把随机偏移累加进 camera.position——有运镜时 tween 每帧
/// setFrom 掩盖问题，空闲机位下 shake 结束后相机停在漂移位置不再回弹
///（LP 变化震屏是最常触发路径）。修复后偏移不写回基准，shake 结束
/// 精确回位。
library;

import 'package:duel_room3/scene3d/camera_rig.dart';
import 'package:flame_3d/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  CameraComponent3D newCamera() => CameraComponent3D(
    position: Vector3(0, 3.2, 6.4),
    target: Vector3(0, 0.6, 0),
  );

  group('震屏', () {
    test('shake 结束后相机回到原位（空闲机位，无 active shot）', () {
      final camera = newCamera();
      final origin = camera.position.clone();
      final rig = CameraRig();

      rig.shake(intensity: 0.5, duration: 0.3);
      var drifted = false;
      for (var i = 0; i < 20; i++) {
        rig.tick(camera, 0.05); // 1.0s，shake 0.3s 结束
        if ((camera.position - origin).length > 1e-9) drifted = true;
      }
      expect(drifted, isTrue, reason: 'shake 期间应有偏移');
      // 结束后精确回位（允许浮点噪声）
      expect((camera.position - origin).length, lessThan(1e-6));
    });

    test('连续多次 shake 不累积漂移', () {
      final camera = newCamera();
      final origin = camera.position.clone();
      final rig = CameraRig();
      for (var round = 0; round < 5; round++) {
        rig.shake(intensity: 0.3, duration: 0.2);
        for (var i = 0; i < 10; i++) {
          rig.tick(camera, 0.05);
        }
      }
      expect((camera.position - origin).length, lessThan(1e-6));
    });

    test('运镜 + 震屏叠加：结束后停在运镜目标位', () {
      final camera = newCamera();
      final rig = CameraRig();
      final shotPos = Vector3(1, 4, 5);
      rig.flyTo(CameraShot(position: shotPos, target: Vector3.zero(), duration: 0.4));
      rig.shake(intensity: 0.4, duration: 0.2);
      for (var i = 0; i < 20; i++) {
        rig.tick(camera, 0.05);
      }
      expect((camera.position - shotPos).length, lessThan(1e-6));
      expect(rig.isAnimating, isFalse);
    });

    test('duration=0 不产生 NaN 也不移动相机（除零防御）', () {
      final camera = newCamera();
      final origin = camera.position.clone();
      final rig = CameraRig();
      rig.shake(intensity: 0.5, duration: 0); // 旧实现 decay=0/0=NaN
      rig.tick(camera, 0.05);
      expect(camera.position.x.isNaN, isFalse);
      expect((camera.position - origin).length, 0);
    });
  });
}
