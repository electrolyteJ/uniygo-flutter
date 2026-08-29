import 'package:flutter/material.dart';
import 'package:resource_data/card_info.dart';
import 'banlist_status_badge.dart';
import 'package:biz/widgets/card_detail_dialog.dart';

enum DeckZoneType { main, extra, side }

class DeckZoneWidget extends StatelessWidget {
  final DeckZoneType type;
  final List<CardInfo> cards;
  final String Function(int code) cardImageUrlOf;
  final String? Function(CardInfo card) banlistStatusOf;
  final void Function(CardInfo card, String zone) onAcceptCard;
  final void Function(String zone, CardInfo card) onRemoveCard;

  const DeckZoneWidget({
    super.key,
    required this.type,
    required this.cards,
    required this.cardImageUrlOf,
    required this.banlistStatusOf,
    required this.onAcceptCard,
    required this.onRemoveCard,
  });

  String get _zoneName {
    switch (type) {
      case DeckZoneType.main:
        return 'main';
      case DeckZoneType.extra:
        return 'extra';
      case DeckZoneType.side:
        return 'side';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<CardInfo>(
      onWillAcceptWithDetails: (details) {
        final card = details.data;
        // 额外卡组只接受融合/同调/XYZ/连接怪兽
        if (type == DeckZoneType.extra) {
          return card.isFusion || card.isSynchro || card.isXyz || card.isLink;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        final card = details.data;
        onAcceptCard(card, _zoneName);
      },
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;
        return Container(
          color: isOver ? const Color(0xFF344555).withValues(alpha: 0.5) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: cards.isEmpty && !isOver
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add,
                              size: 32,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '拖拽卡牌到此处',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              childAspectRatio: 591 / 825,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: cards.length,
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          return _DeckCardItem(
                            card: card,
                            type: type,
                            cardImageUrlOf: cardImageUrlOf,
                            banlistStatusOf: banlistStatusOf,
                            onRemoveCard: onRemoveCard,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeckCardItem extends StatelessWidget {
  final CardInfo card;
  final DeckZoneType type;
  final String Function(int code) cardImageUrlOf;
  final String? Function(CardInfo card) banlistStatusOf;
  final void Function(String zone, CardInfo card) onRemoveCard;

  const _DeckCardItem({
    required this.card,
    required this.type,
    required this.cardImageUrlOf,
    required this.banlistStatusOf,
    required this.onRemoveCard,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = cardImageUrlOf(card.code);
    final banlistStatus = banlistStatusOf(card);

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
                  color: Colors.black.withValues(alpha: 0.5),
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
      onDragStarted: () {},
      child: InkWell(
        onTap: () => _showCardDetail(context, card),
        onLongPress: _removeCard,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF344555),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          card.name.substring(0, _min(2, card.name.length)),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (banlistStatus != null)
                Positioned(
                  top: 4,
                  left: 4,
                  child: BanlistCornerBadge(status: banlistStatus),
                ),
              // 删除按钮（hover 时显示）
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: _removeCard,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF5350),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeCard() {
    final typeName = type == DeckZoneType.main
        ? 'main'
        : type == DeckZoneType.extra
        ? 'extra'
        : 'side';
    onRemoveCard(typeName, card);
  }

  void _showCardDetail(BuildContext context, CardInfo card) {
    CardDetailDialog.show(
      context,
      card: card,
      showAddButton: false,
      banlistStatus: banlistStatusOf(card),
      imageUrl: cardImageUrlOf(card.code),
    );
  }

  int _min(int a, int b) => a < b ? a : b;
}
