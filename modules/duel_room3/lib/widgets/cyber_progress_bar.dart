import 'package:flutter/material.dart';

import '../theme/cyber_intro_tokens.dart';

/// 赛博风**细条进度条**（槽 + 填充 + 微发光），全房间共用。
///
/// 设计稿里的三处进度条（07 载入页底部 1360×3、05b-05e 等候页面 320×3、
/// 06 预加载任务行）形态是同一个：一条 3px 的暗槽，填充部分带一点辉光。
/// 差异只在**宽度、槽色、填充色、圆角**上，因此收敛成一个组件 + 参数。
///
/// 本组件**只管画**：
/// - 不带文案（label / 百分比由调用方排版，载入页与等候页的字号不同）；
/// - 不持有 `AnimationController`（由谁驱动进度是调用方的事）；
/// - 不做 `LayoutBuilder` 之外的布局假设，宽度取父级约束。
///
/// 用法：
/// ```dart
/// CyberProgressBar(progress: 0.64)                       // 载入页
/// CyberProgressBar(progress: v, height: 3, radius: 2)    // 等候页
/// ```
class CyberProgressBar extends StatelessWidget {
  const CyberProgressBar({
    super.key,
    required this.progress,
    this.height = 3,
    this.color = CyberIntroTokens.cyan,
    this.slotColor = CyberIntroTokens.slot,
    this.radius = 0,
    this.glow = true,
  });

  /// 0 → 1，越界自动钳位。
  final double progress;

  /// 条高。设计稿统一 3。
  final double height;

  /// 填充色。
  final Color color;

  /// 槽色（未填充部分）。
  final Color slotColor;

  /// 圆角。载入页 0，等候页 2。
  final double radius;

  /// 填充部分是否带辉光。载入页开，等候页可关。
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 必须用 LayoutBuilder 的 maxWidth 手算宽度：父级若在
          // Stack/Positioned 里，FractionallySizedBox 会拿到无限约束。
          final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
          final bar = Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: slotColor)),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: w * value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    boxShadow: glow
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.55),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          );
          return radius > 0
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: bar,
                )
              : bar;
        },
      ),
    );
  }
}
