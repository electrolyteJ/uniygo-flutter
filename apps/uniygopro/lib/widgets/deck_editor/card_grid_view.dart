import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ygo_card/card_info.dart';
import '../../stores/deck_editor_store.dart';
import 'card_detail_dialog.dart';

class CardGridView extends StatelessWidget {
  const CardGridView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DeckEditorStore>();
    final theme = Theme.of(context);
    final cards = store.searchResults;

    if (cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '无搜索结果',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 591 / 825,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return _CardGridItem(card: card);
      },
    );
  }
}

class _CardGridItem extends StatelessWidget {
  final CardInfo card;

  const _CardGridItem({required this.card});

  @override
  Widget build(BuildContext context) {
    final store = context.read<DeckEditorStore>();
    final theme = Theme.of(context);

    return LongPressDraggable<CardInfo>(
      data: card,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: Container(
            width: 80,
            height: 112,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                'https://cdn02.moecube.com:444/images/ygopro-images-zh-CN/${card.code}.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCardContent(context, theme),
      ),
      onDragStarted: () {
        // 拖拽开始
      },
      child: InkWell(
        onTap: () {
          store.addCard(card);
        },
        onDoubleTap: () {
          CardDetailDialog.show(context, card: card, showAddButton: false);
        },
        borderRadius: BorderRadius.circular(8),
        child: _buildCardContent(context, theme),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  'https://cdn02.moecube.com:444/images/ygopro-images-zh-CN/${card.code}.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        card.name.substring(0, _min(2, card.name.length)),
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              card.name,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

int _min(int a, int b) => a < b ? a : b;
