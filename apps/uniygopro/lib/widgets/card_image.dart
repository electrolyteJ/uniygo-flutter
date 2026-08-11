import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../image/card_image_loader.dart';
import 'package:flutter/widget_previews.dart';

/// 统一卡片图片组件。
///
/// 双重加载策略确保任何场景下都能出图：
/// 1. 优先查 [CardImageLoader] 全局 [ui.Image] 缓存 → [RawImage] 瞬间渲染
/// 2. 缓存 miss → [Image.network] 正常加载（自备 Flutter ImageCache），
///    同时后台预热 [CardImageLoader] 供 Flame 侧复用
class CardImage extends StatefulWidget {
  final int code;
  final double width;
  final double height;
  final BoxFit fit;
  final bool showCodeFallback;

  const CardImage({
    super.key,
    required this.code,
    this.width = 65,
    this.height = 90,
    this.fit = BoxFit.cover,
    this.showCodeFallback = true,
  });

  @override
  State<CardImage> createState() => _CardImageState();
}

class _CardImageState extends State<CardImage> {
  ui.Image? _cachedImage;
  bool _warmed = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  @override
  void didUpdateWidget(covariant CardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _cachedImage = null;
      _warmed = false;
      _checkCache();
    }
  }

  void _checkCache() {
    final img = CardImageLoader.I.get(widget.code);
    if (img != null) {
      setState(() => _cachedImage = img);
    }
    _warmUnifiedCache();
  }

  /// 后台预热统一缓存（仅 miss 时发起一次），供 Flame 侧复用。
  void _warmUnifiedCache() {
    if (_warmed) return;
    _warmed = true;
    final cached = CardImageLoader.I.get(widget.code);
    if (cached != null) return;
    CardImageLoader.I.load(widget.code).then((img) {
      if (!mounted || img == null) return;
      setState(() => _cachedImage = img);
    });
  }

  String get _url {
    final r = CardImageLoader.I.urlResolver;
    return r != null ? r(widget.code) : '';
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = widget.height;
    final cached = _cachedImage;

    Widget content;
    if (cached != null) {
      // 统一缓存命中 → 直接用 ui.Image 渲染
      content = RawImage(
        image: cached,
        width: w,
        height: h,
        fit: widget.fit,
        filterQuality: ui.FilterQuality.low,
      );
    } else {
      // 缓存 miss → Image.network 正常加载，
      // 同时 _warmUnifiedCache 已在后台预热
      content = Image.network(
        _url,
        fit: widget.fit,
        loadingBuilder: _loadingBuilder,
        errorBuilder: _errorBuilder,
      );
    }

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(4), child: content),
    );
  }

  Widget _loadingBuilder(
    BuildContext context,
    Widget child,
    ImageChunkEvent? loadingProgress,
  ) {
    if (loadingProgress == null) return child;
    final total = loadingProgress.expectedTotalBytes;
    final progress =
        total != null ? loadingProgress.cumulativeBytesLoaded / total : null;
    return _placeholder(progress: progress);
  }

  Widget _errorBuilder(
    BuildContext context,
    Object? error,
    StackTrace? stackTrace,
  ) =>
      _placeholder();

  Widget _placeholder({double? progress}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade900],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress != null)
              SizedBox(
                width: widget.width * 0.3,
                height: widget.width * 0.3,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            if (widget.showCodeFallback) ...[
              if (progress != null) const SizedBox(height: 4),
              Text(
                '${widget.code}',
                style: const TextStyle(fontSize: 8, color: Colors.white38),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
@Preview(name: 'CardImage', size: Size(200, 280), brightness: Brightness.dark)
Widget _previewCardImage() => CardImage(code: 89631139, width: 180, height: 256);

