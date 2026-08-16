import 'package:flutter/material.dart';

/// 抽牌动画层：独立子组件经 [AnimatedBuilder] 订阅 [AnimationController]，
/// 逐帧重建只发生在本组件内部；页面仅在动画开始/结束时 setState。
///
/// 必须直接位于页面的 Stack children 中（内部产出 Positioned）。
class DrawCardAnimation extends StatelessWidget {
  final AnimationController controller;
  final Rect source;
  final Rect target;
  final Widget cardVisual;

  const DrawCardAnimation({
    super.key,
    required this.controller,
    required this.source,
    required this.target,
    required this.cardVisual,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final progress = Curves.easeOutCubic.transform(controller.value);
        final rect = Rect.lerp(source, target, progress)!;
        return Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(
            child: Opacity(opacity: 1.0 - progress * 0.15, child: cardVisual),
          ),
        );
      },
    );
  }
}

/// 攻击动画的「去-停-回」进度映射：t ∈ [0,1] → 插值系数 c ∈ [0,1]。
///
/// - [0, 0.42) 冲刺（easeOut）
/// - [0.42, 0.58] 停留（恒 1，停在目标点）
/// - [0.58, 1.0] 回位（easeInOut）
///
/// 抽成纯函数便于单测，避免把曲线细节埋在 widget 里。
double attackProgress(double t) {
  if (t < 0.42) {
    return Curves.easeOut.transform((t / 0.42).clamp(0.0, 1.0));
  }
  if (t < 0.58) {
    return 1.0;
  }
  return 1.0 - Curves.easeInOut.transform(((t - 0.58) / 0.42).clamp(0.0, 1.0));
}

/// 怪兽攻击动画层：独立子组件经 [AnimatedBuilder] 订阅 [AnimationController]，
/// 逐帧重建只发生在本组件内部；页面仅在动画开始/结束时 setState。
class AttackAnimation extends StatelessWidget {
  final AnimationController controller;
  final Rect source;
  final Rect target;
  final Widget cardVisual;

  const AttackAnimation({
    super.key,
    required this.controller,
    required this.source,
    required this.target,
    required this.cardVisual,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final progress = attackProgress(controller.value);
        final rect = Rect.lerp(source, target, progress)!;
        return Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(child: cardVisual),
        );
      },
    );
  }
}
