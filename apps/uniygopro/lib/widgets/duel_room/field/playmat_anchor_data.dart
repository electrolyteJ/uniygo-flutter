import 'dart:ui';

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
