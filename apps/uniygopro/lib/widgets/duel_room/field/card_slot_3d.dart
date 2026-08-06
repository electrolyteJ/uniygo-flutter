import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import '../../../models/FieldCard.dart';
import 'duel_field_world.dart';

class CardSlot3DComponent extends PositionComponent
    with TapCallbacks, HoverCallbacks, HasWorldReference<DuelFieldWorld> {
  /// hover 动画曲线，与 HTML transition: 0.3s cubic-bezier(0.34, 1.56, 0.64, 1) 一致。
  static const _hoverCurve = Cubic(0.34, 1.56, 0.64, 1);
  static const _hoverScale = 1.12;
  static const _hoverLift = 28.0;

  // TextPaint 内部按文本缓存 TextPainter，避免每帧重新 layout。
  static final _labelPaint = TextPaint(
    style: TextStyle(
      color: Colors.white.withOpacity(0.35),
      fontSize: 9,
      fontWeight: FontWeight.w800,
      fontFamily: 'Orbitron',
    ),
  );
  static final _badgePaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFF0055),
      fontSize: 9,
      fontWeight: FontWeight.w900,
      fontFamily: 'Orbitron',
    ),
  );

  final FieldCard? card;
  final String label;
  final double boardX;
  final double boardY;
  final bool isMonster;
  final bool isEMZ;
  final VoidCallback? onTap;

  bool _hovered = false;
  double _liftZ = 0; // Z轴提升高度 (模拟 translateZ)
  Effect? _scaleFx;
  Effect? _liftFx;

  CardSlot3DComponent({
    this.card,
    required this.label,
    required this.boardX,
    required this.boardY,
    this.isMonster = false,
    this.isEMZ = false,
    this.onTap,
  }) : super(
         size: Vector2(DuelFieldLayout.slotWidth, DuelFieldLayout.slotHeight),
         anchor: Anchor.center,
       );

  /// hover 缩放/提升共用 [_hoverCurve]：缩放走 Flame 内置的
  /// [ScaleEffect]（围绕 anchor 中心、命中测试自动适配），lift 需经过
  /// [DuelFieldWorld.projectLiftY] 投影，用 [FunctionEffect] 从当前值起播，
  /// 中途反向不会跳变。
  void _animateHover(bool hovering) {
    _scaleFx?.removeFromParent();
    _liftFx?.removeFromParent();
    final startLift = _liftZ;
    final endLift = hovering ? _hoverLift : 0.0;
    _scaleFx = ScaleEffect.to(
      Vector2.all(hovering ? _hoverScale : 1.0),
      CurvedEffectController(0.3, _hoverCurve),
    );
    _liftFx = FunctionEffect<CardSlot3DComponent>(
      (target, progress) =>
          target._liftZ = startLift + (endLift - startLift) * progress,
      CurvedEffectController(0.3, _hoverCurve),
    );
    addAll([_scaleFx!, _liftFx!]);
  }

  @override
  void render(Canvas canvas) {
    const cardW = DuelFieldLayout.slotWidth;
    const cardH = DuelFieldLayout.slotHeight;

    // 1. 组件 position 已由 world 投影设置，hover 缩放由 Flame transform
    // 围绕 anchor(中心) 应用；此处仅叠加 Z 轴提升位移（世界坐标 y 方向），
    // 除以 scale.y 抵消变换缩放，保持世界坐标下的提升量。
    final liftDy = world.projectLiftY(_liftZ) / scale.y;

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 + liftDy);

    final Color accentColor = isEMZ
        ? const Color(0xFFFFD700)
        : const Color(0xFF00F0FF);

    // 2. 绘制 3D 投影发光底座
    if (_hovered) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: cardW + 16,
            height: cardH + 16,
          ),
          const Radius.circular(10),
        ),
        Paint()
          ..color = accentColor.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }

    // 3. 槽位边框与背景 (100% 匹配 HTML .slot-3d)
    final slotRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
      const Radius.circular(6),
    );

    canvas.drawRRect(
      slotRRect,
      Paint()..color = accentColor.withOpacity(_hovered ? 0.18 : 0.04),
    );
    canvas.drawRRect(
      slotRRect,
      Paint()
        ..color = _hovered ? accentColor : accentColor.withOpacity(0.35)
        ..strokeWidth = _hovered ? 2.0 : 1.5
        ..style = PaintingStyle.stroke,
    );

    if (card == null) {
      // 空位标签
      _labelPaint.render(canvas, label, Vector2.zero(), anchor: Anchor.center);
    } else {
      _renderCardBody(canvas, cardW, cardH);
    }

    canvas.restore();
  }

  void _renderCardBody(Canvas canvas, double w, double h) {
    final pos = card!.position;
    final isFaceUp = (pos & 0x1 != 0) || (pos & 0x2 != 0);
    final isDefense = (pos & 0x2 != 0) || (pos & 0x8 != 0);

    canvas.save();
    if (isDefense) canvas.rotate(pi / 2);

    // 卡片背景
    final cardRect = Rect.fromCenter(
      center: Offset.zero,
      width: w - 2,
      height: h - 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, const Radius.circular(5)),
      Paint()
        ..color = isFaceUp ? const Color(0xFF0D1624) : const Color(0xFF5D4037),
    );

    if (isFaceUp) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(cardRect.deflate(1), const Radius.circular(4)),
        Paint()
          ..color = Colors.white.withOpacity(0.7)
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.restore();

    // 攻防徽章 (Matches .atk-badge-3d)
    if (isFaceUp && isMonster && card!.attack != null) {
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w / 2 - 28, -h / 2 - 6, 32, 14),
        const Radius.circular(4),
      );
      canvas.drawRRect(badgeRect, Paint()..color = const Color(0xF2000000));
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = const Color(0xFFFF0055)
          ..style = PaintingStyle.stroke,
      );
      _badgePaint.render(
        canvas,
        '${card!.attack}',
        Vector2(w / 2 - 28 + 16, -h / 2 - 6 + 7),
        anchor: Anchor.center,
      );
    }
  }

  @override
  void onHoverEnter() {
    _hovered = true;
    _animateHover(true);
  }

  @override
  void onHoverExit() {
    _hovered = false;
    _animateHover(false);
  }

  @override
  void onTapDown(TapDownEvent event) => onTap?.call();
}
