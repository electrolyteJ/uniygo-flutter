/// 匹配盘：背景同心环 + 中央圆形 CTA。
///
/// 四个页签共用同一份视觉与动画。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ygo_settings/theme/duel_controls.dart';
import 'package:ygo_settings/theme/duel_theme.dart';

/// 匹配盘（环 + 圆盘）。
class MatchDial extends StatelessWidget {
  const MatchDial({
    super.key,
    required this.title,
    required this.info,
    required this.hint,
    required this.onTap,
  });

  final String title;
  final String info;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _Rings(),
        Positioned(
          left: 354,
          top: 116,
          width: 136,
          height: 136,
          child: DuelHit(
            key: const ValueKey('create-room-center'),
            onTap: onTap,
            semanticLabel: title,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B2030),
                shape: BoxShape.circle,
                border: Border.all(color: DuelColors.accent),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 36,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: DuelType.sans(
                        title.length > 5 ? 15 : 16,
                        color: DuelColors.accent,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 60,
                    child: Text(
                      info,
                      textAlign: TextAlign.center,
                      style: DuelType.sans(8, color: DuelColors.textMuted),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 78,
                    child: Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: DuelType.sans(7.5, color: DuelColors.textFaint),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 双层同心环，缓慢反向旋转。
class _Rings extends StatefulWidget {
  const _Rings();

  @override
  State<_Rings> createState() => _RingsState();
}

class _RingsState extends State<_Rings> with TickerProviderStateMixin {
  late final AnimationController _outer;
  late final AnimationController _inner;

  @override
  void initState() {
    super.initState();
    _outer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _inner = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _outer.dispose();
    _inner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 282,
          top: 44,
          width: 280,
          height: 280,
          child: AnimatedBuilder(
            animation: _outer,
            builder: (context, _) => Transform.rotate(
              angle: _outer.value * 2 * math.pi,
              child: CustomPaint(
                size: const Size(280, 280),
                painter: const _RingPainter(outer: true),
              ),
            ),
          ),
        ),
        Positioned(
          left: 310,
          top: 72,
          width: 224,
          height: 224,
          child: AnimatedBuilder(
            animation: _inner,
            builder: (context, _) => Transform.rotate(
              angle: -_inner.value * 2 * math.pi,
              child: CustomPaint(
                size: const Size(224, 224),
                painter: const _RingPainter(outer: false),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.outer});

  final bool outer;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    if (outer) {
      _circle(canvas, center, 138, const Color(0xFF16324A));
      _circle(canvas, center, 126, const Color(0xFF122A3E));
      final tick = Paint()
        ..color = const Color(0xFF1E4A63)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 36; i++) {
        final angle = i * math.pi / 18;
        final inner = center + Offset(math.cos(angle), math.sin(angle)) * 126;
        final outerP = center + Offset(math.cos(angle), math.sin(angle)) * 134;
        canvas.drawLine(inner, outerP, tick);
      }
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 132),
        -1.05,
        0.8,
        false,
        Paint()
          ..color = DuelColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    } else {
      _circle(canvas, center, 110, const Color(0xFF1B3A52));
      _circle(canvas, center, 98, const Color(0xFF122A3E));
      final tick = Paint()
        ..color = const Color(0xFF20405A)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 12; i++) {
        final angle = i * math.pi / 6;
        final radial = Offset(math.cos(angle), math.sin(angle));
        final tangent = Offset(-radial.dy, radial.dx);
        final p = center + radial * 104;
        canvas.drawLine(p - tangent * 3, p + tangent * 3, tick);
      }
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 104),
        math.pi * 1.06,
        0.65,
        false,
        Paint()
          ..color = DuelColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _circle(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.outer != outer;
}
