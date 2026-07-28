import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../styles/summon_style.dart';

/// 光环/法阵组件 —— 多层同心环，脉冲呼吸效果
class RingComponent extends PositionComponent {
  final SummonStyle style;
  final double maxRadius;

  RingComponent({required this.style, this.maxRadius = 180})
      : super(size: Vector2.all(maxRadius * 2), anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final progress = summonProgress;

    // 外层环
    _drawRing(canvas, center, maxRadius * progress,
        style.ringColors.first.withOpacity(0.6 * progress), style.ringWidth);

    // 中层环（略小，透明度略低）
    _drawRing(canvas, center, maxRadius * 0.85 * progress,
        style.ringColors.length > 1
            ? style.ringColors[1].withOpacity(0.4 * progress)
            : style.ringColors.first.withOpacity(0.4 * progress),
        style.ringWidth * 0.7);

    // 内层环
    _drawRing(canvas, center, maxRadius * 0.55 * progress,
        style.secondaryColor.withOpacity(0.25 * progress), 1.5);

    // 六芒星（仪式/魔法类型）
    if (style.lightStyle == LightStyle.runes) {
      _drawHexagram(canvas, center, maxRadius * 0.7 * progress, progress);
    }
  }

  void _drawRing(
      Canvas canvas, Offset center, double radius, Color color, double width) {
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  void _drawHexagram(
      Canvas canvas, Offset center, double radius, double opacity) {
    final paint = Paint()
      ..color = style.primaryColor.withOpacity(0.4 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // 上三角
    final path1 = Path();
    for (int i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 3;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) path1.moveTo(x, y); else path1.lineTo(x, y);
    }
    path1.close();
    canvas.drawPath(path1, paint);
    // 下三角
    final path2 = Path();
    for (int i = 0; i < 3; i++) {
      final angle = math.pi / 2 + i * 2 * math.pi / 3;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) path2.moveTo(x, y); else path2.lineTo(x, y);
    }
    path2.close();
    canvas.drawPath(path2, paint);
  }

  double summonProgress = 0.0;
}
