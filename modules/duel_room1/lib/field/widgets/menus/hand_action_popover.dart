import 'package:flutter/material.dart';

import 'package:biz/duel/models/duel_menu.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'hand_action_menu.dart';

class HandActionPopover extends StatelessWidget {
  final List<ActionMenuEntry> actions;

  /// 锚点在 popover 坐标系内的 x 位置（用于对齐底部箭头）。
  /// 为空时箭头居中。
  final double? arrowDx;

  const HandActionPopover({super.key, required this.actions, this.arrowDx});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final menuWidth = menuWidthFor(DuelRoomLayout.of(context));
    if (menuWidth <= 0) return const SizedBox.shrink();

    final arrowWidth = menuWidth.clamp(0.0, 26.0).toDouble();
    final arrowDx = this.arrowDx;
    final arrowLeft = arrowDx == null
        ? (menuWidth - arrowWidth) / 2
        : (arrowDx - arrowWidth / 2)
              .clamp(0.0, menuWidth - arrowWidth)
              .toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HandActionMenu(actions: actions),
        Transform.translate(
          offset: Offset(arrowLeft.toDouble(), -1),
          child: CustomPaint(
            size: Size(arrowWidth, 16),
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
