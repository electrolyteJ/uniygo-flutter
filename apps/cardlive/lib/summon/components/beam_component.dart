import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../styles/summon_style.dart';

/// 光柱组件 —— 根据 LightStyle 绘制不同形态的光束效果
class BeamComponent extends PositionComponent {
  final SummonStyle style;

  BeamComponent({required this.style})
      : super(
          size: Vector2(300, 600),
          anchor: Anchor.center,
        );

  double progress = 0.0;

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final alpha = (progress * 0.8).clamp(0.0, 0.8);

    switch (style.lightStyle) {
      case LightStyle.column:
        _drawColumn(canvas, center, alpha);
      case LightStyle.radial:
        _drawRadial(canvas, center, alpha);
      case LightStyle.spiral:
        _drawSpiral(canvas, center, alpha);
      case LightStyle.blackHole:
        _drawBlackHole(canvas, center, alpha);
      case LightStyle.lines:
        _drawLines(canvas, center, alpha);
      case LightStyle.runes:
        _drawRunes(canvas, center, alpha);
      case LightStyle.shadow:
        _drawShadow(canvas, center, alpha);
    }
  }

  void _drawColumn(Canvas canvas, Offset center, double alpha) {
    final paint = Paint()
      ..color = style.primaryColor.withOpacity(alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // 主光柱
    canvas.drawRect(
        Rect.fromCenter(
            center: center, width: 4 * progress, height: size.y * progress),
        paint);

    // 副光柱
    final sidePaint = Paint()
      ..color = style.secondaryColor.withOpacity(alpha * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(center.dx - 30, center.dy),
            width: 2 * progress,
            height: size.y * 0.6 * progress),
        sidePaint);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(center.dx + 30, center.dy),
            width: 2 * progress,
            height: size.y * 0.6 * progress),
        sidePaint);
  }

  void _drawRadial(Canvas canvas, Offset center, double alpha) {
    final paint = Paint()
      ..color = style.primaryColor.withOpacity(alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    // 同心圆扩散
    for (int i = 0; i < 4; i++) {
      final r = 40.0 + i * 30.0 * progress;
      canvas.drawCircle(center, r, paint..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  void _drawSpiral(Canvas canvas, Offset center, double alpha) {
    final paint = Paint()
      ..color = style.primaryColor.withOpacity(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final path = Path();
    for (double t = 0; t < progress * 8 * math.pi; t += 0.1) {
      final r = t * 12;
      final x = center.dx + r * math.cos(t);
      final y = center.dy + r * math.sin(t);
      if (t == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawBlackHole(Canvas canvas, Offset center, double alpha) {
    // 暗紫色黑洞效果
    final paint = Paint()
      ..color = style.accentColor.withOpacity(alpha * 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, 30 * progress, paint);
    // 外围光环
    canvas.drawCircle(
        center,
        60 * progress,
        Paint()
          ..color = style.primaryColor.withOpacity(alpha * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
  }

  void _drawLines(Canvas canvas, Offset center, double alpha) {
    final paint = Paint()
      ..color = style.primaryColor.withOpacity(alpha)
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // 电路数据线
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final r = 80 * progress;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), paint);

      // 分支线
      final br = 30 * progress;
      final bx = x + br * math.cos(angle + 0.3);
      final by = y + br * math.sin(angle + 0.3);
      canvas.drawLine(Offset(x, y), Offset(bx, by), paint..color = style.secondaryColor.withOpacity(alpha * 0.6));
    }
  }

  void _drawRunes(Canvas canvas, Offset center, double alpha) {
    // 符文圆阵
    final paint = Paint()
      ..color = style.primaryColor.withOpacity(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawCircle(center, 70 * progress, paint);
    canvas.drawCircle(center, 50 * progress, paint..color = style.secondaryColor.withOpacity(alpha * 0.5));
    // 十字符文
    canvas.drawLine(
        Offset(center.dx - 60 * progress, center.dy),
        Offset(center.dx + 60 * progress, center.dy),
        paint);
    canvas.drawLine(
        Offset(center.dx, center.dy - 60 * progress),
        Offset(center.dx, center.dy + 60 * progress),
        paint);
  }

  void _drawShadow(Canvas canvas, Offset center, double alpha) {
    // 暗影扩散
    final gradient = RadialGradient(
      colors: [
        style.accentColor.withOpacity(alpha * 0.7),
        style.primaryColor.withOpacity(alpha * 0.3),
        Colors.transparent,
      ],
    );
    canvas.drawCircle(
        center,
        100 * progress,
        Paint()..shader = gradient.createShader(Rect.fromCircle(center: center, radius: 100 * progress)));
  }
}
