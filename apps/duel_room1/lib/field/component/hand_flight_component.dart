import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../duel_flame_game.dart';
import '../models/hand_fan_layout.dart';
import 'card_paint.dart';

/// 抽卡/发牌飞行动画（Flame effects 版）：
/// 每张飞行卡一个 [SpriteComponent]，移动/淡入由 [MoveEffect] +
/// [EffectController.startDelay] 逐张错位驱动，落地（effect 完成）
/// 回调揭示对应手牌。
///
/// 挂在 camera.viewport（屏幕空间）：起点由卡组槽位世界坐标同步换算
/// （DuelFlameGame.deckSlotWidgetRect），终点由手牌栏卡位直接给出
/// （HandBarComponent.cardSlotRect），全程同一坐标系。
class HandFlightComponent extends PositionComponent
    with HasGameReference<DuelFlameGame> {
  HandFlightComponent({
    required this.codes,
    required this.faceUp,
    required this.source,
    required this.targets,
    required this.onCardArrived,
    required this.onAllDone,
  }) : super(priority: 100);

  /// 每张卡的飞行时长。
  static const double perCardSeconds = 1.4;

  /// 逐张错位延迟：第 i 张比第 i-1 张晚 staggerSeconds 起飞。
  static const double staggerSeconds = 0.35;

  /// 起飞时的淡入时长（错位等待期间卡片不可见，与原实现一致）。
  static const double _fadeInSeconds = 0.15;

  /// 卡码列表（对方抽卡为 0 占位 → 渲染卡背）。
  final List<int> codes;

  /// 是否强制显示卡面（己方抽卡/公开抽卡）。
  final bool faceUp;

  /// 飞行起点（对应方卡组槽位的屏幕矩形）。
  final Rect source;

  /// 每张卡的终点矩形（与 [codes] 一一对应）。
  final List<Rect> targets;

  /// 第 i 张落地回调（揭示对应手牌）。
  final void Function(int index) onCardArrived;

  /// 全部落地回调（页面据此推进抽卡队列）。
  final VoidCallback onAllDone;

  int _completed = 0;

  @override
  void onLoad() {
    super.onLoad();
    final back = CardPaint.cardBackSprite();
    for (var i = 0; i < codes.length; i++) {
      final index = i;
      // 卡面只查缓存：飞行转瞬即逝，异步等网络不如卡背占位流畅。
      final faceImage = codes[i] > 0
          ? game.world.getCachedCardImage(codes[i])
          : null;
      final card = SpriteComponent(
        sprite: (faceUp && faceImage != null) ? Sprite(faceImage) : back,
        size: Vector2(HandFanLayout.cardWidth, HandFanLayout.cardHeight),
        anchor: Anchor.center,
        position: Vector2(source.center.dx, source.center.dy),
      );
      final delay = i * staggerSeconds;
      final move = MoveEffect.to(
        Vector2(
          (i < targets.length ? targets[i] : source).center.dx,
          (i < targets.length ? targets[i] : source).center.dy,
        ),
        EffectController(
          duration: perCardSeconds,
          curve: Curves.easeOutCubic,
          startDelay: delay,
        ),
      );
      move.onComplete = () {
        onCardArrived(index);
        card.removeFromParent();
        _completed++;
        if (_completed == codes.length) {
          onAllDone();
          removeFromParent();
        }
      };
      card.add(move);
      if (delay > 0) {
        // 错位等待期间不可见，起飞瞬间淡入（对齐旧实现 p<=0 不渲染）。
        card.opacity = 0;
        card.add(
          OpacityEffect.to(
            1.0,
            EffectController(duration: _fadeInSeconds, startDelay: delay),
          ),
        );
      }
      add(card);
    }
  }
}
