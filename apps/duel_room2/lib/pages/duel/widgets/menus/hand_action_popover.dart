import 'package:flutter/material.dart';

import '../../models/duel_menu.dart';
import 'hand_action_menu.dart';

class HandActionPopover extends StatelessWidget {
  static const double menuWidth = 220;

  final List<ActionMenuEntry> actions;

  /// 锚点在 popover 坐标系内的 x 位置（用于对齐底部箭头）。
  /// 为空时箭头居中。
  final double? arrowDx;

  const HandActionPopover({super.key, required this.actions, this.arrowDx});

  @override
  Widget build(BuildContext context) {
    final arrowDx = this.arrowDx;
    final arrowLeft = arrowDx == null
        ? (menuWidth - 26) / 2
        : (arrowDx - 13).clamp(8.0, menuWidth - 34);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HandActionMenu(actions: actions),
        Transform.translate(
          offset: Offset(arrowLeft.toDouble(), -1),
          child: CustomPaint(
            size: const Size(26, 16),
            painter: _PopoverArrowPainter(),
          ),
        ),
      ],
    );
  }
}

class _PopoverArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xE6080D16);
    final border = Paint()
      ..color = const Color(0xFF00F0FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
