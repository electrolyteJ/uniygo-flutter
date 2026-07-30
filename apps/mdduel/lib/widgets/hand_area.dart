import 'package:flutter/material.dart';
import '../models/duel_card.dart';
import '../models/duel_state.dart';
import '../theme/md_theme.dart';

class HandArea extends StatelessWidget {
  final DuelState state;

  const HandArea({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cards = state.side(state.turn).hand;
    final interactive = state.isHuman(state.turn) && !state.busy && !state.over;
    if (cards.isEmpty) return const SizedBox(height: 50);
    final n = cards.length;
    const cardW = 72.0;
    const step = 40.0;
    final totalW = (n - 1) * step + cardW;
    return SizedBox(
      width: totalW + 40,
      height: 140,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: List.generate(n, (i) {
          final off = i - (n - 1) / 2;
          final angle = off * 0.08;
          final dy = off.abs() * off.abs() * 1.2 + off.abs() * 2;
          return Positioned(
            left: 20 + i * step,
            bottom: 8 - dy,
            child: _HandCard(
              card: cards[i],
              width: cardW,
              angle: angle,
              dimmed: !interactive,
              onTap: interactive ? () => state.playCard(i) : null,
            ),
          );
        }),
      ),
    );
  }
}

class _HandCard extends StatefulWidget {
  final DuelCard card;
  final double width;
  final double angle;
  final bool dimmed;
  final VoidCallback? onTap;

  const _HandCard({required this.card, required this.width, required this.angle, this.dimmed = false, this.onTap});

  @override
  State<_HandCard> createState() => _HandCardState();
}

class _HandCardState extends State<_HandCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final lift = _hover && !widget.dimmed;
    final h = widget.width * 1.457;
    return Transform.rotate(
      angle: widget.angle * (lift ? 0.2 : 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0.0, lift ? -28.0 : 0.0, 0.0)
          ..multiply(Matrix4.diagonal3Values(lift ? 1.18 : 1.0, lift ? 1.18 : 1.0, 1.0)),
        transformAlignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: widget.dimmed ? .5 : 1,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: widget.width,
                height: h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.width * 0.06),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [widget.card.typeColor, widget.card.typeColor.withValues(alpha: .5), MdTheme.panel],
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                padding: EdgeInsets.all(widget.width * 0.04),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.width * 0.04),
                    color: MdTheme.bgDeep,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: widget.width * 0.04, vertical: widget.width * 0.02),
                        child: Text(widget.card.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: MdTheme.body(widget.width * 0.09, color: Colors.white, w: FontWeight.w700)),
                      ),
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: widget.width * 0.04),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(widget.width * 0.03),
                            gradient: RadialGradient(center: const Alignment(0, -0.2), colors: [widget.card.artColor, widget.card.artColor2]),
                          ),
                          child: Center(
                            child: Text(widget.card.glyph,
                                style: TextStyle(fontSize: widget.width * 0.28, color: Colors.white.withValues(alpha: .9),
                                    shadows: [Shadow(color: widget.card.artColor.withValues(alpha: .8), blurRadius: 10)])),
                          ),
                        ),
                      ),
                      if (widget.card.isMonster) ...[
                        SizedBox(height: widget.width * 0.02),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: widget.width * 0.05),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('ATK/${widget.card.atk}', style: MdTheme.num(widget.width * 0.07, color: MdTheme.goldHi)),
                              Text('DEF/${widget.card.def}', style: MdTheme.num(widget.width * 0.07, color: MdTheme.textDim)),
                            ],
                          ),
                        ),
                        SizedBox(height: widget.width * 0.03),
                      ] else
                        SizedBox(height: widget.width * 0.05),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
