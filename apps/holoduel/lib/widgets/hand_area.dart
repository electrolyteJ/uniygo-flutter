import 'package:flutter/material.dart';
import '../models/duel_card.dart';
import '../models/duel_state.dart';
import 'card_face.dart';

class HandArea extends StatelessWidget {
  final DuelState state;

  const HandArea({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cards = state.side(state.turn).hand;
    final interactive = state.isHuman(state.turn) && !state.busy && !state.over;
    if (cards.isEmpty) return const SizedBox(height: 60);
    final n = cards.length;
    const cardW = 84.0;
    const step = 46.0;
    final totalW = (n - 1) * step + cardW;
    return SizedBox(
      width: totalW + 60,
      height: 168,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: List.generate(n, (i) {
          final off = i - (n - 1) / 2;
          final angle = off * 0.10;
          final dy = off.abs() * off.abs() * 1.5 + off.abs() * 3;
          return Positioned(
            left: 30 + i * step,
            bottom: 12 - dy,
            child: interactive
                ? Draggable<int>(
                    data: i,
                    affinity: Axis.vertical,
                    feedback: CardFace(card: cards[i], width: 90),
                    childWhenDragging: Opacity(
                      opacity: .2,
                      child: CardFace(card: cards[i], width: cardW),
                    ),
                    child: _HandCard(
                      card: cards[i],
                      width: cardW,
                      angle: angle,
                      onTap: () => state.playCard(i),
                      onLongPress: () => state.setPreview(cards[i]),
                      onHover: (h) => state.setPreview(h ? cards[i] : null),
                    ),
                  )
                : _HandCard(
                    card: cards[i],
                    width: cardW,
                    angle: angle,
                    dimmed: true,
                    onTap: null,
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
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHover;

  const _HandCard({
    required this.card,
    required this.width,
    required this.angle,
    this.dimmed = false,
    this.onTap,
    this.onLongPress,
    this.onHover,
  });

  @override
  State<_HandCard> createState() => _HandCardState();
}

class _HandCardState extends State<_HandCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final lift = _hover && !widget.dimmed;
    return Transform.rotate(
      angle: widget.angle * (lift ? 0.2 : 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0.0, lift ? -34.0 : 0.0, 0.0)
          ..multiply(Matrix4.diagonal3Values(
              lift ? 1.22 : 1.0, lift ? 1.22 : 1.0, 1.0)),
        transformAlignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: widget.dimmed ? .5 : 1,
          child: CardFace(
            card: widget.card,
            width: widget.width,
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onHover: (h) {
              setState(() => _hover = h);
              widget.onHover?.call(h);
            },
          ),
        ),
      ),
    );
  }
}
