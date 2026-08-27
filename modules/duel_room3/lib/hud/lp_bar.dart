import 'package:flutter/material.dart';

import 'hud_theme.dart';

/// 竖向 LP 条（MDPro3 风格：屏幕左右边缘，带渐变与发光）。
class LpBar extends StatelessWidget {
  const LpBar({
    super.key,
    required this.playerName,
    required this.lp,
    required this.maxLp,
    required this.alignLeft,
    this.isSelf = false,
  });

  final String playerName;
  final int lp;
  final int maxLp;
  final bool alignLeft;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final ratio = maxLp <= 0 ? 0.0 : (lp / maxLp).clamp(0.0, 1.0);
    // 按比例分档而非绝对阈值：match/tag 初始 LP 16000（MSG_START 下发），
    // 绝对阈值会让半血 8000 仍显示满血色。
    final barColor = ratio > 0.5
        ? HudTheme.cyan
        : ratio > 0.25
            ? HudTheme.gold
            : HudTheme.danger;
    return Container(
      width: 118,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: HudTheme.glowPanel(
        glow: isSelf ? HudTheme.cyan : HudTheme.danger,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            playerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HudTheme.caption.copyWith(color: HudTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          // 数字
          Text(
            '$lp',
            style: TextStyle(
              color: barColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: barColor, blurRadius: 12)],
            ),
          ),
          const SizedBox(height: 4),
          // 条形
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}
