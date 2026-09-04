import 'package:flutter/material.dart';

/// godot RoomOverlay 风格按钮：深色底 Color(0.04,0.07,0.13,0.95) +
/// 彩色描边 + 圆角 6，最小 120×44；[active] 时用 godot hover 的
/// accent.darkened(0.55) 底色表达「已准备」等激活态。
class RoomButton extends StatelessWidget {
  const RoomButton({
    super.key,
    required this.maxWidth,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onPressed,
    this.active = false,
  });

  final double maxWidth;
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? Color.lerp(accent, Colors.black, 0.55)!
        : const Color(0xF20A1221);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(bg),
          foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                ? Colors.blueGrey.shade500
                : Colors.white,
          ),
          overlayColor: WidgetStatePropertyAll(accent.withValues(alpha: 0.2)),
          side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? Colors.blueGrey.shade700
                  : accent,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          minimumSize: WidgetStatePropertyAll(
            Size(maxWidth < 120 ? maxWidth : 120, 44),
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: maxWidth < 120 ? 4 : 16),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
