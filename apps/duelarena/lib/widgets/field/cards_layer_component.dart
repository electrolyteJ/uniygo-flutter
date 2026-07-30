import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:duelarena/widgets/field/projection.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../models/duel_card.dart';
import '../../../models/duel_state.dart';
import 'field_layout.dart';

/// Collects every card on the field (main zones, field spell zone and
/// pile tops), depth-sorts them and paints them with the [camera].
/// Also keeps hit paths so taps can be resolved to cards.
class CardsLayerComponent extends Component {
  final FieldCamera camera;
  final List<ZonePosition> zones;
  final DuelState state;

  final List<_CardRenderable> _renderables = [];
  final Map<int, Path> _hitPaths = {};

  CardsLayerComponent({
    required this.camera,
    required this.zones,
    required this.state,
  });

  double _time = 0;

  @override
  void update(double dt) {
    _time += dt;
  }

  /// Resolves a screen-space tap to the topmost selectable card, if any,
  /// together with the index of the zone it sits in.
  (DuelCard, int)? hitTest(Offset pos) {
    for (final r in _renderables.reversed) {
      final path = _hitPaths[r.id];
      if (path != null && path.contains(pos)) {
        return r.selectable ? (r.card, r.zone.index) : null;
      }
    }
    return null;
  }

  ZonePosition _zone(ZoneKind kind, bool isOpponent, {int index = 0}) =>
      FieldLayout.zone(zones, kind, isOpponent: isOpponent, index: index);

  @override
  void render(Canvas canvas) {
    final s = camera.viewportSize;
    if (s.isEmpty) return;

    _renderables.clear();
    _hitPaths.clear();

    final cards = <_CardRenderable>[];

    for (int i = 0; i < 5; i++) {
      final pm = state.playerField.monsterZones[i];
      if (pm != null) {
        cards.add(_CardRenderable(
          card: pm,
          zone: _zone(ZoneKind.monster, false, index: i),
          standing: pm.isAttack,
          selectable: true,
          id: i,
        ));
      }
      final ps = state.playerField.spellZones[i];
      if (ps != null) {
        cards.add(_CardRenderable(
          card: ps,
          zone: _zone(ZoneKind.spell, false, index: i),
          standing: false,
          selectable: true,
          id: 10 + i,
        ));
      }
      final om = state.opponentField.monsterZones[i];
      if (om != null) {
        cards.add(_CardRenderable(
          card: om,
          zone: _zone(ZoneKind.monster, true, index: i),
          standing: om.isAttack,
          selectable: true,
          id: 20 + i,
        ));
      }
      final os = state.opponentField.spellZones[i];
      if (os != null) {
        cards.add(_CardRenderable(
          card: os,
          zone: _zone(ZoneKind.spell, true, index: i),
          standing: false,
          selectable: true,
          id: 30 + i,
        ));
      }
    }

    // Field spell cards lie flat in the field zone.
    for (final isOpponent in [false, true]) {
      final field = isOpponent ? state.opponentField : state.playerField;
      final fc = field.fieldZone;
      if (fc != null) {
        cards.add(_CardRenderable(
          card: fc,
          zone: _zone(ZoneKind.fieldSpell, isOpponent),
          standing: false,
          selectable: true,
          id: isOpponent ? 41 : 40,
        ));
      }
    }

    // Pile tops: draw a face-down slab on top of the stack, raised by the
    // stack height like Unity's `y += sequence * 0.03`.
    for (final isOpponent in [false, true]) {
      final field = isOpponent ? state.opponentField : state.playerField;
      final piles = <(ZoneKind, int, int)>[
        (ZoneKind.deck, field.deckCount, isOpponent ? 51 : 50),
        (ZoneKind.extra, field.extraCount, isOpponent ? 53 : 52),
        (ZoneKind.grave, field.graveCount, isOpponent ? 55 : 54),
      ];
      for (final (kind, count, id) in piles) {
        if (count <= 0) continue;
        cards.add(_CardRenderable(
          card: DuelCard.preview(),
          zone: _zone(kind, isOpponent),
          standing: false,
          selectable: false,
          pileCount: count,
          id: id,
        ));
      }
    }

    for (final r in cards) {
      r.depth = camera.depthOf(r.zone.center);
      r.quad = _projectCardQuad(r);
    }
    cards.sort((a, b) => b.depth.compareTo(a.depth));
    _renderables.addAll(cards);

    for (final r in cards) {
      if (r.quad == null) continue;
      _drawCard(canvas, r);
    }
  }

  List<Offset>? _projectCardQuad(_CardRenderable r) {
    final c = r.zone.center;
    final hw = FieldLayout.cardW / 2;
    final yOffset = r.pileCount != null
        ? math.min(r.pileCount!, 20) * FieldLayout.stackStep
        : 0.0;

    List<Vec3> corners;
    if (r.standing) {
      corners = [
        Vec3(c.x - hw, yOffset, c.z),
        Vec3(c.x + hw, yOffset, c.z),
        Vec3(c.x + hw, FieldLayout.cardH + yOffset, c.z),
        Vec3(c.x - hw, FieldLayout.cardH + yOffset, c.z),
      ];
    } else {
      final hd = FieldLayout.cardH / 2;
      final y = 0.02 + yOffset;
      corners = [
        Vec3(c.x - hw, y, c.z - hd),
        Vec3(c.x + hw, y, c.z - hd),
        Vec3(c.x + hw, y, c.z + hd),
        Vec3(c.x - hw, y, c.z + hd),
      ];
    }

    final projected = <Offset>[];
    for (final corner in corners) {
      final p = camera.project(corner);
      if (p == null) return null;
      projected.add(p);
    }
    return projected;
  }

  void _drawCard(Canvas canvas, _CardRenderable r) {
    final quad = r.quad!;
    final path = Path()
      ..moveTo(quad[0].dx, quad[0].dy)
      ..lineTo(quad[1].dx, quad[1].dy)
      ..lineTo(quad[2].dx, quad[2].dy)
      ..lineTo(quad[3].dx, quad[3].dy)
      ..close();
    _hitPaths[r.id] = path;

    final selected = r.selectable && state.selectedCard == r.card;
    final faceUp = r.selectable && r.card.isFaceUp;

    if (r.standing) _drawCardShadow(canvas, r);

    if (faceUp) {
      final baseColor = r.card.typeColor;
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(quad[0], quad[2], [
            baseColor.withValues(alpha: 0.35),
            const Color(0xFF1A1A1A).withValues(alpha: 0.95),
            const Color(0xFF111111).withValues(alpha: 0.98),
          ], [0.0, 0.5, 1.0]),
      );
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(quad[0], quad[2], [
            const Color(0xFF5D3A1A),
            const Color(0xFF3A2010),
            const Color(0xFF1A0E05),
          ], [0.0, 0.5, 1.0]),
      );
    }

    final borderColor = selected
        ? Colors.yellowAccent
        : faceUp
            ? r.card.typeColor.withValues(alpha: 0.7)
            : const Color(0xFFD4A060).withValues(alpha: 0.5);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2 : 1
        ..color = borderColor,
    );

    if (selected) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.yellowAccent
              .withValues(alpha: 0.3 + 0.15 * math.sin(_time * 4))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    if (!r.selectable) {
      if (r.pileCount != null) _drawPileCount(canvas, r, quad);
      return;
    }

    if (faceUp) {
      _drawCardText(canvas, r, quad);
    } else {
      _drawCardBack(canvas, quad);
    }
  }

  void _drawPileCount(Canvas canvas, _CardRenderable r, List<Offset> quad) {
    final cx = (quad[0].dx + quad[1].dx + quad[2].dx + quad[3].dx) / 4;
    final cy = (quad[0].dy + quad[1].dy + quad[2].dy + quad[3].dy) / 4;
    final cardH =
        ((quad[2].dy + quad[3].dy) / 2 - (quad[0].dy + quad[1].dy) / 2)
            .abs();
    final fontSize = (cardH * 0.28).clamp(6.0, 16.0);
    final tp = TextPainter(
      text: TextSpan(
        text: '${r.pileCount}',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.9), blurRadius: 3),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _drawCardShadow(Canvas canvas, _CardRenderable r) {
    final c = r.zone.center;
    final hw = FieldLayout.cardW * 0.4;
    const hd = 0.15;
    final corners = [
      camera.project(Vec3(c.x - hw, 0.005, c.z - hd)),
      camera.project(Vec3(c.x + hw, 0.005, c.z - hd)),
      camera.project(Vec3(c.x + hw, 0.005, c.z + hd)),
      camera.project(Vec3(c.x - hw, 0.005, c.z + hd)),
    ];
    if (corners.any((p) => p == null)) return;

    final path = Path()
      ..moveTo(corners[0]!.dx, corners[0]!.dy)
      ..lineTo(corners[1]!.dx, corners[1]!.dy)
      ..lineTo(corners[2]!.dx, corners[2]!.dy)
      ..lineTo(corners[3]!.dx, corners[3]!.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _drawCardText(Canvas canvas, _CardRenderable r, List<Offset> quad) {
    final cx = (quad[0].dx + quad[1].dx + quad[2].dx + quad[3].dx) / 4;
    final topY = (quad[0].dy + quad[1].dy) / 2;
    final botY = (quad[2].dy + quad[3].dy) / 2;
    final cardH = (botY - topY).abs();
    final cardW = (quad[1].dx - quad[0].dx).abs();
    if (cardH < 10 || cardW < 8) return;

    final nameFontSize = (cardH * 0.09).clamp(5.0, 14.0);
    final nameTp = TextPainter(
      text: TextSpan(
        text: r.card.name,
        style: TextStyle(
          color: Colors.white,
          fontSize: nameFontSize,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: cardW * 0.9);
    nameTp.paint(canvas, Offset(cx - nameTp.width / 2, topY + cardH * 0.02));

    if (r.card.type == CardType.monster && cardH > 25) {
      final statFontSize = (cardH * 0.07).clamp(4.0, 11.0);
      final statY = botY - statFontSize * 1.5;

      final atkTp = TextPainter(
        text: TextSpan(
          text: 'ATK/${r.card.attack}',
          style: TextStyle(
            color: Colors.red.shade300,
            fontSize: statFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final defTp = TextPainter(
        text: TextSpan(
          text: 'DEF/${r.card.defense}',
          style: TextStyle(
            color: Colors.blue.shade300,
            fontSize: statFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      atkTp.paint(canvas, Offset(cx - cardW * 0.4, statY));
      defTp.paint(canvas, Offset(cx + cardW * 0.05, statY));
    }

    if (r.card.type == CardType.monster && cardH > 30) {
      final starSize = (cardH * 0.05).clamp(3.0, 8.0);
      final starTp = TextPainter(
        text: TextSpan(
          text: '★' * math.min(r.card.level, 8),
          style: TextStyle(color: Colors.yellow.shade300, fontSize: starSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      starTp.paint(canvas, Offset(cx - starTp.width / 2, topY + cardH * 0.15));
    }
  }

  void _drawCardBack(Canvas canvas, List<Offset> quad) {
    final cx = (quad[0].dx + quad[1].dx + quad[2].dx + quad[3].dx) / 4;
    final cy = (quad[0].dy + quad[1].dy + quad[2].dy + quad[3].dy) / 4;
    final cardW = (quad[1].dx - quad[0].dx).abs();
    final cardH =
        ((quad[2].dy + quad[3].dy) / 2 - (quad[0].dy + quad[1].dy) / 2)
            .abs();
    final r = math.min(cardW, cardH) * 0.2;
    if (r < 2) return;

    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFD4A060).withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.5,
      Paint()..color = const Color(0xFFD4A060).withValues(alpha: 0.15),
    );
  }
}

class _CardRenderable {
  final DuelCard card;
  final ZonePosition zone;
  final bool standing;
  final bool selectable;
  final int? pileCount;
  final int id;
  double depth = 0;
  List<Offset>? quad;

  _CardRenderable({
    required this.card,
    required this.zone,
    required this.standing,
    required this.selectable,
    required this.id,
    this.pileCount,
  });
}
