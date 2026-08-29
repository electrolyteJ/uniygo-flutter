import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../duel_flame_game.dart';
import '../util/hand_fan_layout.dart';
import 'card_paint.dart';

/// 通用飞卡动画（Flame effects 版）：任意源矩形 → 目标矩形列表，
/// 每张飞行卡一个 [SpriteComponent]，移动/淡入由 [MoveEffect] +
/// [EffectController.startDelay] 逐张错位驱动，落地回调逐张触发。
///
/// 挂在 camera.viewport（屏幕空间）：卡组→手牌抽卡、场上↔墓地↔手牌等
/// 全区域双向联动飞牌共用（前者经兼容别名 HandFlightComponent）。
class CardFlightComponent extends PositionComponent
    with HasGameReference<DuelFlameGame> {
  CardFlightComponent({
    required this.codes,
    required this.faceUp,
    required this.source,
    required this.targets,
    required this.onCardArrived,
    required this.onAllDone,
    this.cardSize = const Size(
      HandFanLayout.cardWidth,
      HandFanLayout.cardHeight,
    ),
    this.perCardDuration = perCardSeconds,
    this.stagger = staggerSeconds,
  }) : super(priority: 100);

  /// 每张卡的飞行时长（抽卡默认值；移动飞牌更快）。
  static const double perCardSeconds = 1.4;

  /// 逐张错位延迟：第 i 张比第 i-1 张晚 staggerSeconds 起飞。
  static const double staggerSeconds = 0.35;

  /// 起飞时的淡入时长（错位等待期间卡片不可见，与原实现一致）。
  static const double _fadeInSeconds = 0.15;

  /// 卡码列表（0 占位 → 渲染卡背）。
  final List<int> codes;

  /// 是否显示卡面（false 渲染卡背）。
  final bool faceUp;

  /// 飞行起点（屏幕矩形）。
  final Rect source;

  /// 每张卡的终点矩形（与 [codes] 一一对应）。
  final List<Rect> targets;

  /// 第 i 张落地回调。
  final void Function(int index) onCardArrived;

  /// 全部落地回调。
  final VoidCallback onAllDone;

  /// 卡体尺寸（抽卡=手牌卡尺寸；场上移动=场地槽位尺寸）。
  final Size cardSize;

  /// 单张飞行时长（秒）。
  final double perCardDuration;

  /// 逐张错位（秒）。
  final double stagger;

  int _completed = 0;

  /// 飞行期间持有的卡图克隆：加载器 LRU 驱逐会 dispose 原图，
  /// 飞行途中渲染必须自持克隆；组件移除时统一释放。
  final List<ui.Image> _faceClones = [];

  @override
  void onRemove() {
    for (final clone in _faceClones) {
      clone.dispose();
    }
    _faceClones.clear();
    super.onRemove();
  }

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
      final faceClone = faceUp ? faceImage?.clone() : null;
      if (faceClone != null) _faceClones.add(faceClone);
      final card = SpriteComponent(
        sprite: faceClone != null ? Sprite(faceClone) : back,
        size: Vector2(cardSize.width, cardSize.height),
        anchor: Anchor.center,
        position: Vector2(source.center.dx, source.center.dy),
      );
      final delay = i * stagger;
      final move = MoveEffect.to(
        Vector2(
          (i < targets.length ? targets[i] : source).center.dx,
          (i < targets.length ? targets[i] : source).center.dy,
        ),
        EffectController(
          duration: perCardDuration,
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
