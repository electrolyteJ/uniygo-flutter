import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../models/duel_card.dart';
import '../preview_helpers.dart';
import 'card_face.dart';

class HandArea extends StatelessWidget {
  final List<DuelCard> cards;
  final bool faceDown;
  final ValueChanged<int>? onCardTap;
  final int? selectedIndex;

  const HandArea({
    super.key,
    required this.cards,
    this.faceDown = false,
    this.onCardTap,
    this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    final count = cards.length;
    const cardW = 58.0;
    const cardH = 82.0;
    final spread = math.min(count * 42.0, 320.0);
    final step = count > 1 ? spread / (count - 1) : 0.0;
    final totalW = count > 1 ? spread + cardW : cardW;

    return SizedBox(
      width: totalW,
      height: cardH + 24,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: List.generate(count, (i) {
          final t = count > 1 ? i / (count - 1) - 0.5 : 0.0;
          final angle = t * 0.12;
          final offsetY = t.abs() * 10;

          return Positioned(
            left: i * step,
            bottom: offsetY,
            child: Transform.rotate(
              angle: angle,
              child: CardFace(
                card: cards[i],
                width: cardW,
                height: cardH,
                faceDown: faceDown,
                selected: selectedIndex == i,
                onTap: () => onCardTap?.call(i),
              ),
            ),
          );
        }),
      ),
    );
  }
}

@Preview(name: '手牌区', group: 'HandArea', wrapper: darkPreviewWrapper)
Widget previewHandArea() => HandArea(cards: [
      DuelCard(
          code: 89631139,
          name: '青眼白龙',
          attack: 3000,
          defense: 2500,
          level: 8,
          attribute: 0x10),
      DuelCard(
          code: 46986414,
          name: '黑魔术师',
          attack: 2500,
          defense: 2100,
          level: 7,
          attribute: 0x20),
      DuelCard(code: 70781052, name: '天使的施舍', type: CardType.spell),
      DuelCard(code: 53129443, name: '黑洞', type: CardType.spell),
    ]);
