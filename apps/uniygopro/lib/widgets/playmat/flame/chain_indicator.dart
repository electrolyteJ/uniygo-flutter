import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class ChainIndicatorComponent extends PositionComponent with HasGameRef {
  final int chainIndex;
  final String label;

  ChainIndicatorComponent({
    required this.chainIndex,
    required this.label,
  });

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    // Pulsing scale effect from HTML
    final pulse = 1.0 + sin(_time * 4) * 0.03;
    
    const goldGlow = Color(0xFFFFD700);
    const cyanGlow = Color(0xFF00F0FF);
    final color = chainIndex % 2 == 0 ? goldGlow : cyanGlow;

    canvas.save();
    canvas.scale(pulse);

    final paint = Paint()
      ..color = const Color(0xEB0A101A) // rgba(10, 16, 26, 0.95)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 140, height: 32),
      const Radius.circular(16),
    );

    // Shadow/Glow
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawRRect(rect, paint);
    canvas.drawRRect(rect, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'CHAIN $chainIndex: $label',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          fontFamily: 'Orbitron',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );

    canvas.restore();
  }
}
