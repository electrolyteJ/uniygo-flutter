import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Flame 侧手牌/飞行卡的绘制与 Sprite 工具。
///
/// 卡背为程序生成（深渐变 + 斜纹 + 金框 + 菱形徽记），经
/// [loadCardBackSprite] 一次性烘焙成 Sprite 缓存复用——
/// 卡面/卡背因此统一走 SpriteComponent 渲染。
class CardPaint {
  CardPaint._();

  /// 卡背烘焙分辨率（2x，Retina 下不糊）。
  static const double _backW = 128;
  static const double _backH = 180;

  static Sprite? _cardBackSprite;

  /// 卡背 Sprite（同步烘焙一次，全局复用）。圆角已烘进图像
  /// （角部透明），SpriteComponent 直接渲染即为圆角卡背。
  ///
  /// 同步（toImageSync）的原因：SpriteComponent 挂载时要求 sprite 非空，
  /// 手牌/飞行卡构造时就要拿到初始 sprite，等不得异步。
  static Sprite cardBackSprite() {
    final cached = _cardBackSprite;
    if (cached != null) return cached;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintCardBack(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, _backW, _backH),
        const Radius.circular(10),
      ),
    );
    final image = recorder.endRecording().toImageSync(
      _backW.toInt(),
      _backH.toInt(),
    );
    return _cardBackSprite = Sprite(image);
  }

  /// 卡背底色：深蓝黑垂直渐变。
  static const _backGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1B3A), Color(0xFF0A0B1E)],
  );

  static final Paint _backStripePaint = Paint()
    ..color = const Color(0xFF3A3D6E).withValues(alpha: 0.35)
    ..strokeWidth = 0.6
    ..style = PaintingStyle.stroke;

  static final Paint _backInnerBorderPaint = Paint()
    ..color = const Color(0xFFFFD700).withValues(alpha: 0.75)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _backInnerThinPaint = Paint()
    ..color = const Color(0xFFFFD700).withValues(alpha: 0.30)
    ..strokeWidth = 0.5
    ..style = PaintingStyle.stroke;

  static final Paint _backRingPaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  static final Paint _backRingGlowPaint = Paint()
    ..color = const Color(0xFF00F0FF).withValues(alpha: 0.55)
    ..strokeWidth = 0.8
    ..style = PaintingStyle.stroke;

  static final Paint _backDiamondPaint = Paint()
    ..color = const Color(0xFF00F0FF).withValues(alpha: 0.85);

  /// 绘制卡背（供 [loadCardBackSprite] 烘焙）：移植自原 Flutter 手牌栏卡背——
  /// 深渐变底 + 斜纹 + 双层金框 + 中心圆环菱形。
  static void paintCardBack(Canvas canvas, RRect rrect) {
    final rect = rrect.outerRect;
    canvas.save();
    canvas.clipRRect(rrect);

    canvas.drawRect(
      rect,
      Paint()..shader = _backGradient.createShader(rect),
    );

    // 细密斜纹。
    const step = 6.0;
    for (double x = rect.left - rect.height; x < rect.right; x += step) {
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x + rect.height, rect.bottom),
        _backStripePaint,
      );
    }

    canvas.restore();

    // 双层金线内框。
    final inner = rrect.outerRect.deflate(4.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(3)),
      _backInnerBorderPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner.deflate(2.0), const Radius.circular(2)),
      _backInnerThinPaint,
    );

    // 中心徽记：金环 + 青色细环 + 旋转 45° 菱形。
    final center = rect.center;
    final radius = rect.shortestSide * 0.22;
    canvas.drawCircle(center, radius, _backRingPaint);
    canvas.drawCircle(center, radius - 2.0, _backRingGlowPaint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.785398); // π/4
    final half = radius * 0.45;
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2),
      _backDiamondPaint,
    );
    canvas.restore();
  }
}
