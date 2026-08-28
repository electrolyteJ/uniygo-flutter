import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:duelink/duelink.dart' show POS_DEFENSE;
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import 'package:biz/duel/models/battle_presentation.dart';
import 'package:biz/duel/models/field_zone_key.dart';
import 'package:duel_room1/field/models/flame_field_snapshot.dart';
import 'package:duel_room1/field/duel_field_world.dart';

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

  double _elapsed = 0;
  double _impactTime = 0;
  BattlePresentation? _lastPresentation;
  bool _wasInDamageStep = false;

  // ── 光束渲染缓存 ──
  // path / 渐变 shader / PathMetric 仅在攻守双方位置变化时重建，
  // 避免每帧 LinearGradient.createShader + path.computeMetrics()。
  static const _beamGradient = LinearGradient(
    colors: [
      Color(0x00FFF6AA),
      Color(0xBBFFF6AA),
      Color(0xFFF67B4B),
      Color(0xB900F0FF),
      Color(0x0000F0FF),
    ],
    stops: [0, 0.2, 0.5, 0.8, 1],
  );
  Path? _beamPath;
  Shader? _beamShader;
  ui.PathMetric? _beamMetric;
  double _beamStartX = double.nan;
  double _beamStartY = double.nan;
  double _beamEndX = double.nan;
  double _beamEndY = double.nan;

  // 动态 pulse 线宽留在热路径：复用 Paint，每帧只改 strokeWidth/shader。
  final Paint _beamGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
  static final _beamCorePaint = Paint()
    ..color = const Color(0xFFFFF6D6).withValues(alpha: 0.95)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 3.2;
  static final _projectileGlowPaint = Paint()
    ..color = const Color(0xFFFFF6D6)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  static final _projectileCorePaint = Paint()
    ..color = const Color(0xFFFF7A59);

  /// 当前状态快照（widget 层经游戏推入）。
  FlameFieldSnapshot get _snapshot => world.game.snapshot;

  BattlePresentationComponent() : super(priority: 30);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    final presentation = _snapshot.battlePresentation;
    if (!identical(_lastPresentation, presentation)) {
      _lastPresentation = presentation;
      _impactTime = 0;
    }

    if (_snapshot.inDamageStep) {
      _impactTime += dt;
    } else if (_wasInDamageStep) {
      _impactTime = 0;
    }
    _wasInDamageStep = _snapshot.inDamageStep;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final presentation = _snapshot.battlePresentation;
    if (presentation == null) return;

    final attacker = world.worldPositionForZoneKey(
      presentation.attackerZoneKey,
    );
    if (attacker == null) return;

    final defender = presentation.defenderZoneKey == null
        ? _directAttackTarget(presentation.attackerZoneKey)
        : world.worldPositionForZoneKey(presentation.defenderZoneKey!);
    if (defender == null) return;

    final start = Offset(attacker.x, attacker.y);
    final end = Offset(defender.x, defender.y);
    final path = _beamPathFor(start, end);

    _drawFocus(
      canvas,
      center: start,
      color: const Color(0xFFFF7A59),
      radius: _snapshot.inDamageStep ? 54 : 42,
      intensity: _snapshot.inDamageStep ? 1.0 : 0.72,
    );

    if (!presentation.isDirectAttack) {
      _drawFocus(
        canvas,
        center: end,
        color: const Color(0xFF00F0FF),
        radius: _snapshot.inDamageStep ? 54 : 42,
        intensity: _snapshot.inDamageStep ? 1.0 : 0.72,
      );
    }

    _drawBeam(canvas, path);
    _drawProjectile(canvas, path);
    if (_snapshot.inDamageStep) {
      _drawImpact(canvas, end, presentation.isDirectAttack);
    }

    _drawInfoPlate(
      canvas,
      anchor: start,
      alignRight: _slotBelongsToSelf(presentation.attackerZoneKey),
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
      alignRight: !_slotBelongsToSelf(presentation.defenderZoneKey!),
      title: presentation.defenderName ?? '怪兽',
      value: _battleValueLabel(
        presentation.defenderAttack,
        presentation.defenderDefense,
        presentation.defenderPosition,
      ),
      accent: const Color(0xFF00F0FF),
    );
  }

  /// 直接攻击的目标点：攻击方的「棋盘坐标 x」+ 越过底/顶行的 y，再投影。
  /// 注意必须取棋盘坐标（[DuelFieldWorld.boardPositionForZoneKey]），
  /// 不能复用 render 里已投影的世界坐标，否则恢复 3D 投影后会二次投影错位。
  Vector2? _directAttackTarget(String attackerZoneKey) {
    final board = world.boardPositionForZoneKey(attackerZoneKey);
    if (board == null) return null;
    final towardTop = _slotBelongsToSelf(attackerZoneKey);
    final targetY = towardTop
        ? -DuelFieldLayout.stY - 72
        : DuelFieldLayout.stY + 72;
    return world.project3D(board.x, targetY);
  }

  /// 攻守位置不变时复用缓存的 beam path（同时刷新渐变 shader 与 PathMetric）。
  Path _beamPathFor(Offset start, Offset end) {
    var path = _beamPath;
    if (path == null ||
        start.dx != _beamStartX ||
        start.dy != _beamStartY ||
        end.dx != _beamEndX ||
        end.dy != _beamEndY) {
      _beamStartX = start.dx;
      _beamStartY = start.dy;
      _beamEndX = end.dx;
      _beamEndY = end.dy;
      final control = _beamControlPoint(start, end);
      path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      _beamPath = path;
      _beamShader = _beamGradient.createShader(path.getBounds().inflate(24));
      _beamMetric = path.computeMetrics().firstOrNull;
    }
    return path;
  }

  bool _slotBelongsToSelf(String slotId) {
    return parseZoneKey(slotId)?.controller == _snapshot.myController;
  }

  Offset _beamControlPoint(Offset start, Offset end) {
    final midX = (start.dx + end.dx) / 2;
    final midY = (start.dy + end.dy) / 2;
    final travelUp = end.dy < start.dy;
    return Offset(midX, midY + (travelUp ? -26 : 26));
  }

  void _drawBeam(Canvas canvas, Path path) {
    final pulse = 0.82 + (math.sin(_elapsed * 8) * 0.18);

    canvas.drawPath(
      path,
      _beamGlowPaint
        ..shader = _beamShader
        ..strokeWidth = 12 * pulse,
    );

    canvas.drawPath(path, _beamCorePaint);
  }

  void _drawProjectile(Canvas canvas, Path path) {
    // PathMetric 随 path 缓存（见 _beamPathFor），每条 path 只取一次。
    final metric = _beamMetric;
    if (metric == null) return;
    final progress = (_elapsed * 1.9) % 1;
    final tangent = metric.getTangentForOffset(metric.length * progress);
    if (tangent == null) return;

    canvas.drawCircle(tangent.position, 8, _projectileGlowPaint);
    canvas.drawCircle(tangent.position, 3.4, _projectileCorePaint);
  }

  void _drawImpact(Canvas canvas, Offset center, bool isDirectAttack) {
    final pulse = (_impactTime * 3.8).clamp(0.0, 1.8).toDouble();
    final coreColor = isDirectAttack
        ? const Color(0xFFFFC857)
        : const Color(0xFF00F0FF);
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

    canvas.drawRRect(rect, Paint()..color = const Color(0xD9111722));
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
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 34),
        width: width,
        height: height,
      ),
      const Radius.circular(999),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xD9FFC857));
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
    final isDefense = position != null && (position & POS_DEFENSE) != 0;
    if (isDefense) {
      return 'DEF ${defense ?? '?'}';
    }
    return 'ATK ${attack ?? '?'}';
  }
}
