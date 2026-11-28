import 'package:flutter/material.dart';

import '../../theme/duel_style.dart';

/// 猜拳手势圆盘。
class HandCircle extends StatelessWidget {
  const HandCircle({
    super.key,
    required this.size,
    this.hand,
    this.highlight = false,
  });

  final double size;
  final int? hand;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlight ? const Color(0xFF0A1F2F) : const Color(0xFF09121C),
        border: Border.all(color: highlight ? duelCyan : duelLine),
      ),
      alignment: Alignment.center,
      child: hand == null
          ? Text(
              '?',
              style: TextStyle(
                color: highlight ? duelCyan : duelSub,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w700,
              ),
            )
          : Icon(
              _handIcon(hand!),
              color: highlight ? duelCyan : duelTextColor,
              size: size * 0.4,
            ),
    );
  }
}

IconData _handIcon(int hand) => switch (hand) {
  1 => Icons.content_cut,
  2 => Icons.circle_outlined,
  3 => Icons.back_hand_outlined,
  _ => Icons.help_outline,
};
