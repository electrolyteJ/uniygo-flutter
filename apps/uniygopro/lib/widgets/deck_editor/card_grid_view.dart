import 'package:flutter/material.dart';
import 'package:ygo_data/card_info.dart';
import 'banlist_status_badge.dart';
import 'package:duel_room1/widgets/card_detail_dialog.dart';

class CardGridView extends StatelessWidget {
  final List<CardInfo> cards;
  final String? Function(CardInfo card) banlistStatusOf;
  final String Function(int code) cardImageUrlOf;
  final void Function(CardInfo card) onAddCard;

  const CardGridView({
    super.key,
    required this.cards,
    required this.banlistStatusOf,
    required this.cardImageUrlOf,
    required this.onAddCard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        return _CardGridItem(
          card: card,
          banlistStatusOf: banlistStatusOf,
          cardImageUrlOf: cardImageUrlOf,
          onAddCard: onAddCard,
        );
      },
    );
  }
}

class _CardGridItem extends StatelessWidget {
  final CardInfo card;
  final String? Function(CardInfo card) banlistStatusOf;
  final String Function(int code) cardImageUrlOf;
  final void Function(CardInfo card) onAddCard;

  const _CardGridItem({
    required this.card,
    required this.banlistStatusOf,
    required this.cardImageUrlOf,
    required this.onAddCard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final banlistStatus = banlistStatusOf(card);
    final imageUrl = cardImageUrlOf(card.code);

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
              child: Image.network(imageUrl, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCardContent(context, theme, banlistStatus, imageUrl),
      ),
      onDragStarted: () {
        // 拖拽开始
      },
      child: InkWell(
        onTap: () {
          onAddCard(card);
        },
        onDoubleTap: () {
          CardDetailDialog.show(
            context,
            card: card,
            showAddButton: false,
            banlistStatus: banlistStatus,
            imageUrl: imageUrl,
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: _buildCardContent(context, theme, banlistStatus, imageUrl),
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    ThemeData theme,
    String? banlistStatus,
    String imageUrl,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor, width: 1),
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        imageUrl,
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
                  if (banlistStatus != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: BanlistCornerBadge(status: banlistStatus),
                    ),
                ],
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
