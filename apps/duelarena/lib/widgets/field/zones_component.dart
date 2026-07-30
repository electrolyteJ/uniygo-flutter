import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/duel_state.dart';
import 'field_layout.dart';
import 'projection.dart';

/// Draws every field zone outline plus the glowing center line.
/// Each zone is its own [ZoneComponent] child, mirroring the zone
/// GameObjects in YGOProUnity_V2's duel field.
class ZonesComponent extends Component {
  final FieldCamera camera;
  final List<ZonePosition> zones;
  final DuelState state;

  ZonesComponent({
    required this.camera,
    required this.zones,
    required this.state,
  });

  double _time = 0;

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  Future<void> onLoad() async {
    for (final zone in zones) {
      await add(ZoneComponent(camera: camera, zone: zone, state: state));
    }
  }

  @override
  void renderTree(Canvas canvas) {
    super.renderTree(canvas);
    _drawCenterLine(canvas);
  }

  void _drawCenterLine(Canvas canvas) {
    const hw = FieldLayout.groundHalfW * 0.85;
    final p1 = camera.project(Vec3(-hw, 0.02, 0));
    final p2 = camera.project(Vec3(hw, 0.02, 0));
    if (p1 == null || p2 == null) return;

    final time = _time;
    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..strokeWidth = 6
        ..color = Colors.amber
            .withValues(alpha: 0.06 + 0.03 * math.sin(time * 2))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..strokeWidth = 1.5
        ..shader = ui.Gradient.linear(p1, p2, [
          Colors.transparent,
          Colors.amber.withValues(alpha: 0.6),
          Colors.orangeAccent.withValues(alpha: 0.8),
          Colors.amber.withValues(alpha: 0.6),
          Colors.transparent,
        ], [0.0, 0.25, 0.5, 0.75, 1.0]),
    );
  }
}

class ZoneComponent extends Component {
  final FieldCamera camera;
  final ZonePosition zone;
  final DuelState state;

  ZoneComponent({
    required this.camera,
    required this.zone,
    required this.state,
  });

  Color get _color {
    switch (zone.kind) {
      case ZoneKind.monster:
        return Colors.orangeAccent;
      case ZoneKind.spell:
        return Colors.tealAccent;
      case ZoneKind.deck:
      case ZoneKind.extra:
        return Colors.indigoAccent;
      case ZoneKind.grave:
        return Colors.deepPurpleAccent;
      case ZoneKind.banished:
        return Colors.blueGrey;
      case ZoneKind.fieldSpell:
        return Colors.pinkAccent;
    }
  }

  String? get _label {
    switch (zone.kind) {
      case ZoneKind.deck:
        return '卡组';
      case ZoneKind.extra:
        return '额外';
      case ZoneKind.grave:
        return '墓地';
      case ZoneKind.banished:
        return '除外';
      case ZoneKind.fieldSpell:
        return '场地';
      case ZoneKind.monster:
      case ZoneKind.spell:
        return null;
    }
  }

  int get _pileCount {
    final field = zone.isOpponent ? state.opponentField : state.playerField;
    switch (zone.kind) {
      case ZoneKind.deck:
        return field.deckCount;
      case ZoneKind.extra:
        return field.extraCount;
      case ZoneKind.grave:
        return field.graveCount;
      case ZoneKind.banished:
        return field.banishedCount;
      case ZoneKind.fieldSpell:
      case ZoneKind.monster:
      case ZoneKind.spell:
        return 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final hw = zone.width / 2;
    final hd = zone.depth / 2;
    final c = zone.center;
    final corners = [
      camera.project(Vec3(c.x - hw, 0.01, c.z - hd)),
      camera.project(Vec3(c.x + hw, 0.01, c.z - hd)),
      camera.project(Vec3(c.x + hw, 0.01, c.z + hd)),
      camera.project(Vec3(c.x - hw, 0.01, c.z + hd)),
    ];
    if (corners.any((p) => p == null)) return;

    final path = Path()
      ..moveTo(corners[0]!.dx, corners[0]!.dy)
      ..lineTo(corners[1]!.dx, corners[1]!.dy)
      ..lineTo(corners[2]!.dx, corners[2]!.dy)
      ..lineTo(corners[3]!.dx, corners[3]!.dy)
      ..close();

    final color = _color;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = color.withValues(alpha: 0.12),
    );
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.02));

    final label = _label;
    if (label != null) {
      _drawLabel(canvas, corners, label);
    }
  }

  void _drawLabel(Canvas canvas, List<Offset?> corners, String text) {
    final cx = (corners[0]!.dx + corners[2]!.dx) / 2;
    final topY = (corners[0]!.dy + corners[1]!.dy) / 2;
    final botY = (corners[2]!.dy + corners[3]!.dy) / 2;
    final h = (botY - topY).abs();
    if (h < 14) return;

    final fontSize = (h * 0.16).clamp(5.0, 11.0);
    var label = text;
    final count = _pileCount;
    if (zone.kind != ZoneKind.fieldSpell && count > 0) {
      label = '$text $count';
    }
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: _color.withValues(alpha: 0.55),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, topY + h * 0.06));
  }
}
