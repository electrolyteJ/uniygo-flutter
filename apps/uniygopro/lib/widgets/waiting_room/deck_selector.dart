import 'package:flutter/material.dart';
import '../../stores/duel_room_state.dart';

class DeckSelector extends StatelessWidget {
  final DuelRoomState state;
  final int mySlot;
  const DeckSelector({super.key, required this.state, required this.mySlot});

  @override
  Widget build(BuildContext context) {
    final isPlayer = mySlot >= 0 && mySlot <= 1;
    if (!isPlayer) return const SizedBox.shrink();

    final decks = state.availableDecks;
    final selected = state.selectedDeckName;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade700,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.style, size: 14, color: Colors.blueGrey.shade400),
              const SizedBox(width: 6),
              Text('卡组', style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          if (decks.isEmpty)
            Text(
              '没有可用卡组，请先在主页创建卡组',
              style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade800,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blueGrey.shade600),
              ),
              child: DropdownButton<String>(
                value: selected,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                dropdownColor: Colors.blueGrey.shade800,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: decks.map((d) {
                  return DropdownMenuItem(
                    value: d.deckName,
                    child: Text(d.deckName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    state.selectDeck(value);
                  }
                },
              ),
            ),
          if (selected != null && decks.any((d) => d.deckName == selected))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                () {
                  final deck = decks.firstWhere((d) => d.deckName == selected);
                  return '主: ${deck.mainCount}  额: ${deck.extraCount}  副: ${deck.sideCount}';
                }(),
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
