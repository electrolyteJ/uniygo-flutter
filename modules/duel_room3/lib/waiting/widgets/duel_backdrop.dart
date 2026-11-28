/// 05 对战-等候 页面底纹（设计稿 324:680）。
///
/// 纯色 #05070F + 五组同心圆（描边 #0C1622）+ 两条横向分隔线（#08111C）。
library;

import 'package:flutter/material.dart';

/// 设计坐标（844×390）。
const List<({double cx, double cy, double r})> _rings = [
  (cx: 422, cy: 195, r: 260),
  (cx: 422, cy: 195, r: 180),
  (cx: 422, cy: 195, r: 100),
  (cx: 860, cy: 40, r: 120),
  (cx: 0, cy: 380, r: 160),
];

const List<double> _hLines = [60, 330];

class DuelRoomBackdrop extends StatelessWidget {
  const DuelRoomBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: const _BackdropPainter(), child: child);
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 844;
    final sy = size.height / 390;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF05070F),
    );

    canvas.save();
    canvas.scale(sx, sy);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF0C1622)
      ..strokeWidth = 1;
    for (final ring in _rings) {
      canvas.drawCircle(Offset(ring.cx, ring.cy), ring.r, ringPaint);
    }

    final linePaint = Paint()
      ..color = const Color(0xFF08111C)
      ..strokeWidth = 1;
    for (final y in _hLines) {
      canvas.drawLine(Offset(0, y), Offset(844, y), linePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
}
