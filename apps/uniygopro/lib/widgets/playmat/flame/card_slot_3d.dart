import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../../../stores/duel_room_state.dart';
import 'duel_flame_game.dart';

class CardSlot3DComponent extends PositionComponent with TapCallbacks, HoverCallbacks, HasGameReference<DuelFlameGame> {
  final FieldCard? card;
  final String label;
  final double boardX;
  final double boardY;
  final bool isMonster;
  final bool isEMZ;
  final VoidCallback? onTap;

  bool _isHovered = false;
  double _liftZ = 0; // Z轴提升高度 (模拟 translateZ)
  double _hoverScale = 1.0;

  CardSlot3DComponent({
    this.card,
    required this.label,
    required this.boardX,
    required this.boardY,
    this.isMonster = false,
    this.isEMZ = false,
    this.onTap,
  });

  @override
  void update(double dt) {
    super.update(dt);
    // 缓动提升效果 (Matches HTML transition: 0.3s cubic-bezier(0.34, 1.56, 0.64, 1))
    final targetLift = _isHovered ? 28.0 : 0.0;
    final targetScale = _isHovered ? 1.12 : 1.0;
    
    _liftZ += (targetLift - _liftZ) * 0.15;
    _hoverScale += (targetScale - _hoverScale) * 0.15;
  }

  @override
  void render(Canvas canvas) {
    // 1. 使用游戏统一的投影算法，传入 _liftZ 实现真正的 3D 悬浮
    final projected = game.project3D(boardX, boardY, lift: _liftZ);
    const cardW = 68.0;
    const cardH = 96.0;

    canvas.save();
    canvas.translate(projected.dx, projected.dy);
    canvas.scale(_hoverScale);

    final Color accentColor = isEMZ ? const Color(0xFFFFD700) : const Color(0xFF00F0FF);

    // 2. 绘制 3D 投影发光底座
    if (_isHovered) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: cardW + 16, height: cardH + 16), const Radius.circular(10)),
        Paint()..color = accentColor.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }

    // 3. 槽位边框与背景 (100% 匹配 HTML .slot-3d)
    final slotRRect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH), const Radius.circular(6));
    
    canvas.drawRRect(slotRRect, Paint()..color = accentColor.withOpacity(_isHovered ? 0.18 : 0.04));
    canvas.drawRRect(slotRRect, Paint()
      ..color = _isHovered ? accentColor : accentColor.withOpacity(0.35)
      ..strokeWidth = _isHovered ? 2.0 : 1.5
      ..style = PaintingStyle.stroke);

    if (card == null) {
      // 空位标签
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9, fontWeight: FontWeight.w800, fontFamily: 'Orbitron')),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
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
    final cardRect = Rect.fromCenter(center: Offset.zero, width: w - 2, height: h - 2);
    canvas.drawRRect(RRect.fromRectAndRadius(cardRect, const Radius.circular(5)), 
        Paint()..color = isFaceUp ? const Color(0xFF0D1624) : const Color(0xFF5D4037));

    if (isFaceUp) {
      canvas.drawRRect(RRect.fromRectAndRadius(cardRect.deflate(1), const Radius.circular(4)), 
          Paint()..color = Colors.white.withOpacity(0.7)..style = PaintingStyle.stroke);
    }
    canvas.restore();

    // 攻防徽章 (Matches .atk-badge-3d)
    if (isFaceUp && isMonster && card!.attack != null) {
      final badgeRect = RRect.fromRectAndRadius(Rect.fromLTWH(w / 2 - 28, -h / 2 - 6, 32, 14), const Radius.circular(4));
      canvas.drawRRect(badgeRect, Paint()..color = const Color(0xF2000000));
      canvas.drawRRect(badgeRect, Paint()..color = const Color(0xFFFF0055)..style = PaintingStyle.stroke);
      final tp = TextPainter(
        text: TextSpan(text: '${card!.attack}', style: const TextStyle(color: Color(0xFFFF0055), fontSize: 9, fontWeight: FontWeight.w900, fontFamily: 'Orbitron')),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w / 2 - 28 + (32 - tp.width) / 2, -h / 2 - 6 + (14 - tp.height) / 2));
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    // 由于涉及 3D 投影，使用简单的 AABB 可能会不准，但目前 Flame 组件在 Canvas 坐标系
    final projected = game.project3D(boardX, boardY, lift: _liftZ);
    final dx = (point.x - projected.dx) / _hoverScale;
    final dy = (point.y - projected.dy) / _hoverScale;
    return dx.abs() <= 34 && dy.abs() <= 48;
  }

  @override
  void onHoverEnter() => _isHovered = true;
  @override
  void onHoverExit() => _isHovered = false;
  @override
  void onTapDown(TapDownEvent event) => onTap?.call();
}
