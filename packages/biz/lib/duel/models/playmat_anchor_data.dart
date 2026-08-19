import 'dart:ui';

/// 场地锚点数据（各卡槽与阶段灯在 widget 坐标系下的矩形），
/// 供 HUD/弹层对齐 Flame 场地；[signature] 用于变更判等。
class PlaymatAnchorData {
  final Map<String, Rect> slotRects;
  final Rect phaseLampRect;

  const PlaymatAnchorData({
    required this.slotRects,
    required this.phaseLampRect,
  });

  String get signature {
    final entries = slotRects.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final buffer = StringBuffer(
      '${_rectSignature(phaseLampRect)}|${entries.length}',
    );
    for (final entry in entries) {
      buffer
        ..write('|')
        ..write(entry.key)
        ..write(':')
        ..write(_rectSignature(entry.value));
    }
    return buffer.toString();
  }

  static String _rectSignature(Rect rect) {
    return [
      rect.left,
      rect.top,
      rect.width,
      rect.height,
    ].map((value) => value.toStringAsFixed(1)).join(',');
  }
}
