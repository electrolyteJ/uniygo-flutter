import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/cyber_skin.dart';

/// 赛博 HUD 后处理叠层：扫描线 / 下移扫描带 / 雨丝 / 噪点 / 暗角 /
/// 偶发故障条 / 四角切角线框。
///
/// flame_3d 没有后处理 pass，这一层是纯 Flutter CustomPaint，铺在 3D
/// 场景之上、HUD 之下，用 IgnorePointer 保证不拦截任何点击/射线拾取。
/// 8 秒一个循环，所有随机量用固定种子，避免每帧闪烁无规律。
class CyberOverlay extends StatefulWidget {
  const CyberOverlay({super.key});

  @override
  State<CyberOverlay> createState() => _CyberOverlayState();
}

class _CyberOverlayState extends State<CyberOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _CyberOverlayPainter(_controller.value),
          ),
        ),
      ),
    );
  }
}

class _CyberOverlayPainter extends CustomPainter {
  const _CyberOverlayPainter(this.t);

  /// 归一化循环进度 [0, 1)。
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── 暗角：四周压暗，中心留出决斗场 ──
    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(w / 2, h * 0.46),
        math.max(w, h) * 0.72,
        const [
          Color(0x00000000),
          Color(0x00000000),
          Color(0x8A01030A),
        ],
        [0.0, 0.58, 1.0],
      );
    canvas.drawRect(Offset.zero & size, vignette);

    // ── 静态扫描线（每 3px 一条极淡青线）──
    final scanPaint = Paint()
      ..color = const Color(0x0C00D9FF)
      ..strokeWidth = 1;
    for (var y = 0.0; y < h; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(w, y), scanPaint);
    }

    // ── 缓慢下移的亮扫描带 ──
    final bandY = (t * (h + 260)) - 130;
    final band = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, bandY - 55),
        Offset(0, bandY + 55),
        const [
          Color(0x0000E5FF),
          Color(0x1400E5FF),
          Color(0x0000E5FF),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, bandY - 55, w, 110), band);

    // ── 雨丝：固定种子生成，随进度整体下移 ──
    final rain = Paint()
      ..color = const Color(0x1A7DF9FF)
      ..strokeWidth = 0.8;
    final rng = math.Random(4242);
    for (var i = 0; i < 72; i++) {
      final x0 = rng.nextDouble() * (w + 60) - 30;
      final y0 = rng.nextDouble() * (h + 120);
      final len = 14 + rng.nextDouble() * 26;
      final y = (y0 + t * h * 1.8) % (h + 120) - 60;
      canvas.drawLine(
        Offset(x0, y),
        Offset(x0 - len * 0.28, y + len),
        rain,
      );
    }

    // ── 噪点 ──
    final noiseRng = math.Random(911);
    final noise = Paint()..color = const Color(0x1400E5FF);
    final warmNoise = Paint()..color = const Color(0x10FF2D95);
    for (var i = 0; i < 150; i++) {
      final x = noiseRng.nextDouble() * w;
      final y = noiseRng.nextDouble() * h;
      final jitter = math.sin(t * math.pi * 16 + i) * 1.5;
      canvas.drawRect(
        Rect.fromLTWH(x + jitter, y, 1.2, 1.2),
        i % 5 == 0 ? warmNoise : noise,
      );
    }

    // ── 偶发故障条：每隔若干帧出现 1~2 帧的水平色差 ──
    final frame = (t * 8 * 60).floor();
    if (frame % 97 < 2 || frame % 157 < 2) {
      final gy = h * (0.18 + (frame % 7) * 0.11);
      canvas.drawRect(
        Rect.fromLTWH(0, gy, w, 2 + (frame % 3) * 2),
        Paint()..color = const Color(0x33FF2D95),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, gy + 6, w, 1.5),
        Paint()..color = const Color(0x2A00E5FF),
      );
    }

    // ── 四角切角线框 + 上下极细霓虹边 ──
    final framePaint = Paint()
      ..color = CyberPalette.cyan.withValues(alpha: 0.34)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const inset = 10.0;
    const arm = 26.0;
    for (final corner in [
      _Corner(inset, inset, 1, 1),
      _Corner(w - inset, inset, -1, 1),
      _Corner(inset, h - inset, 1, -1),
      _Corner(w - inset, h - inset, -1, -1),
    ]) {
      final path = Path()
        ..moveTo(corner.x, corner.y + corner.sy * arm)
        ..lineTo(corner.x, corner.y)
        ..lineTo(corner.x + corner.sx * arm, corner.y);
      canvas.drawPath(path, framePaint);
    }
    canvas.drawLine(
      Offset(0, 0),
      Offset(w, 0),
      Paint()..color = CyberPalette.magenta.withValues(alpha: 0.22),
    );
    canvas.drawLine(
      Offset(0, h - 1),
      Offset(w, h - 1),
      Paint()..color = CyberPalette.cyan.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant _CyberOverlayPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _Corner {
  const _Corner(this.x, this.y, this.sx, this.sy);

  final double x;
  final double y;
  final double sx;
  final double sy;
}
