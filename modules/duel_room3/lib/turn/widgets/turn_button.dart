import 'package:flutter/material.dart';

import '../../theme/duel_style.dart';
import '../../theme/hud_theme.dart';

/// 先攻 / 后攻选择按钮。
class TurnButton extends StatelessWidget {
  const TurnButton({
    super.key,
    required this.width,
    required this.height,
    required this.label,
    required this.caption,
    required this.enabled,
    required this.onTap,
  });

  final double width;
  final double height;
  final String label;
  final String caption;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFF0A1F2F) : const Color(0xFF09121C),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: enabled ? duelCyan : duelLine),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: HudTheme.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: enabled ? duelCyan : duelSub,
                ),
              ),
              const SizedBox(height: 2),
              Text(caption, style: HudTheme.caption.copyWith(fontSize: 8)),
            ],
          ),
        ),
      ),
    );
  }
}
