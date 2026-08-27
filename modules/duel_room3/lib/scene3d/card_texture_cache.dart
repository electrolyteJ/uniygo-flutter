import 'dart:ui' as ui;

import 'package:biz/card_image_loader.dart';
import 'package:flame_3d/resources.dart';

/// 卡图纹理缓存：CardImageLoader（biz，ui.Image L1 内存缓存 + 磁盘缓存）
/// → flame_3d [ImageTexture]。
///
/// - 命中 L1 → 同步出纹理；miss → 异步加载完成后回调（立牌先显示占位色）
/// - 卡背纹理由 Canvas 程序化烘焙（移植 duel_room1 card_paint 的卡背视觉）
class CardTextureCache {
  CardTextureCache._();
  static final CardTextureCache instance = CardTextureCache._();

  final Map<int, ImageTexture> _textures = {};

  /// 加载中的卡号 → 等待回调队列（同卡多立牌都要拿到纹理）。
  final Map<int, List<void Function(ImageTexture texture)>> _pending = {};
  ImageTexture? _cardBack;

  /// 已缓存的纹理（未加载返回 null）。
  ImageTexture? getCached(int code) => _textures[code];

  /// 确保纹理加载（已缓存则同步回调，否则异步加载后回调）。
  /// ImageTexture.create 本身是异步的（ui.Image → ByteData），统一走回调。
  void ensure(int code, void Function(ImageTexture texture) onReady) {
    final cached = _textures[code];
    if (cached != null) {
      onReady(cached);
      return;
    }
    if (code <= 0) return;
    final waiters = _pending[code];
    if (waiters != null) {
      waiters.add(onReady);
      return;
    }
    _pending[code] = [onReady];
    () async {
      final image =
          CardImageLoader.I.get(code) ??
          await CardImageLoader.I.load(code, targetWidth: 300);
      final callbacks = _pending.remove(code) ?? const [];
      if (image == null) return;
      final texture = _textures[code] ??= await ImageTexture.create(image);
      for (final cb in callbacks) {
        cb(texture);
      }
    }();
  }

  /// 卡背纹理（懒烘焙一次）。
  Future<ImageTexture> cardBack() async {
    final cached = _cardBack;
    if (cached != null) return cached;
    final texture = await ImageTexture.create(_bakeCardBack());
    _cardBack = texture;
    return texture;
  }

  /// 烘焙卡背：深渐变底 + 斜纹 + 金框 + 中心徽记（简化自 room1 卡背）。
  static ui.Image _bakeCardBack({int w = 236, int h = 344}) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final rect = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    final rrect = ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(10));

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      rect,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset.zero,
          ui.Offset(0, h.toDouble()),
          const [ui.Color(0xFF1A1206), ui.Color(0xFF3A2A10)],
        ),
    );
    final stripe = ui.Paint()..color = const ui.Color(0x14FFD700);
    const step = 8.0;
    for (var x = -h.toDouble(); x < w.toDouble(); x += step) {
      canvas.drawLine(
        ui.Offset(x, 0),
        ui.Offset(x + h.toDouble(), h.toDouble()),
        stripe,
      );
    }
    canvas.restore();

    final inner = rect.deflate(8);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(inner, const ui.Radius.circular(6)),
      ui.Paint()
        ..color = const ui.Color(0xCCFFD700)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final center = rect.center;
    final radius = w * 0.2;
    canvas.drawCircle(
      center,
      radius,
      ui.Paint()
        ..color = const ui.Color(0xFFFFD700)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      center,
      radius - 4,
      ui.Paint()
        ..color = const ui.Color(0x8C00F0FF)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final diamond = ui.Path()
      ..moveTo(center.dx, center.dy - radius * 0.6)
      ..lineTo(center.dx + radius * 0.6, center.dy)
      ..lineTo(center.dx, center.dy + radius * 0.6)
      ..lineTo(center.dx - radius * 0.6, center.dy)
      ..close();
    canvas.drawPath(diamond, ui.Paint()..color = const ui.Color(0xD900F0FF));

    return recorder.endRecording().toImageSync(w, h);
  }
}
