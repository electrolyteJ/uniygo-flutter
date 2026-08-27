import 'package:flutter/material.dart';
import 'package:ygo_data/deck_info.dart';

class DeckListPanel extends StatelessWidget {
  final List<DeckInfo> decks;
  final String? currentDeckName;
  final bool isLocked;
  final void Function(String name) onSelectDeck;
  final void Function(String name) onCreateDeck;
  final void Function(String name) onDeleteDeck;

  const DeckListPanel({
    super.key,
    required this.decks,
    required this.currentDeckName,
    required this.isLocked,
    required this.onSelectDeck,
    required this.onCreateDeck,
    required this.onDeleteDeck,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2A3A4A),
        border: Border(right: BorderSide(color: Color(0xFF455A64))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF455A64))),
            ),
            child: const Text(
              '我的卡组',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          if (isLocked)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                '等待房间中仅允许编辑当前选中的卡组',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ),
          // 新建按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: isLocked ? null : () => _showCreateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('新建卡组'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: const Color(0xFF1E2A38),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // 卡组列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: decks.length,
              itemBuilder: (context, index) {
                final deck = decks[index];
                return _DeckListItem(
                  deck: deck,
                  isSelected: currentDeckName == deck.deckName,
                  onTap: isLocked
                      ? null
                      : () => onSelectDeck(deck.deckName),
                  onDelete: isLocked
                      ? null
                      : () => _confirmDelete(context, deck),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3A4A),
        title: const Text('新建卡组'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '输入卡组名称',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFFB300)),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                onCreateDeck(name);
                Navigator.pop(context);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: const Color(0xFF1E2A38),
            ),
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    DeckInfo deck,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3A4A),
        title: const Text('删除卡组'),
        content: Text('确定要删除卡组 "${deck.deckName}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              onDeleteDeck(deck.deckName);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _DeckListItem extends StatelessWidget {
  final DeckInfo deck;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _DeckListItem({
    required this.deck,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF37474F) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: const Color(0xFF344555),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 内置卡组图标
              if (deck.isBuiltin) ...[
                Icon(
                  Icons.book_outlined,
                  size: 16,
                  color: const Color(0xFFFFB300).withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.deckName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '主卡组 ${deck.mainCount} · 额外 ${deck.extraCount} · 备牌 ${deck.sideCount}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // 删除按钮
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
