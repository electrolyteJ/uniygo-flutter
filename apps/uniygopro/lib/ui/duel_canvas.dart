/// 三屏共用的「设计画布」：844×390 设计坐标按可用空间铺满。
///
/// 应用全局以 1280×800 为设计分辨率并由 FittedBox(fill) 缩放到窗口
/// （见 app.dart）。三屏沿用同一约定：内容层把 844×390 设计稿
/// 非等比拉伸到整块可用区域，背景装饰按同一比例（sx/sy 分别缩放）
/// 全幅绘制。这样在手机横屏（约 844×390）上像素比例与设计稿一致，
/// 在桌面/网页上则与其他页面一样整体拉伸，不会出现上下黑边。
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:ygo_settings/theme/duel_theme.dart';

/// 设计稿分辨率（逻辑像素）。
const Size kDuelDesignSize = Size(844, 390);

/// 背景装饰的三种变体。
enum DuelBackdropKind { splash, login, home, page }

/// 页面骨架：背景铺满，[child] 按 844×390 设计坐标铺满可用区域。
class DuelStage extends StatelessWidget {
  const DuelStage({super.key, required this.backdrop, required this.child});

  final DuelBackdropKind backdrop;

  /// 以 844×390 为坐标系的页面内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DuelColors.base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DuelBackdrop(kind: backdrop),
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: kDuelDesignSize.width,
                height: kDuelDesignSize.height,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 全幅背景装饰。
class DuelBackdrop extends StatelessWidget {
  const DuelBackdrop({super.key, required this.kind});

  final DuelBackdropKind kind;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _DuelBackdropPainter(kind),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DuelBackdropPainter extends CustomPainter {
  _DuelBackdropPainter(this.kind);

  final DuelBackdropKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final sx = size.width / kDuelDesignSize.width;
    final sy = size.height / kDuelDesignSize.height;

    _paintBase(canvas, size, sx, sy);
    _paintGrid(canvas, size, sx, sy);
    _paintRings(canvas, sx, sy);
    _paintRule(canvas, size, sx, sy);
    _paintSlash(canvas, sx, sy);
    _paintArc(canvas, sx, sy);
    if (kind == DuelBackdropKind.home) {
      _paintTopFade(canvas, size, sy);
    }
  }

  /// 底色渐变 + 中心冷光（设计稿 splash/login 的径向光晕）。
  void _paintBase(Canvas canvas, Size size, double sx, double sy) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment(-0.35, -0.75),
          end: Alignment(0.75, 0.85),
          colors: [DuelColors.baseTop, DuelColors.baseMid, DuelColors.base],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );

    if (kind == DuelBackdropKind.home || kind == DuelBackdropKind.page) {
      return;
    }

    // 设计稿径向光晕：中心约 (262.5, 190)，#123047 40% → 透明。
    final center = Offset(
      sx * (kind == DuelBackdropKind.login ? 253 : 221.5),
      sy * 190,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          size.width * 0.52,
          const [Color(0x66123047), Color(0x00123047)],
          const [0, 1],
        ),
    );
  }

  /// 28px 网格（按 sx/sy 分别对齐设计稿间距）。
  void _paintGrid(Canvas canvas, Size size, double sx, double sy) {
    final paint = Paint()..color = DuelColors.grid;
    final stepX = 28 * sx;
    final stepY = 28 * sy;

    for (var x = 0.0; x <= size.width; x += stepX) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += stepY) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  void _paintRings(Canvas canvas, double sx, double sy) {
    if (kind == DuelBackdropKind.home || kind == DuelBackdropKind.page) {
      return;
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = DuelColors.ring;

    final center = kind == DuelBackdropKind.login
        ? const Offset(300, 200)
        : const Offset(422, 190);
    final radii = kind == DuelBackdropKind.login
        ? const [330.0, 270.0]
        : const [336.0, 262.0, 214.0];

    for (final r in radii) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx * sx, center.dy * sy),
          width: 2 * r * sx,
          height: 2 * r * sy,
        ),
        paint,
      );
    }
  }

  /// 开屏的水平基准线（y=180）。
  void _paintRule(Canvas canvas, Size size, double sx, double sy) {
    if (kind != DuelBackdropKind.splash) return;
    canvas.drawRect(
      Rect.fromLTWH(0, 180 * sy, size.width, 1),
      Paint()..color = DuelColors.rule,
    );
  }

  /// 开屏右侧的青色斜线。
  void _paintSlash(Canvas canvas, double sx, double sy) {
    if (kind != DuelBackdropKind.splash) return;
    canvas.drawLine(
      Offset(614 * sx, 266 * sy),
      Offset(633 * sx, 230 * sy),
      Paint()
        ..color = DuelColors.accentDim
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  /// 登录页左上角的青色弧线。
  void _paintArc(Canvas canvas, double sx, double sy) {
    if (kind != DuelBackdropKind.login) return;
    final path = Path()
      ..moveTo(112 * sx, 88 * sy)
      ..quadraticBezierTo(138 * sx, 24 * sy, 208 * sx, 30 * sy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = DuelColors.accentDim,
    );
  }

  /// 主页顶部黑色渐隐（设计稿 844×72，黑色 62% → 透明）。
  void _paintTopFade(Canvas canvas, Size size, double sy) {
    final rect = Rect.fromLTWH(0, 0, size.width, 72 * sy);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x9E000000), Color(0x00000000)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _DuelBackdropPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
