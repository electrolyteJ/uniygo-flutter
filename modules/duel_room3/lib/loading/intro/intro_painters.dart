import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'intro_tokens.dart';

/// 入场动画的共享绘制工具与小组件。
///
/// 全部是纯绘制（CustomPaint / 无状态文字），不持有动画控制器——
/// 时间轴由 [DuelIntroOverlay] 单点驱动，相位画面只接收归一化进度。

/// 缓动：先快后慢（出场用）。
double easeOutCubic(double t) {
  final c = t.clamp(0.0, 1.0) - 1;
  return c * c * c + 1;
}

/// 缓动：先慢后快（冲入用）。
double easeInCubic(double t) {
  final c = t.clamp(0.0, 1.0);
  return c * c * c;
}

double easeInOutCubic(double t) {
  final c = t.clamp(0.0, 1.0);
  return c < 0.5 ? 4 * c * c * c : 1 - math.pow(-2 * c + 2, 3) / 2;
}

/// 在 [from, to] 区间内把 [t] 映射到 [0, 1]。
double progressBetween(double t, double from, double to) {
  if (to <= from) return t >= to ? 1 : 0;
  return ((t - from) / (to - from)).clamp(0.0, 1.0);
}

/// 错位大字：品红层 / 青层 / 主层三层叠加（设计稿的色差错位效果）。
///
/// 层序为品红 → 青 → 主（主层最上，保证可读），与设计稿 402:289/290/291
/// 的 z 序一致。
class ChromaText extends StatelessWidget {
  const ChromaText(
    this.text, {
    super.key,
    required this.fontSize,
    this.fontWeight = FontWeight.w900,
    this.letterSpacing = 2,
    this.color = IntroTokens.textPrimary,
    this.ghostOpacity = 1,
    this.glow = false,
    this.family,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final Color color;

  /// 错位层透明度（入场时由 0 渐显）。
  final double ghostOpacity;

  /// 是否给主层加辉光。
  final bool glow;
  final String? family;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    TextStyle base(Color c) => TextStyle(
      color: c,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: 1,
      fontFamily: family ?? IntroTokens.displayFamily,
    );

    final ghosts = <Widget>[
      if (ghostOpacity > 0.01)
        Transform.translate(
          offset: IntroTokens.magentaGhostOffset,
          child: Text(
            text,
            textAlign: textAlign,
            style: base(IntroTokens.magenta.withValues(alpha: ghostOpacity)),
          ),
        ),
      if (ghostOpacity > 0.01)
        Transform.translate(
          offset: IntroTokens.cyanGhostOffset,
          child: Text(
            text,
            textAlign: textAlign,
            style: base(IntroTokens.cyan.withValues(alpha: ghostOpacity)),
          ),
        ),
    ];

    return Stack(
      alignment: Alignment.center,
      children: [
        ...ghosts,
        Text(
          text,
          textAlign: textAlign,
          style: base(color).copyWith(
            shadows: glow
                ? [
                    Shadow(
                      color: IntroTokens.cyan.withValues(alpha: 0.55),
                      blurRadius: fontSize * 0.45,
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}

/// 带字距的等宽小字（读数 / 传输日志 / 角标）。
class MonoLabel extends StatelessWidget {
  const MonoLabel(
    this.text, {
    super.key,
    this.fontSize = 11,
    this.color = IntroTokens.textMuted,
    this.letterSpacing = 2,
    this.fontWeight = FontWeight.w500,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final double fontSize;
  final Color color;
  final double letterSpacing;
  final FontWeight fontWeight;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        fontWeight: fontWeight,
        fontFamily: IntroTokens.monoFamily,
        height: 1.1,
      ),
    );
  }
}

/// 横向渐变光带（中心亮、两端透明）。
class HorizontalLightBand extends StatelessWidget {
  const HorizontalLightBand({
    super.key,
    this.color = IntroTokens.cyan,
    this.opacity = 0.9,
  });

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ),
      ),
    );
  }
}

/// 径向光晕（中心亮 → 边缘透明）。
class RadialGlow extends StatelessWidget {
  const RadialGlow({
    super.key,
    this.color = IntroTokens.cyan,
    this.opacity = 0.2,
  });

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
    );
  }
}

/// 描边圆环（1px 细线）。
class RingOutline extends StatelessWidget {
  const RingOutline({
    super.key,
    this.color = IntroTokens.cyan,
    this.opacity = 0.3,
    this.strokeWidth = 1,
    this.dashed = false,
  });

  final Color color;
  final double opacity;
  final double strokeWidth;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingPainter(
        color: color.withValues(alpha: opacity),
        strokeWidth: strokeWidth,
        dashed: dashed,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashed,
  });

  final Color color;
  final double strokeWidth;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width - strokeWidth,
      height: size.height - strokeWidth,
    );
    if (!dashed) {
      canvas.drawOval(rect, paint);
      return;
    }
    // 虚线圆：按弧长切成 dash + gap。
    const dash = 10.0;
    const gap = 7.0;
    final path = Path()..addOval(rect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashed != dashed;
}

/// 速度线隧道：多组从中心向外发散的直线（设计稿 402:199）。
///
/// 用极坐标生成放射线，长度按「距中心的归一化距离」衰减，形成隧道感。
class SpeedTunnelPainter extends CustomPainter {
  const SpeedTunnelPainter({
    required this.progress,
    this.color = IntroTokens.cyan,
    this.rayCount = 72,
  });

  /// 0 → 1：线条从中心向外「流」。
  final double progress;
  final Color color;
  final int rayCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * math.pi * 2;
      // 每条线相位错开，避免整圈同步闪烁。
      final phase = (progress + i / rayCount) % 1.0;
      final inner = maxR * (0.12 + phase * 0.72);
      final outer = inner + maxR * 0.26;
      if (inner > maxR) continue;
      final opacity = (1 - phase) * 0.34;
      paint
        ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..strokeWidth = 0.6 + (1 - phase) * 1.1;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        paint,
      );
    }

    // 中心目标点。
    canvas.drawCircle(
      center,
      2.6,
      Paint()..color = IntroTokens.textPrimary.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(SpeedTunnelPainter old) =>
      old.progress != progress || old.color != color;
}

/// 透视场地线框（设计稿 402:238 / 402:464）：梯形外框 + 中线 + 两道横线 + 内切圆。
///
/// [reveal] 控制描边进度（0 → 1，从中心向四周生长）。
class PerspectiveFieldPainter extends CustomPainter {
  const PerspectiveFieldPainter({
    required this.reveal,
    this.color = IntroTokens.cyan,
    this.opacity = 0.85,
    this.strokeWidth = 1.2,
    this.showCircle = true,
  });

  final double reveal;
  final Color color;
  final double opacity;
  final double strokeWidth;
  final bool showCircle;

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withValues(alpha: opacity);

    // 梯形：上边窄（远端），下边宽（近端）。
    final topY = size.height * 0.30;
    final bottomY = size.height * 0.90;
    final topHalf = size.width * 0.115;
    final bottomHalf = size.width * 0.315;
    final cx = size.width / 2;

    Path clipPath = Path()
      ..moveTo(cx - topHalf, topY)
      ..lineTo(cx + topHalf, topY)
      ..lineTo(cx + bottomHalf, bottomY)
      ..lineTo(cx - bottomHalf, bottomY)
      ..close();

    // 从中点向外「生长」：裁剪交给 saveLayer + 缩放。
    canvas.save();
    final scale = 0.25 + 0.75 * easeOutCubic(reveal);
    canvas.translate(cx, (topY + bottomY) / 2);
    canvas.scale(scale, scale);
    canvas.translate(-cx, -(topY + bottomY) / 2);

    canvas.drawPath(clipPath, paint);

    // 中线（纵向）。
    canvas.drawLine(
      Offset(cx, topY),
      Offset(cx, bottomY),
      paint..color = color.withValues(alpha: opacity * 0.7),
    );

    // 两道横线：按梯形插值。
    final paintFaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.8
      ..color = color.withValues(alpha: opacity * 0.5);
    for (final f in const [0.38, 0.68]) {
      final y = topY + (bottomY - topY) * f;
      final half = topHalf + (bottomHalf - topHalf) * f;
      canvas.drawLine(Offset(cx - half, y), Offset(cx + half, y), paintFaint);
    }

    if (showCircle) {
      // 内切圆：贴住梯形上边、与两侧相切。
      final radius = (bottomY - topY) * 0.42;
      canvas.drawCircle(Offset(cx, topY + radius * 0.86), radius, paintFaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PerspectiveFieldPainter old) =>
      old.reveal != reveal || old.color != color || old.opacity != opacity;
}

/// 坐标网格底纹（设计稿 402:179）：稀疏的十字准线。
class CoordGridPainter extends CustomPainter {
  const CoordGridPainter({this.color = IntroTokens.cyan, this.opacity = 0.16});

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: opacity);
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 水平准线（上下各一条）。
    for (final f in const [0.18, 0.5, 0.82]) {
      final y = size.height * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // 竖直准线（左右各一条 + 中轴）。
    for (final f in const [0.08, 0.5, 0.92]) {
      final x = size.width * f;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 四角短刻度。
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color.withValues(alpha: opacity * 2.2);
    const len = 14.0;
    for (final c in [
      Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      final sx = c.dx == 0 ? 1.0 : -1.0;
      final sy = c.dy == 0 ? 1.0 : -1.0;
      canvas.drawLine(c, c + Offset(sx * len, 0), tick);
      canvas.drawLine(c, c + Offset(0, sy * len), tick);
    }

    // 中心十字。
    canvas.drawLine(Offset(cx - 6, cy), Offset(cx + 6, cy), tick);
    canvas.drawLine(Offset(cx, cy - 6), Offset(cx, cy + 6), tick);
  }

  @override
  bool shouldRepaint(CoordGridPainter old) => old.opacity != opacity;
}

/// 加载进度槽（设计稿底部 1360×3 细条 + 右侧百分比）。
class IntroProgressBar extends StatelessWidget {
  const IntroProgressBar({
    super.key,
    required this.progress,
    required this.label,
    required this.percentText,
    this.color = IntroTokens.cyan,
    this.percentColor,
  });

  /// 0 → 1。
  final double progress;
  final String label;
  final String percentText;
  final Color color;
  final Color? percentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MonoLabel(label, fontSize: 11, color: IntroTokens.textDim),
            MonoLabel(
              percentText,
              fontSize: 11,
              color: percentColor ?? color,
              letterSpacing: 1.5,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 3,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Stack 里的子节点拿不到 ParentData 宽度，必须用
              // LayoutBuilder 的 maxWidth 手动算进度条宽度
              // （FractionallySizedBox 在 Positioned 外会拿到无限宽约束）。
              final w = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 0.0;
              return Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: IntroTokens.slot)),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: w * progress.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.55),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 左上角图注（设计稿 402:197 等）：序号 + 说明。
class IntroCaption extends StatelessWidget {
  const IntroCaption(this.text, {super.key, this.color = IntroTokens.cyan});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MonoLabel(text, fontSize: 11, color: color, letterSpacing: 1.6);
  }
}

/// 给文字加「故障抖动」位移（错位大字的入场用）。
class GlitchOffset extends StatelessWidget {
  const GlitchOffset({super.key, required this.child, required this.amount});

  /// 0 → 1，越大错位越明显。
  final double amount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dx = IntroTokens.magentaGhostOffset.dx * amount;
    final dy = IntroTokens.magentaGhostOffset.dy * amount;
    return Transform.translate(offset: Offset(dx, dy), child: child);
  }
}

/// ui.ClipRect 快捷（相位画面对裁切敏感）。
class PhaseClip extends StatelessWidget {
  const PhaseClip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(child: child);
}

/// 让 CustomPaint 精确铺满父级（不带 intrinsic 尺寸）。
class FillPaint extends StatelessWidget {
  const FillPaint({super.key, required this.painter});

  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(child: CustomPaint(painter: painter));
  }
}

/// 便捷：把 painter 包成 [ui.Size] 无关的满铺层。
Widget fillPainter(CustomPainter painter) =>
    CustomPaint(painter: painter, child: const SizedBox.expand());
