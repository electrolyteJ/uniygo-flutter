import 'package:flutter/material.dart';

import '../../theme/duel_style.dart';
import '../../theme/hud_theme.dart';

/// 猜拳手势按钮（石头 / 剪刀 / 布）。
class HandButton extends StatelessWidget {
  const HandButton({
    super.key,
    required this.width,
    required this.height,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final double width;
  final double height;
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? duelCyan : duelSub;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF09121C),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: duelLine),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: height * 0.4),
              SizedBox(height: height * 0.1),
              Text(
                label,
                style: HudTheme.caption.copyWith(
                  fontSize: 9,
                  color: enabled ? duelTextColor : duelSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
