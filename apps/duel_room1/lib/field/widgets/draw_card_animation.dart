import 'package:flutter/material.dart';

/// 抽卡动画层：卡从卡组槽位飞入手牌栏。
///
/// 独立子组件经 [AnimatedBuilder] 订阅 [AnimationController]，逐帧重建
/// 只发生在本组件内部；页面仅在动画开始/结束时 setState。
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
