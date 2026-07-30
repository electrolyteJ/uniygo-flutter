import 'package:flutter/material.dart';
import '../models/duel_card.dart';
import '../theme/duel_theme.dart';
import 'card_face.dart';

enum SlotTone { ownMon, ownSt, foeMon, foeSt }

class CardSlot extends StatelessWidget {
  final DuelCard? card;
  final double width;
  final String label;
  final SlotTone tone;
  final bool droppable;
  final bool target;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final ValueChanged<bool>? onCardHover;
  final VoidCallback? onCardLongPress;
  final DragTargetValidator? onWillAccept;
  final ValueChanged<int>? onAccept;

  const CardSlot({
    super.key,
    this.card,
    this.width = 62,
    this.label = '',
    this.tone = SlotTone.ownMon,
    this.droppable = false,
    this.target = false,
    this.selected = false,
    this.onTap,
    this.onDoubleTap,
    this.onCardHover,
    this.onCardLongPress,
    this.onWillAccept,
    this.onAccept,
  });

  Color get _base {
    switch (tone) {
      case SlotTone.ownMon:
        return DuelTheme.gold.withValues(alpha: .34);
      case SlotTone.ownSt:
        return DuelTheme.cyan.withValues(alpha: .3);
      case SlotTone.foeMon:
        return DuelTheme.crimson.withValues(alpha: .4);
      case SlotTone.foeSt:
        return DuelTheme.crimson.withValues(alpha: .3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = width * DuelTheme.cardRatio;
    Widget inner(bool drop) => _SlotBox(
          width: width,
          height: height,
          baseColor: _base,
          droppable: droppable || drop,
          target: target,
          label: label,
          card: card,
          selected: selected,
          onCardHover: onCardHover,
          onCardLongPress: onCardLongPress,
        );
    Widget slot;
    if (onAccept != null) {
      slot = DragTarget<int>(
        onWillAcceptWithDetails: (d) => onWillAccept?.call(d.data) ?? false,
        onAcceptWithDetails: (d) => onAccept?.call(d.data),
        builder: (context, candidate, _) => inner(candidate.isNotEmpty),
      );
    } else {
      slot = inner(false);
    }
    return GestureDetector(onTap: onTap, onDoubleTap: onDoubleTap, child: slot);
  }
}

typedef DragTargetValidator = bool Function(int data);

class _SlotBox extends StatefulWidget {
  final double width;
  final double height;
  final Color baseColor;
  final bool droppable;
  final bool target;
  final String label;
  final DuelCard? card;
  final bool selected;
  final ValueChanged<bool>? onCardHover;
  final VoidCallback? onCardLongPress;

  const _SlotBox({
    required this.width,
    required this.height,
    required this.baseColor,
    required this.droppable,
    required this.target,
    required this.label,
    required this.card,
    required this.selected,
    this.onCardHover,
    this.onCardLongPress,
  });

  @override
  State<_SlotBox> createState() => _SlotBoxState();
}

class _SlotBoxState extends State<_SlotBox> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulsing = widget.droppable || widget.target;
    final pulseColor = widget.droppable ? DuelTheme.goldHi : DuelTheme.crimson;

    Widget box = AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final k = pulsing ? _pulse.value : 0.0;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: pulsing
                  ? Color.lerp(widget.baseColor, pulseColor, 0.5 + k * 0.5)!
                  : widget.baseColor,
              width: pulsing ? 2 : 1,
            ),
            color: Colors.white.withValues(alpha: 0.03),
            boxShadow: [
              if (pulsing)
                BoxShadow(color: pulseColor.withValues(alpha: .3 + k * .5), blurRadius: 14 + k * 14),
              BoxShadow(color: widget.baseColor.withValues(alpha: .12), blurRadius: 8, spreadRadius: -4),
            ],
          ),
          child: child,
        );
      },
      child: widget.card != null
          ? _buildCard()
          : Center(
              child: Text(
                widget.label,
                style: TextStyle(color: Colors.white.withValues(alpha: .16), fontSize: 9, letterSpacing: 1),
              ),
            ),
    );
    return box;
  }

  Widget _buildCard() {
    final card = widget.card!;
    final isMon = card.isMonster;
    Widget face = CardFace(
      card: card,
      width: widget.width,
      faceDown: card.faceDown,
      selected: widget.selected,
      onHover: widget.onCardHover,
      onLongPress: widget.onCardLongPress,
    );
    if (isMon && card.position == BattlePosition.defense) {
      face = Transform.rotate(angle: 1.5708, child: Transform.scale(scale: .92, child: face));
    }
    if (isMon) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: widget.width * 0.06,
            right: widget.width * 0.06,
            bottom: -widget.width * 0.08,
            height: widget.width * 0.22,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Colors.black.withValues(alpha: .6), Colors.transparent],
                ),
              ),
            ),
          ),
          Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()..rotateX(-1.12),
            child: face,
          ),
        ],
      );
    }
    return face;
  }
}
