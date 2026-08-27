/// 轻量 3D 补间引擎（纯 Dart，可单测）。
///
/// 场景层所有动画（立牌移动/缩放/翻转、光束伸缩、飞行轨迹）统一走这里：
/// 每帧 [TweenEngine3D.tick] 推进，完成时触发回调并自动移除。
library;

import 'package:vector_math/vector_math.dart';

typedef EaseFn = double Function(double t);

double easeLinear(double t) => t;
double easeInOutCubic(double t) =>
    t < 0.5 ? 4 * t * t * t : 1 - 4 * (1 - t) * (1 - t) * (1 - t) * 0.25 * 4;
double easeOutCubic(double t) {
  final u = 1 - t;
  return 1 - u * u * u;
}

double easeOutBack(double t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final u = t - 1;
  return 1 + c3 * u * u * u + c1 * u * u;
}

/// 单个补间：Vector3 从 [from] 到 [to]。
class Vector3Tween {
  Vector3Tween({
    required this.from,
    required this.to,
    required this.duration,
    required this.apply,
    this.ease = easeInOutCubic,
    this.onComplete,
    this.arcHeight = 0,
  });

  final Vector3 from;
  final Vector3 to;
  final double duration;

  /// 每帧应用插值结果。
  final void Function(Vector3 value) apply;
  final EaseFn ease;
  final void Function()? onComplete;

  /// >0 时在中途附加向上的抛物线弧（抽牌/送墓飞行用）。
  final double arcHeight;

  double elapsed = 0;

  /// 推进 [dt]；返回是否已完成。
  bool tick(double dt) {
    elapsed += dt;
    final raw = duration <= 0 ? 1.0 : (elapsed / duration).clamp(0.0, 1.0);
    final k = ease(raw);
    final value = from + (to - from) * k;
    if (arcHeight > 0) {
      value.y += 4 * arcHeight * raw * (1 - raw);
    }
    apply(value);
    if (raw >= 1) {
      onComplete?.call();
      return true;
    }
    return false;
  }
}

/// 标量补间（透明度/缩放系数等）。
class ScalarTween {
  ScalarTween({
    required this.from,
    required this.to,
    required this.duration,
    required this.apply,
    this.ease = easeInOutCubic,
    this.onComplete,
  });

  final double from;
  final double to;
  final double duration;
  final void Function(double value) apply;
  final EaseFn ease;
  final void Function()? onComplete;

  double elapsed = 0;

  bool tick(double dt) {
    elapsed += dt;
    final raw = duration <= 0 ? 1.0 : (elapsed / duration).clamp(0.0, 1.0);
    apply(from + (to - from) * ease(raw));
    if (raw >= 1) {
      onComplete?.call();
      return true;
    }
    return false;
  }
}

/// 补间调度器：场景组件每帧 [tick]。
class TweenEngine3D {
  final List<Vector3Tween> _vectorTweens = [];
  final List<ScalarTween> _scalarTweens = [];

  void addVector(Vector3Tween tween) => _vectorTweens.add(tween);
  void addScalar(ScalarTween tween) => _scalarTweens.add(tween);

  bool get isIdle => _vectorTweens.isEmpty && _scalarTweens.isEmpty;

  void tick(double dt) {
    // 双列表皆空时直接返回，避免每帧两份 List.of() 空快照分配。
    if (isIdle) return;
    // onComplete 回调可能新增补间（如攻击前扑的返回段），先推进快照、
    // 再统一移除已完成的，避免遍历中修改列表。
    for (final tween in List<Vector3Tween>.of(_vectorTweens)) {
      if (tween.tick(dt)) _vectorTweens.remove(tween);
    }
    for (final tween in List<ScalarTween>.of(_scalarTweens)) {
      if (tween.tick(dt)) _scalarTweens.remove(tween);
    }
  }

  void clear() {
    _vectorTweens.clear();
    _scalarTweens.clear();
  }
}
