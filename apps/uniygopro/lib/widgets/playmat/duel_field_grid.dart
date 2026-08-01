import 'package:flutter/material.dart';
import '../../stores/duel_room_state.dart';
import 'field_card_slot.dart';

class DuelFieldGrid extends StatelessWidget {
  final DuelRoomState duel;
  final Function(FieldCard? card, int? code)? onCardSelect;

  const DuelFieldGrid({
    super.key,
    required this.duel,
    this.onCardSelect,
  });

  FieldCard? _getCard(int controller, int zone, int sequence) {
    return duel.fieldCards['${controller}_${zone}_$sequence'];
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D141E).withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyan.shade900.withOpacity(0.4), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 15, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 对手魔陷区 (5槽位) + 额外卡组 (左) + 场地 (右)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDeckSlot('EX', duel.oppExtra, isExtra: true),
                  const SizedBox(width: 8),
                  ...List.generate(5, (i) {
                    final card = _getCard(1, 8, 4 - i); // 镜像次序
                    return FieldCardSlot(
                      card: card,
                      label: 'S/T ${5 - i}',
                      onTap: () => onCardSelect?.call(card, card?.code),
                    );
                  }),
                  const SizedBox(width: 8),
                  _buildZoneSlot(_getCard(1, 8, 5), '场地', isMonster: false),
                ],
              ),

              const SizedBox(height: 4),

              // 对手怪兽区 (5槽位) + 墓地 (左) + 除外 (右)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCountSlot('除外', duel.oppRemoved, Colors.deepOrangeAccent),
                  const SizedBox(width: 8),
                  ...List.generate(5, (i) {
                    final card = _getCard(1, 4, 4 - i); // 镜像次序
                    return FieldCardSlot(
                      card: card,
                      label: 'M ${5 - i}',
                      isMonster: true,
                      onTap: () => onCardSelect?.call(card, card?.code),
                    );
                  }),
                  const SizedBox(width: 8),
                  _buildCountSlot('墓地', duel.oppGrave, Colors.grey.shade400),
                ],
              ),

              const SizedBox(height: 6),

              // 额外怪兽区 (EMZ 2槽位)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 56),
                  FieldCardSlot(
                    card: _getCard(1, 4, 5) ?? _getCard(0, 4, 5),
                    label: 'EMZ 1',
                    isMonster: true,
                    onTap: () {
                      final c = _getCard(1, 4, 5) ?? _getCard(0, 4, 5);
                      onCardSelect?.call(c, c?.code);
                    },
                  ),
                  const SizedBox(width: 90),
                  FieldCardSlot(
                    card: _getCard(1, 4, 6) ?? _getCard(0, 4, 6),
                    label: 'EMZ 2',
                    isMonster: true,
                    onTap: () {
                      final c = _getCard(1, 4, 6) ?? _getCard(0, 4, 6);
                      onCardSelect?.call(c, c?.code);
                    },
                  ),
                  const SizedBox(width: 56),
                ],
              ),

              const SizedBox(height: 6),

              // 己方怪兽区 (5槽位) + 墓地 (左) + 除外 (右)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCountSlot('墓地', duel.selfGrave, Colors.grey.shade400),
                  const SizedBox(width: 8),
                  ...List.generate(5, (i) {
                    final card = _getCard(0, 4, i);
                    return FieldCardSlot(
                      card: card,
                      label: 'M ${i + 1}',
                      isMonster: true,
                      onTap: () => onCardSelect?.call(card, card?.code),
                    );
                  }),
                  const SizedBox(width: 8),
                  _buildCountSlot('除外', duel.selfRemoved, Colors.deepOrangeAccent),
                ],
              ),

              const SizedBox(height: 4),

              // 己方魔陷区 (5槽位) + 场地 (左) + 主卡组 (右)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildZoneSlot(_getCard(0, 8, 5), '场地', isMonster: false),
                  const SizedBox(width: 8),
                  ...List.generate(5, (i) {
                    final card = _getCard(0, 8, i);
                    return FieldCardSlot(
                      card: card,
                      label: 'S/T ${i + 1}',
                      onTap: () => onCardSelect?.call(card, card?.code),
                    );
                  }),
                  const SizedBox(width: 8),
                  _buildDeckSlot('DECK', duel.selfDeck, isExtra: false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneSlot(FieldCard? card, String label, {required bool isMonster}) {
    return FieldCardSlot(
      card: card,
      label: label,
      isMonster: isMonster,
      onTap: () => onCardSelect?.call(card, card?.code),
    );
  }

  Widget _buildDeckSlot(String label, int count, {required bool isExtra}) {
    return Container(
      width: 48,
      height: 64,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isExtra ? Colors.purple.shade900.withOpacity(0.3) : Colors.blue.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isExtra ? Colors.purpleAccent : Colors.cyanAccent, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isExtra ? Colors.purpleAccent : Colors.cyanAccent,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCountSlot(String label, int count, Color color) {
    return Container(
      width: 48,
      height: 64,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
