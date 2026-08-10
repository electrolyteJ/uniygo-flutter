import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'card_image_loader.dart';

/// 统一卡片图片组件。
///
/// 完全基于 [CardImageLoader] 全局缓存加载图片：
/// - 命中缓存（含 Flame 侧已加载的 [ui.Image]）→ 直接 [RawImage] 渲染，零网络、零解码
/// - 未命中 → 后台通过 [CardImageLoader] 下载/解码，完成后自动切换到 [RawImage]
///
/// Flame 与 Flutter Widget 共用同一份 [ui.Image] 缓存，彻底消除重复加载。
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
  ui.Image? _image;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant CardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) _sync();
  }

  void _sync() {
    final cached = CardImageLoader.I.get(widget.code);
    if (cached != null) {
      _image = cached;
      _loading = false;
      return;
    }
    _image = null;
    if (_loading) return;
    _loading = true;
    CardImageLoader.I.load(widget.code).then((img) {
      if (!mounted) return;
      _image = img;
      _loading = false;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: img != null
            ? RawImage(
                image: img,
                fit: widget.fit,
                filterQuality: ui.FilterQuality.low,
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade900],
        ),
      ),
      child: Center(
        child: widget.showCodeFallback
            ? Text(
                '${widget.code}',
                style: const TextStyle(fontSize: 8, color: Colors.white38),
              )
            : null,
      ),
    );
  }
}
