import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../duel_field_world.dart';

/// 场地正中央计时器：仅显示当前回合方的剩余时间（MM:SS）。
///
/// 位置固定在世界原点——两个 EMZ 槽位（x=±84，半宽 34 → 内沿 ±50）
/// 之间的空位正中，88 宽的底板不压任何槽位。
///
/// 数据每帧直读 [DuelFlameGame.snapshot]（selfTimeLeft /
/// opponentTimeLeft 由 TIME_LIMIT 推送）；为 0（未下发）时隐藏。
/// ≤30s 变红，否则金色（对齐旧 widget PhaseBar 语义）。
class CenterTimerComponent extends PositionComponent
    with HasWorldReference<DuelFieldWorld> {
  CenterTimerComponent()
    : super(anchor: Anchor.center, size: Vector2(_width, _height));

  static const _width = 88.0;
  static const _height = 30.0;

  static const _urgentColor = Color(0xFFFF4D4D);
  static const _normalColor = Color(0xFFFFD700);

  static final _backdropPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.55);

  static TextPaint _textPaint(Color color) => TextPaint(
    style: TextStyle(
      color: color,
      fontSize: 15,
      fontWeight: FontWeight.w900,
      fontFamily: 'Orbitron',
      letterSpacing: 1.2,
    ),
  );

  static String _format(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void render(Canvas canvas) {
    final snapshot = world.game.snapshot;
    final seconds = snapshot.currentPlayer == snapshot.myController
        ? snapshot.selfTimeLeft
        : snapshot.opponentTimeLeft;
    if (seconds <= 0) return;

    final urgent = seconds <= 30;
    final color = urgent ? _urgentColor : _normalColor;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size.toSize(),
      const Radius.circular(_height / 2),
    );
    canvas.drawRRect(rect, _backdropPaint);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    _textPaint(color).render(
      canvas,
      _format(seconds),
      Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
    );
  }
}
