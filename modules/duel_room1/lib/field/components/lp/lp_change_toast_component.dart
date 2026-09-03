import 'dart:math';

import 'package:biz/duel/models/lp_change_event.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../duel_field_game.dart';
import 'lp_toast_feed.dart';
import '../hand_card/hand_bar_component.dart';

/// LP 变动锚定 toast（viewport 屏幕空间）：伤害/回复/支付/直接变值时，
/// 在受影响玩家的手牌栏附近弹出大字号变动数字 + 类型标签——
/// 我方 toast 在我方手牌栏正上方居中，对方 toast 在对方手牌栏正下方居中。
///
/// 每帧直读 [DuelFieldGame.snapshot] 的 lpChangeTick/lpChangeEvent 做
/// tick diff；同侧同 kind 0.8s 内的连续变动由 [LpToastFeed] 合并累加。
/// 动画：缩放弹入（150ms）→ 停留 → 上飘淡出（末 350ms），全程 1.4s。
///
/// 挂 viewport（与 HandBarComponent 同层）：不随场地相机缩放，
/// 位置只依赖屏幕尺寸与对方手牌栏 hudTopY。
class LpChangeToastComponent extends PositionComponent
    with HasGameReference<DuelFieldGame> {
  LpChangeToastComponent({required this.isSelf})
    : super(anchor: Anchor.center, size: Vector2(116, 46));

  /// 是否锚定我方手牌栏（对方 toast 锚对方手牌栏）。
  final bool isSelf;

  final LpToastFeed _feed = LpToastFeed();
  int _lastTick = 0;

  static const _totalMs = 1400.0;
  static const _scaleInMs = 150.0;
  static const _fadeOutMs = 350.0;

  /// toast 与手牌栏的纵向间隙。
  static const _gap = 8.0;

  /// 相机 zoom 缓存：world 层时代toast 随场地缩放，挪到 viewport 层后
  /// 1:1 像素显小——渲染时按 zoom 等比放大，观感与原尺寸一致。
  double _zoom = 1.0;

  void _syncPosition() {
    // 我方：手牌栏（屏显高度 = 96 × hudScale，贴底并让开 Home 指示条）
    // 正上方；对方：手牌栏正下方。
    final halfH = size.y / 2;
    final barVisualH =
        HandBarComponent.barHeight * game.hudScale;
    final y = isSelf
        ? game.size.y -
            game.viewPadding.bottom -
            barVisualH -
            HandBarComponent.bottomPadding -
            _gap -
            halfH
        : (game.oppHandBar?.hudTopY ?? 0) +
            barVisualH +
            _gap +
            halfH;
    position = Vector2(game.size.x / 2, y);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _syncPosition();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _syncPosition();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncPosition();
    // toast 尺寸跟随场地 zoom（对齐世界层时代的观感），但夹紧下限——
    // 手机横屏 zoom ≈0.4 时不缩到不可读。
    _zoom = game.camera.viewfinder.zoom.clamp(0.85, 1.3);
    final snapshot = game.snapshot;
    final tick = snapshot.lpChangeTick;
    if (tick < _lastTick) {
      // 新一局开始（tick 归零回退）：清空未播完的 toast。
      _feed.reset();
    } else if (tick > _lastTick) {
      final event = snapshot.lpChangeEvent;
      if (event != null) {
        final eventIsSelf = event.player == snapshot.myController;
        if (eventIsSelf == isSelf) {
          _feed.add(event);
        }
      }
    }
    _lastTick = tick;
    _feed.tick(Duration(microseconds: (dt * 1000000).round()));
  }

  @override
  void render(Canvas canvas) {
    final entry = _feed.current;
    if (entry == null) return;

    final elapsedMs = _feed.elapsed.inMicroseconds / 1000.0;

    // 弹入缩放（easeOutBack）。
    final scaleT = (elapsedMs / _scaleInMs).clamp(0.0, 1.0);
    final scale = _easeOutBack(scaleT);
    // 末段上飘 + 淡出。
    final fadeT =
        ((elapsedMs - (_totalMs - _fadeOutMs)) / _fadeOutMs).clamp(0.0, 1.0);
    final opacity = 1.0 - fadeT;
    final rise = fadeT * 18;

    final color = switch (entry.kind) {
      LpChangeKind.damage => const Color(0xFFFF5252),
      LpChangeKind.recover => const Color(0xFF69F0AE),
      LpChangeKind.pay => const Color(0xFFFFD740),
      LpChangeKind.set => const Color(0xFF90A4AE),
    };
    final label = switch (entry.kind) {
      LpChangeKind.damage => '伤害',
      LpChangeKind.recover => '回复',
      LpChangeKind.pay => '支付',
      LpChangeKind.set => '变动',
    };
    final deltaText =
        entry.delta > 0 ? '+${entry.delta}' : '${entry.delta}';

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 - rise * _zoom);
    canvas.scale(scale * _zoom);

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.x,
        height: size.y,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xE6080E18).withValues(alpha: 0.9 * opacity),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.7 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    TextPaint(
      style: TextStyle(
        color: color.withValues(alpha: opacity),
        fontSize: 18,
        fontWeight: FontWeight.w900,
        fontFamily: 'Orbitron',
      ),
    ).render(canvas, deltaText, Vector2(0, -7), anchor: Anchor.center);
    TextPaint(
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.85 * opacity),
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ).render(canvas, label, Vector2(0, 12), anchor: Anchor.center);

    canvas.restore();
  }

  double _easeOutBack(double x) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2);
  }
}
