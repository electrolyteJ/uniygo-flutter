import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 统一的卡片图片加载器——Flame (ui.Image) 和 Flutter Widget (ImageProvider)
/// 共用同一套缓存。
///
/// 三层缓存：
/// 1. **L1 内存 LRU**（有界）：解码后的 [ui.Image]，供 Flame 侧同步 [get]；
///    超过 [_maxMemoryImages] 时按最久未访问淘汰并释放 GPU 资源，
///    不再像旧版无限增长导致内存失控/被迫全清。
/// 2. **L2 磁盘缓存**（flutter_cache_manager）：HTTP 缓存头语义 + LRU 文件
///    淘汰（最多 [Config.maxNrOfCacheObjects] 个对象）；卡图按 code 不可变，
///    `stalePeriod` 设为 30 天——期间不重验证，app 重启/切后台零重下。
/// 3. **L3 HTTP**：CacheManager 内置（支持 ETag/Cache-Control），外加轻量重试。
///
/// 同一 code 的并发请求只发一次加载，结果共享给所有等待者。
/// 卡图专用 HTTP 文件服务：
/// - 提高并发上限（默认 10 → 20），加快大批量缩略图的下行吞吐；
/// - 对「连接 + 响应头」加 20s 超时，避免偶发挂起长期占用并发槽位，
///   拖慢排队中的其它卡图（表现为「加载慢/加载不出来」）。
class _CardImageFileService extends HttpFileService {
  _CardImageFileService() {
    concurrentFetches = 20;
  }

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) {
    return super
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 20));
  }
}

class CardImageLoader {
  static final CardImageLoader I = CardImageLoader._();
  CardImageLoader._();

  /// URL 解析器，由应用启动时注入（通常挂到 ServiceSingleton.dataService）。
  String Function(int code)? urlResolver;

  /// L2 磁盘缓存：卡图 immutable，30 天免重验证；LRU 上限 1 万个对象。
  static final CacheManager _cacheManager = CacheManager(
    Config(
      'ygo_card_images',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 10000,
      fileService: _CardImageFileService(),
    ),
  );

  /// 暴露给 Widget 侧（CardImage / CachedNetworkImage）共享同一磁盘层。
  CacheManager get cacheManager => _cacheManager;

  /// L1 内存 LRU 上限（张）。解码后的卡图约 1MB/张，200 张 ≈ 200MB 上限；
  /// 对局同时可见卡图约 50~60 张，此值留有余量。
  static const int _maxMemoryImages = 200;

  /// 解码失败/URL 非法的 code 短期不再重试（负面缓存，避免高频重建时反复请求）。
  /// 缩短到 5s：瞬时超时/网络抖动后快速恢复，减少「一直加载不出来」。
  static const Duration _negativeCacheTtl = Duration(seconds: 5);
  final Map<int, DateTime> _failedCodes = {};

  final LinkedHashMap<int, ui.Image> _images = LinkedHashMap();
  final Map<int, Completer<ui.Image?>> _loading = {};

  String _url(int code) => urlResolver?.call(code) ?? '';

  /// 同步获取已缓存的 [ui.Image]，未加载返回 null。访问会刷新 LRU 顺序。
  ui.Image? get(int code) {
    final img = _images[code];
    if (img != null) {
      // touch：移到尾部（LinkedHashMap 插入序 = 访问序）
      _images.remove(code);
      _images[code] = img;
    }
    return img;
  }

  /// 异步加载卡片图片（可选降采样解码）：
  /// - L1 命中 → 立即返回（首个解码尺寸即该 code 的缓存尺寸）
  /// - 正在加载 → 等待同一 Future（去重）
  /// - 负面缓存内 → 直接返回 null
  /// - 否则走 L2 磁盘（秒回）→ miss 时 L3 HTTP（带重试），按目标尺寸
  ///   解码后入 L1
  ///
  /// [targetWidth]/[targetHeight] 语义对齐 Image.memCacheWidth：
  /// 解码结果不超过目标尺寸（保持宽高比，allowUpscaling=false 不放大），
  /// 传 null 表示全尺寸。Flame 场地卡槽传小尺寸目标，避免全尺寸
  /// 400px 解码的内存与耗时。
  ///
  /// 注意：L1 命中后**不按更大目标重新解码**——重新解码会经 [_putMemory]
  /// dispose 旧 [ui.Image]，而 Flame 侧 [CardSlotComponent] 仍持有旧图
  /// 引用，`drawImageRect` 对已释放图会断言崩溃。首个解码尺寸即缓存尺寸。
  Future<ui.Image?> load(
    int code, {
    int? targetWidth,
    int? targetHeight,
  }) async {
    final cached = get(code);
    if (cached != null) return cached;

    final existing = _loading[code];
    if (existing != null) return existing.future;

    final failedAt = _failedCodes[code];
    if (failedAt != null &&
        DateTime.now().difference(failedAt) < _negativeCacheTtl) {
      return null;
    }

    final completer = Completer<ui.Image?>();
    _loading[code] = completer;
    try {
      final url = _url(code);
      if (url.isEmpty) {
        completer.complete(null);
        return null;
      }
      final bytes = await _fetchBytesWithRetry(url);
      if (bytes == null) {
        _failedCodes[code] = DateTime.now();
        completer.complete(null);
        return null;
      }
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      _failedCodes.remove(code);
      _putMemory(code, image);
      completer.complete(image);
      return image;
    } catch (_) {
      _failedCodes[code] = DateTime.now();
      completer.complete(null);
      return null;
    } finally {
      _loading.remove(code);
    }
  }

  /// L2 磁盘命中直接读文件；miss 走 HTTP（CacheManager 处理缓存头），
  /// 瞬时失败带退避重试。
  Future<Uint8List?> _fetchBytesWithRetry(
    String url, {
    int attempts = 3,
  }) async {
    for (var i = 0; i < attempts; i++) {
      try {
        final file = await _cacheManager
            .getSingleFile(url)
            .timeout(const Duration(seconds: 20));
        final bytes = await file.readAsBytes();
        return bytes;
      } catch (_) {
        if (i == attempts - 1) return null;
        await Future<void>.delayed(Duration(milliseconds: 150 * (i + 1)));
      }
    }
    return null;
  }

  void _putMemory(int code, ui.Image image) {
    _images.remove(code)?.dispose();
    _images[code] = image;
    while (_images.length > _maxMemoryImages) {
      // keys.first = 最久未访问；注意：若 Flame 侧正持有被逐出的 ui.Image
      // 会渲染失败——与旧版 evict 语义相同的既有风险，调用方应避免长持有。
      _images.remove(_images.keys.first)?.dispose();
    }
  }

  /// 移除指定 code 的内存缓存（释放 GPU 资源）。
  /// [includeDisk] 为 true 时同时删除磁盘缓存（卡图 immutable，一般不需要）。
  Future<void> evict(int code, {bool includeDisk = false}) async {
    _images.remove(code)?.dispose();
    _loading.remove(code);
    if (includeDisk) {
      final url = _url(code);
      if (url.isNotEmpty) await _cacheManager.removeFile(url);
    }
  }

  /// 清空 L1 内存缓存（L2 磁盘层刻意保留——磁盘缓存的价值正是跨会话复用）。
  /// 需要连磁盘一起清时用 [clearDisk]。
  void clear() {
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    _loading.clear();
    _failedCodes.clear();
  }

  /// 连同磁盘缓存一起全清（慎用：下次进入将全量重下）。
  Future<void> clearDisk() async {
    clear();
    await _cacheManager.emptyCache();
  }
}
