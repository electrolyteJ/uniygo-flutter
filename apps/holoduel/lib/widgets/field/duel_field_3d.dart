import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/duel_card.dart';
import '../../models/duel_state.dart';
import '../../theme/duel_theme.dart';
import '../card_slot.dart';

class DuelField3d extends StatefulWidget {
  final DuelState state;

  const DuelField3d({super.key, required this.state});

  @override
  State<DuelField3d> createState() => _DuelField3dState();
}

class _DuelField3dState extends State<DuelField3d> with TickerProviderStateMixin {
  static const double zw = 62;
  static const double gap = 8;
  static const double planeW = 526;
  static const double planeH = 470;

  final Map<String, GlobalKey> _zoneKeys = {};
  final GlobalKey _planeKey = GlobalKey();
  final ValueNotifier<Offset> _parallax = ValueNotifier(Offset.zero);
  late final AnimationController _ring1;
  late final AnimationController _ring2;
  late final AnimationController _ring3;

  DuelState get state => widget.state;

  @override
  void initState() {
    super.initState();
    for (final s in ['own', 'foe']) {
      for (final k in ['mon', 'st']) {
        for (var i = 0; i < 5; i++) {
          _zoneKeys['${s}_${k}_$i'] = GlobalKey();
        }
      }
    }
    _ring1 = AnimationController(vsync: this, duration: const Duration(seconds: 70))..repeat();
    _ring2 = AnimationController(vsync: this, duration: const Duration(seconds: 120))..reverse(from: 1);
    _ring3 = AnimationController(vsync: this, duration: const Duration(seconds: 42))..repeat();
  }

  @override
  void dispose() {
    _parallax.dispose();
    _ring1.dispose();
    _ring2.dispose();
    _ring3.dispose();
    super.dispose();
  }

  void _registerAnchors() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final e in _zoneKeys.entries) {
        final ctx = e.value.currentContext;
        if (ctx == null) continue;
        final box = ctx.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          state.fx.registerAnchor(e.key, box.localToGlobal(box.size.center(Offset.zero)));
        }
      }
      final pctx = _planeKey.currentContext;
      if (pctx != null) {
        final box = pctx.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          state.fx.registerAnchor('field_center', box.localToGlobal(box.size.center(Offset.zero)));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _registerAnchors();
    return LayoutBuilder(builder: (context, c) {
      final scale = (math.min(c.maxWidth / (planeW + 40), c.maxHeight / (planeH + 60)))
          .clamp(0.5, 1.25);
      return MouseRegion(
        onHover: (e) {
          final rx = (e.localPosition.dx / c.maxWidth - .5) * 0.12;
          final ry = (e.localPosition.dy / c.maxHeight - .5) * -0.08;
          _parallax.value = Offset(rx, ry);
        },
        child: ValueListenableBuilder<Offset>(
          valueListenable: _parallax,
          builder: (context, p, _) => Transform.scale(
            scale: scale,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: -40,
                  height: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [
                        DuelTheme.cyan.withValues(alpha: .18),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateX(0.66 + p.dy)
                    ..rotateY(p.dx),
                  child: SizedBox(
                    key: _planeKey,
                    width: planeW,
                    height: planeH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: CustomPaint(painter: _FieldPainter())),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 22,
                          child: Transform(
                            alignment: Alignment.topCenter,
                            transform: Matrix4.identity()..rotateX(-1.5708),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    DuelTheme.cyan.withValues(alpha: .28),
                                    DuelTheme.void_.withValues(alpha: .95),
                                  ],
                                ),
                                border: Border(
                                  top: BorderSide(color: DuelTheme.cyan.withValues(alpha: .55)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _ring(480, _ring2, DuelTheme.cyan.withValues(alpha: .12), 1),
                        _ring(330, _ring1, DuelTheme.gold.withValues(alpha: .28), 1.2, dashed: true),
                        _ring(190, _ring3, DuelTheme.gold.withValues(alpha: .16), 2),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _half(Side.foe),
                              _midline(),
                              _half(Side.own),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _ring(double size, Animation<double> anim, Color color, double w, {bool dashed = false}) {
    return Positioned.fill(
      child: Center(
        child: RotationTransition(
          turns: anim,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _RingPainter(color, w, dashed)),
          ),
        ),
      ),
    );
  }

  Widget _midline() {
    return GestureDetector(
      onTap: () => state.directAttack(),
      child: SizedBox(
        width: planeW - 40,
        height: 42,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    DuelTheme.cyan.withValues(alpha: .65),
                    DuelTheme.gold.withValues(alpha: .8),
                    DuelTheme.cyan.withValues(alpha: .65),
                    Colors.transparent,
                  ]),
                  boxShadow: [BoxShadow(color: DuelTheme.cyan.withValues(alpha: .4), blurRadius: 10)],
                ),
              ),
            ),
            Positioned(
              left: 0,
              child: Transform(
                transform: Matrix4.translationValues(0, 0, 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xD90A0D24),
                    border: Border.all(color: DuelTheme.gold.withValues(alpha: .5)),
                  ),
                  child: Text('TURN ${state.turnN}',
                      style: DuelTheme.tech(10, color: DuelTheme.goldHi, ls: 2)),
                ),
              ),
            ),
            Transform(
              transform: Matrix4.translationValues(0, 0, 34),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                      center: Alignment(0, -0.24), colors: [Color(0xFF1C2356), Color(0xFF0A0D24)]),
                  border: Border.all(color: DuelTheme.gold.withValues(alpha: .65)),
                  boxShadow: [
                    BoxShadow(color: DuelTheme.gold.withValues(alpha: .3), blurRadius: 22),
                  ],
                ),
                child: Center(
                  child: Text('☥',
                      style: TextStyle(
                          fontSize: 21,
                          color: DuelTheme.goldHi,
                          shadows: [Shadow(color: DuelTheme.gold.withValues(alpha: .9), blurRadius: 10)])),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _half(Side side) {
    final isFoe = side == Side.foe;
    final st = state.side(side);
    final monRow = _row(side, 'mon', st.mon);
    final stRow = _row(side, 'st', st.st);
    return SizedBox(
      width: planeW,
      height: 196,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(mainAxisSize: MainAxisSize.min, children: isFoe ? [stRow, stGap, monRow] : [monRow, stGap, stRow]),
          Positioned(
            left: 18,
            child: Column(mainAxisSize: MainAxisSize.min, children: isFoe
                ? [_pile('卡组', st.deck.length, deck: true), pileGap, _pile('墓地', st.grave.length, grave: true)]
                : [_pile('场地', null, field: true), pileGap, _pile('额外', 3)]),
          ),
          Positioned(
            right: 18,
            child: Column(mainAxisSize: MainAxisSize.min, children: isFoe
                ? [_pile('场地', null, field: true), pileGap, _pile('额外', 3)]
                : [_pile('卡组', st.deck.length, deck: true), pileGap, _pile('墓地', st.grave.length, grave: true)]),
          ),
        ],
      ),
    );
  }

  Widget get stGap => const SizedBox(height: gap);
  Widget get pileGap => const SizedBox(height: 10);

  Widget _row(Side side, String kind, List<DuelCard?> zones) {
    final isFoe = side == Side.foe;
    final isMon = kind == 'mon';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final card = zones[i];
        final key = _zoneKeys['${side.name}_${kind}_$i']!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: gap / 2),
          child: KeyedSubtree(
            key: key,
            child: CardSlot(
              card: card,
              width: zw,
              label: isMon ? 'M$i' : 'S$i',
              tone: isFoe
                  ? (isMon ? SlotTone.foeMon : SlotTone.foeSt)
                  : (isMon ? SlotTone.ownMon : SlotTone.ownSt),
              target: isFoe && isMon && card != null && state.selectedZone != null,
              selected: !isFoe && isMon && state.selectedZone == i && card != null,
              onTap: () {
                if (!isFoe && isMon) {
                  state.selectMonster(i);
                } else if (isFoe && isMon && card != null) {
                  state.attackTarget(i);
                } else if (isFoe && isMon) {
                  state.directAttack();
                }
              },
              onDoubleTap: (!isFoe && isMon) ? () => state.togglePosition(i) : null,
              onCardHover: (hover) => state.setPreview(hover ? card : null),
              onCardLongPress: () => state.setPreview(card),
              onWillAccept: (handIdx) {
                if (side != state.turn || !state.isHuman(state.turn)) return false;
                if (state.phase != DuelPhase.main1 && state.phase != DuelPhase.main2) return false;
                if (state.busy || state.over) return false;
                final hand = state.side(state.turn).hand;
                if (handIdx < 0 || handIdx >= hand.length) return false;
                final c = hand[handIdx];
                if (isMon) {
                  return c.isMonster && !state.side(side).summoned && card == null;
                }
                return !c.isMonster && card == null;
              },
              onAccept: (handIdx) {
                state.playCard(handIdx, monZone: isMon ? i : null, stZone: isMon ? null : i);
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _pile(String label, int? count, {bool deck = false, bool grave = false, bool field = false}) {
    return SizedBox(
      width: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: DuelTheme.body(9, color: DuelTheme.textDim, ls: 2)),
          const SizedBox(height: 3),
          Container(
            height: field ? 40 : 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: const Color(0xB3080B1E),
              border: field
                  ? Border.all(color: DuelTheme.gold.withValues(alpha: .35), style: BorderStyle.solid)
                  : Border.all(color: DuelTheme.cyan.withValues(alpha: .28)),
              boxShadow: [BoxShadow(color: DuelTheme.cyan.withValues(alpha: .08), blurRadius: 10)],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (field)
                  Text('◉', style: TextStyle(fontSize: 17, color: DuelTheme.gold.withValues(alpha: .55)))
                else
                  Positioned.fill(
                    left: 6,
                    top: 6,
                    right: 6,
                    bottom: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const RadialGradient(colors: [Color(0xFF3A2154), Color(0xFF180C28)]),
                        border: Border.all(color: DuelTheme.gold.withValues(alpha: .4)),
                        boxShadow: [if (grave) BoxShadow(color: Colors.black.withValues(alpha: .6), blurRadius: 4)],
                      ),
                      child: Center(
                        child: Text('☥',
                            style: TextStyle(
                                fontSize: 18,
                                color: DuelTheme.gold.withValues(alpha: grave ? .4 : .8))),
                      ),
                    ),
                  ),
                if (count != null)
                  Positioned(
                    right: -4,
                    bottom: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0D24),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: DuelTheme.gold.withValues(alpha: .6)),
                      ),
                      child: Text('$count', style: DuelTheme.tech(10, color: DuelTheme.goldHi)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Paint();

    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0B0F26), Color(0xFF070919), Color(0xFF0A0D20)],
    ).createShader(rect);
    canvas.drawRect(rect, p);

    p.shader = RadialGradient(
      colors: [DuelTheme.cyan.withValues(alpha: .09), Colors.transparent],
    ).createShader(Rect.fromCircle(center: rect.center, radius: size.width * .31));
    canvas.drawRect(rect, p);

    p.shader = null;
    p.strokeWidth = 1;
    p.color = DuelTheme.cyan.withValues(alpha: .05);
    for (var x = 0.0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }

    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: const Alignment(0, -0.1),
      colors: [Colors.black.withValues(alpha: .52), Colors.transparent],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.55));
    canvas.drawRect(rect, p);

    p.shader = null;
    p.color = DuelTheme.cyan.withValues(alpha: .4);
    canvas.drawRect(Rect.fromLTWH(0, size.height - 2, size.width, 2), p);

    p.color = DuelTheme.cyan.withValues(alpha: .22);
    canvas.drawRect(rect.deflate(0.5), p);
    p.color = DuelTheme.gold.withValues(alpha: .28);
    canvas.drawRect(rect.deflate(9), p);

    p.color = DuelTheme.gold.withValues(alpha: .5);
    p.strokeWidth = 2;
    const b = 22.0;
    const m = 4.0;
    canvas.drawLine(const Offset(m, m + b), const Offset(m, m), p);
    canvas.drawLine(const Offset(m, m), const Offset(m + b, m), p);
    canvas.drawLine(Offset(size.width - m - b, m), Offset(size.width - m, m), p);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m, m + b), p);
    canvas.drawLine(Offset(m, size.height - m - b), Offset(m, size.height - m), p);
    canvas.drawLine(Offset(m, size.height - m), Offset(m + b, size.height - m), p);
    canvas.drawLine(Offset(size.width - m - b, size.height - m), Offset(size.width - m, size.height - m), p);
    canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m, size.height - m - b), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double width;
  final bool dashed;

  _RingPainter(this.color, this.width, this.dashed);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    if (!dashed) {
      canvas.drawCircle(c, r, p);
      return;
    }
    final path = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final metrics = path.computeMetrics().first;
    const dash = 10.0;
    const gap = 8.0;
    var dist = 0.0;
    final total = metrics.length;
    final dashedPath = Path();
    while (dist < total) {
      final end = math.min(dist + dash, total);
      dashedPath.addPath(metrics.extractPath(dist, end), Offset.zero);
      dist = end + gap;
    }
    canvas.drawPath(dashedPath, p);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color || old.dashed != dashed;
}
