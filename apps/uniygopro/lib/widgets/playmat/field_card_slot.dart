import 'package:flutter/material.dart';
import '../../models/FieldCard.dart';
import '../../stores/duel_room_state.dart';
import '../shared/card_image.dart';

class FieldCardSlot extends StatelessWidget {
  final FieldCard? card;
  final String label;
  final bool isMonster;
  final bool isSelected;
  final bool isSelectable;
  final VoidCallback? onTap;

  const FieldCardSlot({
    super.key,
    this.card,
    required this.label,
    this.isMonster = false,
    this.isSelected = false,
    this.isSelectable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final slotWidth = isMonster ? 56.0 : 48.0;
    final slotHeight = isMonster ? 78.0 : 64.0;

    if (card == null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: slotWidth,
          height: slotHeight,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelectable
                  ? Colors.amberAccent
                  : (isSelected ? Colors.cyanAccent : Colors.white12),
              width: isSelectable || isSelected ? 2 : 1,
            ),
            boxShadow: isSelectable
                ? [BoxShadow(color: Colors.amberAccent.withOpacity(0.4), blurRadius: 6)]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white24,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    // 判断表示形式: 0x1=攻击表侧, 0x2=守备表侧, 0x4=攻击里侧, 0x8=守备里侧
    final pos = card!.position;
    final isFaceUp = (pos & 0x1 != 0) || (pos & 0x2 != 0);
    final isDefense = (pos & 0x2 != 0) || (pos & 0x8 != 0);
    final isDisabled = card!.disabled;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: slotWidth,
        height: slotHeight,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? Colors.cyanAccent
                : (isSelectable
                    ? Colors.amberAccent
                    : (isDisabled ? Colors.redAccent : Colors.white30)),
            width: isSelected || isSelectable ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.cyanAccent.withOpacity(0.6), blurRadius: 8)]
              : (isSelectable
                  ? [BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 6)]
                  : (isDisabled
                      ? [BoxShadow(color: Colors.redAccent.withOpacity(0.35), blurRadius: 6)]
                      : [])),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 卡牌本体（攻击/守备旋转）
              Center(
                child: Transform.rotate(
                  angle: isDefense ? 1.5708 : 0, // 90度旋转表示守备状态
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      isFaceUp
                          ? CardImage(code: card!.code, width: slotWidth, height: slotHeight)
                          : Container(
                              width: slotWidth,
                              height: slotHeight,
                              decoration: BoxDecoration(
                                color: Colors.brown.shade800,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.amber.shade900),
                              ),
                              child: const Center(
                                child: Icon(Icons.shield_outlined, color: Colors.amber, size: 16),
                              ),
                            ),
                      if (isDisabled)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.38),
                            border: Border.all(color: Colors.redAccent, width: 1.5),
                          ),
                          child: const Center(
                            child: Icon(Icons.block, color: Colors.redAccent, size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 卡名（仅表侧显示）
              if (isFaceUp && card!.name != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    color: Colors.black45,
                    child: Text(
                      card!.name!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // 攻击力/守备力标签（怪兽且表侧）
              if (isFaceUp && isMonster && card!.attack != null)
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      '${card!.attack}',
                      style: const TextStyle(fontSize: 7, color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              // 叠材计数 (Xyz Materials)
              if (card!.overlayCount > 0)
                Positioned(
                  top: 1,
                  left: 1,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.purple,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${card!.overlayCount}',
                      style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
