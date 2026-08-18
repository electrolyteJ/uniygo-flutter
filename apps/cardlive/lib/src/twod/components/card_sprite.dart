import 'dart:async';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 卡图精灵组件 —— 加载卡图并带有缩放/旋转/发光动画
class CardSpriteComponent extends SpriteComponent {
  final String imageUrl;
  final double targetScale;
  bool _loaded = false;

  CardSpriteComponent({
    required this.imageUrl,
    required Vector2 size,
    this.targetScale = 1.0,
  }) : super(size: size, anchor: Anchor.center, priority: 10);

  double materializeProgress = 0.0;

  @override
  Future<void> onLoad() async {
    await _loadFromNetwork();
  }

  Future<void> _loadFromNetwork() async {
    try {
      final completer = Completer<ui.Image>();
      final stream =
          NetworkImage(imageUrl).resolve(ImageConfiguration.empty);
      stream.addListener(ImageStreamListener(
        (info, _) => completer.complete(info.image),
        onError: (e, s) => completer.completeError(e),
      ));
      final image = await completer.future;

      // 创建带缩放目标尺寸的 sprite
      final sprite = Sprite(image);
      final targetSize = size * targetScale;
      final scaleFactor = (targetSize.x / image.width)
          .clamp(0.5, 2.0);

      this.sprite = sprite;
      this.scale = Vector2.all(scaleFactor * 0.2); // 初始很小
      _loaded = true;
    } catch (e) {
      debugPrint('CardSprite: 图片加载失败 $e');
    }
  }

  bool get isLoaded => _loaded;
}
