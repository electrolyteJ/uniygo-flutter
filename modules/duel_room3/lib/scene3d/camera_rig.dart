import 'dart:math' as math;

import 'package:flame_3d/camera.dart';
import 'package:flame_3d/core.dart';
import 'package:flutter/animation.dart' show Curves;

import 'field_3d_layout.dart';

/// 一段运镜：目标机位 + 注视点 + 时长。
class CameraShot {
  const CameraShot({
    required this.position,
    required this.target,
    this.duration = 0.6,
  });

  final Vector3 position;
  final Vector3 target;
  final double duration;
}

/// 相机运镜器：对 [CameraComponent3D.position]/[target] 做缓动，
/// 支持镜头队列（演出分镜）与震屏。由 Game 每帧 [tick] 驱动。
///
/// 不 import Riverpod / biz，保持场景层纯净。
class CameraRig {
  CameraRig();

  final List<CameraShot> _queue = [];
  CameraShot? _active;
  Vector3 _fromPos = Vector3.zero();
  Vector3 _fromTarget = Vector3.zero();
  double _elapsed = 0;

  double _shakeTime = 0;
  double _shakeDuration = 0;
  double _shakeIntensity = 0;
  final math.Random _rng = math.Random();

  bool get isAnimating => _active != null || _queue.isNotEmpty;

  /// 立即回到默认机位。
  void snapToDefault(CameraComponent3D camera) {
    _queue.clear();
    _active = null;
    camera.position.setFrom(Field3DLayout.defaultCameraPosition);
    camera.target.setFrom(Field3DLayout.defaultCameraTarget);
  }

  /// 排队一段运镜（追加到队尾）。
  void enqueue(CameraShot shot) => _queue.add(shot);

  /// 清空队列并立即飞往指定机位。
  void flyTo(CameraShot shot) {
    _queue.clear();
    _queue.add(shot);
  }

  /// 回默认机位（缓动）。
  void flyHome({double duration = 0.7}) {
    flyTo(CameraShot(
      position: Field3DLayout.defaultCameraPosition.clone(),
      target: Field3DLayout.defaultCameraTarget.clone(),
      duration: duration,
    ));
  }

  /// 震屏。
  void shake({double intensity = 0.25, double duration = 0.35}) {
    _shakeIntensity = intensity;
    _shakeDuration = duration;
    _shakeTime = duration;
  }

  /// 每帧驱动。
  void tick(CameraComponent3D camera, double dt) {
    if (_active == null && _queue.isNotEmpty) {
      _active = _queue.removeAt(0);
      _fromPos = camera.position.clone();
      _fromTarget = camera.target.clone();
      _elapsed = 0;
    }
    final shot = _active;
    if (shot != null) {
      _elapsed += dt;
      final t = shot.duration <= 0 ? 1.0 : (_elapsed / shot.duration).clamp(0, 1);
      final k = Curves.easeInOutCubic.transform(t.toDouble());
      camera.position.setFrom(_fromPos + (shot.position - _fromPos) * k);
      camera.target.setFrom(_fromTarget + (shot.target - _fromTarget) * k);
      if (t >= 1) _active = null;
    }
    if (_shakeTime > 0) {
      _shakeTime -= dt;
      final decay = (_shakeTime / _shakeDuration).clamp(0.0, 1.0);
      final amp = _shakeIntensity * decay;
      camera.position.x += (_rng.nextDouble() - 0.5) * 2 * amp;
      camera.position.y += (_rng.nextDouble() - 0.5) * 2 * amp;
    }
  }
}
