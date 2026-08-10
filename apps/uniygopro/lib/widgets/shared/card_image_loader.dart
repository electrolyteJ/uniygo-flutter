import 'dart:async';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

/// 统一的卡片图片加载器——Flame (ui.Image) 和 Flutter Widget (ImageProvider)
/// 共用同一份解码后缓存。同一 code 的并发请求只发一次 HTTP，结果共享给所有等待者。
class CardImageLoader {
  static final CardImageLoader I = CardImageLoader._();
  CardImageLoader._();

  /// URL 解析器，由应用启动时注入（通常挂到 ServiceSingleton.dataService）。
  String Function(int code)? urlResolver;

  final Map<int, ui.Image> _images = {};
  final Map<int, Completer<ui.Image?>> _loading = {};

  String _url(int code) => urlResolver?.call(code) ?? '';

  /// 同步获取已缓存的 [ui.Image]，未加载返回 null。
  ui.Image? get(int code) => _images[code];

  /// 异步加载卡片图片：
  /// - 命中缓存 → 立即返回
  /// - 正在加载 → 等待同一 Future（去重）
  /// - 未加载 → 发起 HTTP 请求并解码
  Future<ui.Image?> load(int code) async {
    final cached = _images[code];
    if (cached != null) return cached;

    final existing = _loading[code];
    if (existing != null) return existing.future;

    final completer = Completer<ui.Image?>();
    _loading[code] = completer;
    try {
      final url = _url(code);
      if (url.isEmpty) {
        completer.complete(null);
        return null;
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        completer.complete(null);
        return null;
      }
      final codec = await ui.instantiateImageCodec(response.bodyBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      _images[code] = image;
      completer.complete(image);
      return image;
    } catch (_) {
      completer.complete(null);
      return null;
    } finally {
      _loading.remove(code);
    }
  }

  /// 移除指定 code 的缓存图片（释放 GPU 资源）。
  void evict(int code) {
    _images.remove(code)?.dispose();
    _loading.remove(code);
  }

  /// 释放全部缓存资源。
  void clear() {
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    _loading.clear();
  }
}
