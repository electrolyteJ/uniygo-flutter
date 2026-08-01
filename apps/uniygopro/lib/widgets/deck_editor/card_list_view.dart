import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ygo_card/card_info.dart';
import '../../stores/deck_editor_store.dart';
import 'card_detail_dialog.dart';

class CardListView extends StatelessWidget {
  const CardListView({super.key});

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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return _CardListItem(card: card);
      },
    );
  }
}

class _CardListItem extends StatelessWidget {
  final CardInfo card;

  const _CardListItem({required this.card});

  @override
  Widget build(BuildContext context) {
    final store = context.read<DeckEditorStore>();
    final theme = Theme.of(context);
    final banlistStatus = store.getBanlistStatus(card);

    return LongPressDraggable<CardInfo>(
      data: card,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  child: Image.network(
                    'https://cdn02.moecube.com:444/images/ygopro-images-zh-CN/${card.code}.jpg',
                    width: 40,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    card.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCardContent(context, theme, banlistStatus),
      ),
      child: _buildCardContent(context, theme, banlistStatus),
    );
  }

  Widget _buildCardContent(BuildContext context, ThemeData theme, String? banlistStatus) {
    final store = context.read<DeckEditorStore>();

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {
          store.addCard(card);
        },
        onLongPress: () {
          CardDetailDialog.show(context, card: card, showAddButton: false);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  'https://cdn02.moecube.com:444/images/ygopro-images-zh-CN/${card.code}.jpg',
                  width: 40,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 40,
                      height: 56,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.image_not_supported),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            card.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (banlistStatus != null) ...[
                          const SizedBox(width: 8),
                          _BanlistDot(status: banlistStatus),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.typeText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (card.isMonster)
                Text(
                  '${card.attack >= 0 ? card.attack : "?"}/${card.defense >= 0 ? card.defense : "?"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BanlistDot extends StatelessWidget {
  final String status;

  const _BanlistDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case '禁止':
        color = Theme.of(context).colorScheme.error;
        break;
      case '限制':
        color = Colors.orange;
        break;
      case '准限制':
        color = Colors.yellow.shade700;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Tooltip(
      message: status,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
