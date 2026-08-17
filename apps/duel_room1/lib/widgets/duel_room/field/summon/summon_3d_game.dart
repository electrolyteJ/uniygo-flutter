import 'dart:ui';

import 'package:flame_3d/camera.dart';
import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/game.dart';

import 'cyber_dragon_rig.dart';

/// 电子龙召唤演出的独立 3D 场景（透明 overlay 叠在 2D 场地上方）。
///
/// 与 [DuelFlameGame] 完全隔离：自己的 [World3D] + [CameraComponent3D] +
/// 灯光，只活一次演出（约 [CyberDragonRig.duration] 秒），演完经
/// [onDone] 通知页面移除 overlay。
class Summon3DGame extends FlameGame3D<World3D, CameraComponent3D> {
  Summon3DGame({required Vector3 dragonTarget, required this.onDone})
    : _dragonTarget = dragonTarget,
      super(
        world: World3D(),
        camera: CameraComponent3D(
          position: Vector3(0, 1.6, 5.4),
          target: Vector3(0, -0.1, 0),
          fovY: 45,
        ),
      );

  /// 龙落地的世界坐标（由页面把卡槽屏幕坐标换算到 z=0 平面）。
  final Vector3 _dragonTarget;

  /// 演出结束回调（页面移除 overlay）。
  final void Function() onDone;

  /// 相机参数暴露给页面做屏幕→世界换算。
  static const double cameraDistance = 5.5; // |(0,1.6,5.4) - (0,-0.1,0)| ≈ 5.66，取近似
  static const double fovYDegrees = 45;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await world.addAll([
      LightComponent.ambient(intensity: 0.45),
      LightComponent.point(
        position: Vector3(2.5, 3.5, 3.5),
        intensity: 1.3,
      ),
      LightComponent.point(
        position: Vector3(-2.5, 1.0, -2.0),
        color: const Color(0xFF88AAFF),
        intensity: 0.6,
      ),
      CyberDragonRig(onCompleted: onDone, basePosition: _dragonTarget),
    ]);
  }
}
