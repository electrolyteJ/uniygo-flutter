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

  /// 震屏偏移（撤销重放用）与 tween 合成 scratch（免每帧分配）。
  final Vector3 _shakeOffset = Vector3.zero();
  bool _shakeApplied = false;
  final Vector3 _scratchPos = Vector3.zero();
  final Vector3 _scratchTarget = Vector3.zero();

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

  /// 震屏（duration/intensity 非正直接忽略：除零防御）。
  ///
  /// 偏移不写回基准位：每帧先撤掉上一帧偏移，tween 合成后再加上本帧
  /// 新偏移；shake 结束后相机精确停在基准位，不会漂移（旧实现把随机
  /// 偏移累加进 position，空闲机位多次震屏后明显漂离默认位）。
  void shake({double intensity = 0.25, double duration = 0.35}) {
    if (duration <= 0 || intensity <= 0) return;
    _shakeIntensity = intensity;
    _shakeDuration = duration;
    _shakeTime = duration;
  }

  /// 每帧驱动。
  void tick(CameraComponent3D camera, double dt) {
    // 撤掉上一帧震屏偏移（tween 分支的 setFrom 覆盖与撤销幂等）。
    if (_shakeApplied) {
      camera.position.sub(_shakeOffset);
      _shakeApplied = false;
    }
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
      // scratch 复用，避免每帧 new 两个 Vector3。
      camera.position.setFrom(
        _scratchPos
          ..setFrom(shot.position)
          ..sub(_fromPos)
          ..scale(k)
          ..add(_fromPos),
      );
      camera.target.setFrom(
        _scratchTarget
          ..setFrom(shot.target)
          ..sub(_fromTarget)
          ..scale(k)
          ..add(_fromTarget),
      );
      if (t >= 1) _active = null;
    }
    if (_shakeTime > 0) {
      _shakeTime -= dt;
      if (_shakeTime > 0) {
        final decay = (_shakeTime / _shakeDuration).clamp(0.0, 1.0);
        final amp = _shakeIntensity * decay;
        _shakeOffset.setValues(
          (_rng.nextDouble() - 0.5) * 2 * amp,
          (_rng.nextDouble() - 0.5) * 2 * amp,
          0,
        );
        camera.position.add(_shakeOffset);
        _shakeApplied = true;
      } else {
        _shakeTime = 0; // 结束：本帧起不加偏移，相机停在基准位
      }
    }
  }
}
