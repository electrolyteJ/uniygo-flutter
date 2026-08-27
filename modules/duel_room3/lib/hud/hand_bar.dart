import 'dart:math' as math;

import 'package:biz/widgets/card_image.dart';
import 'package:flutter/material.dart';

import 'hud_theme.dart';

/// MDPro3 风格己方手牌横排：底部扇形微展开，选中卡上浮，
/// 点卡 → 详情/动作；就地选择中高亮可选手牌。
class HandBar extends StatelessWidget {
  const HandBar({
    super.key,
    required this.cards,
    required this.selectedSequence,
    required this.selectableSequences,
    required this.checkedSequences,
    required this.onCardTap,
  });

  /// 手牌卡号列表（selfHand）。
  final List<int> cards;

  /// 当前选中（弹出动作条）的手牌序号。
  final int? selectedSequence;

  /// 就地选择中可选中的手牌序号集合。
  final Set<int> selectableSequences;

  /// 就地选择中已勾选的手牌序号集合。
  final Set<int> checkedSequences;

  final void Function(int sequence, int code) onCardTap;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    const cardW = 64.0;
    const cardH = 93.0;
    // 手牌多时压缩间距
    final gap = cards.length <= 1
        ? 0.0
        : math.min(cardW * 0.72, (620 - cardW) / (cards.length - 1));
    final totalW = cardW + gap * (cards.length - 1);
    return SizedBox(
      height: cardH + 26,
      child: Center(
        child: SizedBox(
          width: totalW,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < cards.length; i++)
                _HandCard(
                  key: ValueKey('hand_$i'),
                  code: cards[i],
                  width: cardW,
                  height: cardH,
                  left: i * gap,
                  selected: i == selectedSequence,
                  selectable: selectableSequences.contains(i),
                  checked: checkedSequences.contains(i),
                  onTap: () => onCardTap(i, cards[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HandCard extends StatelessWidget {
  const _HandCard({
    super.key,
    required this.code,
    required this.width,
    required this.height,
    required this.left,
    required this.selected,
    required this.selectable,
    required this.checked,
    required this.onTap,
  });

  final int code;
  final double width;
  final double height;
  final double left;
  final bool selected;
  final bool selectable;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glowColor = checked
        ? HudTheme.heal
        : selectable
            ? HudTheme.cyan
            : selected
                ? HudTheme.gold
                : null;
    return Positioned(
      left: left,
      bottom: selected || checked ? 18 : 0,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: glowColor ?? HudTheme.panelBorder,
              width: glowColor != null ? 2 : 1,
            ),
            boxShadow: glowColor != null
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.6),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CardImage(
              code: code,
              width: width,
              height: height,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
