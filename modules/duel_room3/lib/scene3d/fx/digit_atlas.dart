import 'dart:ui' as ui;

import 'package:flame_3d/resources.dart';

/// 伤害数字纹理：Canvas 烘焙 0-9 / + / - 共 12 个字形纹理（池化复用）。
///
/// flame_3d 无文本渲染，数字 = 贴字形的 billboard 平面。
class DigitAtlas {
  DigitAtlas._();
  static final DigitAtlas instance = DigitAtlas._();

  final Map<String, ImageTexture> _glyphs = {};
  Future<void>? _baking;

  static const _chars = ['0','1','2','3','4','5','6','7','8','9','+','-'];

  /// 烘焙全部字形（幂等）。
  Future<void> ensureBaked() {
    return _baking ??= () async {
      for (final ch in _chars) {
        _glyphs[ch] = await ImageTexture.create(_bakeGlyph(ch));
      }
    }();
  }

  ImageTexture? glyph(String ch) => _glyphs[ch];

  static ui.Image _bakeGlyph(String ch, {int w = 64, int h = 88}) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: ui.TextAlign.center),
    )
      ..pushStyle(ui.TextStyle(
        color: const ui.Color(0xFFFFFFFF),
        fontSize: 72,
        fontWeight: ui.FontWeight.w900,
        // 描边效果：阴影叠两层
        shadows: const [
          ui.Shadow(color: ui.Color(0xFF000000), blurRadius: 4),
          ui.Shadow(
            color: ui.Color(0xFF000000),
            blurRadius: 1,
            offset: ui.Offset(2, 2),
          ),
        ],
      ))
      ..addText(ch);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: w.toDouble()));
    canvas.drawParagraph(
      paragraph,
      ui.Offset(0, (h - paragraph.height) / 2),
    );
    return recorder.endRecording().toImageSync(w, h);
  }
}
