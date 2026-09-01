import 'dart:ui' as ui;

import 'package:biz/card_image_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter/widget_previews.dart';

/// 统一卡片图片组件。
///
/// 双重加载策略确保任何场景下都能出图：
/// 1. 优先查 [CardImageLoader] L1 内存 [ui.Image] 缓存 → [RawImage] 瞬间渲染
/// 2. miss → [CachedNetworkImage]：与 Flame 侧共享 [CardImageLoader.cacheManager]
///    磁盘层（30 天免重验证 + LRU 文件淘汰）+ Flutter ImageCache 内存层，
///    彻底替代旧版裸 Image.network（无磁盘缓存、被 ImageCache 静默逐出）。
///    同时后台预热 L1 供 Flame 侧复用。
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
      _warmed = false;
      _checkCache();
    }
  }

  void _checkCache() {
    _warmUnifiedCache();
  }

  /// 后台预热 L1（磁盘命中时近乎零成本），供 Flame 侧复用。
  /// 按展示尺寸降采样解码（与 memCacheWidth 同一目标），避免全尺寸
  /// 400px 图占内存。
  void _warmUnifiedCache() {
    if (_warmed) return;
    _warmed = true;
    CardImageLoader.I.load(
      widget.code,
      targetWidth: _decodeWidth(widget.width),
    ).then((img) {
      if (!mounted || img == null) return;
      setState(() {});
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
    // 每次 build 都从 LRU 重新取：淘汰会 dispose 旧 ui.Image，而 Widget
    // 状态里若缓存其引用，重建时 RawImage.clone() 会因 disposed image 崩溃。
    final cached = CardImageLoader.I.get(widget.code);

    Widget content;
    if (cached != null) {
      // L1 命中 → 直接用 ui.Image 渲染
      content = RawImage(
        image: cached,
        width: w,
        height: h,
        fit: widget.fit,
        filterQuality: ui.FilterQuality.low,
      );
    } else {
      // L1 miss → CachedNetworkImage（磁盘 + Flutter ImageCache 内存）
      content = CachedNetworkImage(
        imageUrl: _url,
        cacheManager: CardImageLoader.I.cacheManager,
        fit: widget.fit,
        width: w,
        height: h,
        // 按展示尺寸解码，避免大图占内存（小缩略图不必解码全尺寸）
        memCacheWidth: _decodeWidth(w),
        progressIndicatorBuilder: (context, url, progress) =>
            _placeholder(progress: progress.progress),
        errorWidget: (context, url, error) => _placeholder(),
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

  /// 解码宽度 = 展示宽度 2 倍（Retina），下限 256 保证大图弹窗清晰。
  static int _decodeWidth(double displayWidth) =>
      (displayWidth * 2).round().clamp(256, 1024);

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
Widget previewCardImage() => CardImage(code: 89631139, width: 180, height: 256);
