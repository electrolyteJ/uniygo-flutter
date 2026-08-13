import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../../../../models/battle_presentation.dart';
import '../../../../models/field_zone_key.dart';
import '../../../../pages/duel_room/duel/bloc/duel_bloc.dart';
import '../../../../pages/duel_room/duel/bloc/duel_state.dart';
import '../duel_field_world.dart';

class BattlePresentationComponent extends Component
    with HasWorldReference<DuelFieldWorld> {
  static final _namePaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      fontFamily: 'Orbitron',
    ),
  );

  static final _valuePaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      fontFamily: 'Orbitron',
    ),
  );

  final DuelBloc duelBloc;

  /// 当前对局状态快照（便捷访问，等价于 duelBloc.state）。
  DuelState get duelStore => duelBloc.state;

  double _elapsed = 0;
  double _impactTime = 0;
  BattlePresentation? _lastPresentation;
  bool _wasInDamageStep = false;

  BattlePresentationComponent({required this.duelBloc}) : super(priority: 30);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    final presentation = duelStore.battlePresentation;
    if (!identical(_lastPresentation, presentation)) {
      _lastPresentation = presentation;
      _impactTime = 0;
    }

    if (duelStore.inDamageStep) {
      _impactTime += dt;
    } else if (_wasInDamageStep) {
      _impactTime = 0;
    }
    _wasInDamageStep = duelStore.inDamageStep;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final presentation = duelStore.battlePresentation;
    if (presentation == null) return;

    final attacker = world.worldPositionForSlotId(presentation.attackerSlotId);
    if (attacker == null) return;

    final defender =
        presentation.defenderSlotId == null
            ? _directAttackTarget(attacker, presentation.attackerSlotId)
            : world.worldPositionForSlotId(presentation.defenderSlotId!);
    if (defender == null) return;

    final start = Offset(attacker.x, attacker.y);
    final end = Offset(defender.x, defender.y);
    final control = _beamControlPoint(start, end);
    final path =
        Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    _drawFocus(
      canvas,
      center: start,
      color: const Color(0xFFFF7A59),
      radius: duelStore.inDamageStep ? 54 : 42,
      intensity: duelStore.inDamageStep ? 1.0 : 0.72,
    );

    if (!presentation.isDirectAttack) {
      _drawFocus(
        canvas,
        center: end,
        color: const Color(0xFF00F0FF),
        radius: duelStore.inDamageStep ? 54 : 42,
        intensity: duelStore.inDamageStep ? 1.0 : 0.72,
      );
    }

    _drawBeam(canvas, path);
    _drawProjectile(canvas, path);
    if (duelStore.inDamageStep) {
      _drawImpact(canvas, end, presentation.isDirectAttack);
    }

    _drawInfoPlate(
      canvas,
      anchor: start,
      alignRight: _slotBelongsToSelf(presentation.attackerSlotId),
      title: presentation.attackerName,
      value: _battleValueLabel(
        presentation.attackerAttack,
        presentation.attackerDefense,
        presentation.attackerPosition,
      ),
      accent: const Color(0xFFFF7A59),
    );

    if (presentation.isDirectAttack) {
      _drawDirectLabel(canvas, end);
      return;
    }

    _drawInfoPlate(
      canvas,
      anchor: end,
      alignRight: !_slotBelongsToSelf(presentation.defenderSlotId!),
      title: presentation.defenderName ?? '怪兽',
      value: _battleValueLabel(
        presentation.defenderAttack,
        presentation.defenderDefense,
        presentation.defenderPosition,
      ),
      accent: const Color(0xFF00F0FF),
    );
  }

  Vector2 _directAttackTarget(Vector2 attacker, String attackerSlotId) {
    final towardTop = _slotBelongsToSelf(attackerSlotId);
    final targetY =
        towardTop
            ? -DuelFieldLayout.stY - 72
            : DuelFieldLayout.stY + 72;
    return world.project3D(attacker.x, targetY);
  }

  bool _slotBelongsToSelf(String slotId) {
    return parseZoneKey(slotId)?.controller == duelStore.myController;
  }

  Offset _beamControlPoint(Offset start, Offset end) {
    final midX = (start.dx + end.dx) / 2;
    final midY = (start.dy + end.dy) / 2;
    final travelUp = end.dy < start.dy;
    return Offset(midX, midY + (travelUp ? -26 : 26));
  }

  void _drawBeam(Canvas canvas, Path path) {
    final pulse = 0.82 + (math.sin(_elapsed * 8) * 0.18);
    final bounds = path.getBounds().inflate(24);
    final gradient = LinearGradient(
      colors: const [
        Color(0x00FFF6AA),
        Color(0xBBFFF6AA),
        Color(0xFFF67B4B),
        Color(0xB900F0FF),
        Color(0x0000F0FF),
      ],
      stops: const [0, 0.2, 0.5, 0.8, 1],
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = gradient.createShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 12 * pulse
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFF6D6).withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.2,
    );
  }

  void _drawProjectile(Canvas canvas, Path path) {
    final metric = path.computeMetrics().firstOrNull;
    if (metric == null) return;
    final progress = (_elapsed * 1.9) % 1;
    final tangent = metric.getTangentForOffset(metric.length * progress);
    if (tangent == null) return;

    canvas.drawCircle(
      tangent.position,
      8,
      Paint()
        ..color = const Color(0xFFFFF6D6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      tangent.position,
      3.4,
      Paint()..color = const Color(0xFFFF7A59),
    );
  }

  void _drawImpact(Canvas canvas, Offset center, bool isDirectAttack) {
    final pulse = (_impactTime * 3.8).clamp(0.0, 1.8).toDouble();
    final coreColor =
        isDirectAttack ? const Color(0xFFFFC857) : const Color(0xFF00F0FF);
    final outerRadius = 18 + (pulse * 28);

    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..color = coreColor.withValues(alpha: (0.34 - pulse * 0.12).clamp(0, 1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      center,
      14,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _drawFocus(
    Canvas canvas, {
    required Offset center,
    required Color color,
    required double radius,
    required double intensity,
  }) {
    final glowAlpha = (0.18 + math.sin(_elapsed * 6).abs() * 0.18) * intensity;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: glowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(
      center,
      radius - 10,
      Paint()
        ..color = color.withValues(alpha: 0.5 * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  void _drawInfoPlate(
    Canvas canvas, {
    required Offset anchor,
    required bool alignRight,
    required String title,
    required String value,
    required Color accent,
  }) {
    final titleMetrics = _namePaint.getLineMetrics(title);
    final valueMetrics = _valuePaint.getLineMetrics(value);
    final width = math.max(titleMetrics.width, valueMetrics.width) + 20;
    const height = 34.0;
    final dx = alignRight ? anchor.dx - width - 48 : anchor.dx + 48;
    final dy = anchor.dy - 20;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(dx, dy, width, height),
      const Radius.circular(10),
    );

    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xD9111722),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = accent.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawRect(
      Rect.fromLTWH(dx + 8, dy + height - 6, width - 16, 2),
      Paint()..color = accent.withValues(alpha: 0.85),
    );

    _namePaint.render(
      canvas,
      title,
      Vector2(dx + 10, dy + 8),
      anchor: Anchor.topLeft,
    );
    _valuePaint.render(
      canvas,
      value,
      Vector2(dx + 10, dy + 19),
      anchor: Anchor.topLeft,
    );
  }

  void _drawDirectLabel(Canvas canvas, Offset center) {
    const label = 'DIRECT';
    final metrics = _valuePaint.getLineMetrics(label);
    final width = metrics.width + 18;
    const height = 24.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, center.dy - 34), width: width, height: height),
      const Radius.circular(999),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xD9FFC857),
    );
    _valuePaint.render(
      canvas,
      label,
      Vector2(rect.center.dx, rect.center.dy),
      anchor: Anchor.center,
    );
  }

  String _battleValueLabel(int? attack, int? defense, int? position) {
    if (attack == null && defense == null) {
      return 'ATK ?';
    }
    final isDefense = position != null && (position & 0x0C) != 0;
    if (isDefense) {
      return 'DEF ${defense ?? '?'}';
    }
    return 'ATK ${attack ?? '?'}';
  }
}
