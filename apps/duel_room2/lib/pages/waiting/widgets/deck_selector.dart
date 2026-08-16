import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:ygo_data/deck_info.dart';

class DeckSelector extends StatelessWidget {
  final bool enabled;
  final List<DeckInfo> decks;
  final String? selectedDeckName;
  final int mySlot;
  final ValueChanged<String?>? onSelectDeck;
  final VoidCallback? onEditDeck;
  final List<String>? invalidationResult;

  const DeckSelector({
    super.key,
    this.enabled = true,
    required this.decks,
    required this.selectedDeckName,
    required this.mySlot,
    required this.onSelectDeck,
    this.onEditDeck,
    this.invalidationResult,
  });

  @override
  Widget build(BuildContext context) {
    final invalid = invalidationResult?.isNotEmpty == true;
    final isPlayer = mySlot >= 0 && mySlot <= 1;
    final hasSelectedDeck =
        selectedDeckName != null &&
        decks.any((d) => d.deckName == selectedDeckName);
    if (!isPlayer) return const SizedBox.shrink();
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
              Text(
                '卡组',
                style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
              ),
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
                // 卡组可能在编辑器中被删除：selectedDeckName 不在 items 里时
                // DropdownButton 会断言失败，改用已算好的 hasSelectedDeck 兜底。
                value: hasSelectedDeck ? selectedDeckName : null,
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
                onChanged: enabled ? onSelectDeck : null,
              ),
            ),
          if (hasSelectedDeck)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                () {
                  final deck = decks.firstWhere(
                    (d) => d.deckName == selectedDeckName,
                  );
                  return '主: ${deck.mainCount}  额: ${deck.extraCount}  副: ${deck.sideCount}';
                }(),
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11),
              ),
            ),
          if (hasSelectedDeck)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onEditDeck,
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('编辑当前卡组'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber.shade200,
                    side: BorderSide(color: Colors.amber.shade700),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ),
          if (invalid)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 14,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '卡组不合规',
                          style: TextStyle(
                            color: Colors.red.shade400,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ...invalidationResult!.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(top: 2, left: 18),
                        child: Text(
                          '• $e',
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!invalid)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.green.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '卡组合规',
                    style: TextStyle(
                      color: Colors.green.shade400,
                      fontSize: 12,
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

@Preview(name: 'DeckSelector', size: Size(320, 220), brightness: Brightness.dark)
Widget previewDeckSelector() => DeckSelector(
      decks: [DeckInfo(deckName: '青眼卡组'), DeckInfo(deckName: '黑魔导卡组')],
      selectedDeckName: '青眼卡组',
      mySlot: 0,
      onSelectDeck: (_) {},
    );

