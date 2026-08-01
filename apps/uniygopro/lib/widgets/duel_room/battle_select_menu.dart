import 'package:flutter/material.dart';
import '../../stores/duel_room_state.dart';

class BattleSelectMenu extends StatelessWidget {
  final List<BattleAction> actions;
  final void Function(BattleAction action) onSelect;
  const BattleSelectMenu({super.key, required this.actions, required this.onSelect});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('战斗阶段', style: TextStyle(color: Colors.white, fontSize: 16)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        for (final action in actions)
          ActionChip(
            label: Text(_labelFor(action)),
            onPressed: () => onSelect(action),
          ),
      ]),
    ]),
  );

  String _labelFor(BattleAction action) {
    if (action.directAttack) return '直接攻击';
    switch (action.type) {
      case 1: return '攻击';
      case 2: return '待机';
      default: return '行动${action.sequence}';
    }
  }
}
