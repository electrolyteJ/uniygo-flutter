import 'package:biz/service_singleton.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:flutter/material.dart';
import 'package:resource_data/card_info.dart';
import 'package:resource_data/deck_info.dart';

/// 卡组分区网格：主/额外/副三个分区展示卡片，支持减卡回调。
class DeckZoneGrid extends StatelessWidget {
  const DeckZoneGrid({
    super.key,
    required this.title,
    required this.cards,
    this.accent = const Color(0xFF37E2FF),
    this.onCardTap,
    this.onCardLongPress,
    this.cardBuilder,
  });

  final String title;
  final List<DeckCard> cards;
  final Color accent;

  /// 点卡回调（编辑器里 = 减卡；详情页 = 看详情）。
  final void Function(int code)? onCardTap;
  final void Function(int code)? onCardLongPress;

  /// 自定义卡片右上角角标（如数量徽标）。
  final Widget Function(DeckCard card)? cardBuilder;

  int get total => cards.fold(0, (sum, c) => sum + c.count);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            '$title（$total）',
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (cards.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('（空）',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final card in cards)
                _ZoneCardTile(
                  card: card,
                  onTap: onCardTap,
                  onLongPress: onCardLongPress,
                  badge: cardBuilder?.call(card),
                ),
            ],
          ),
      ],
    );
  }
}

class _ZoneCardTile extends StatelessWidget {
  const _ZoneCardTile({
    required this.card,
    this.onTap,
    this.onLongPress,
    this.badge,
  });

  final DeckCard card;
  final void Function(int code)? onTap;
  final void Function(int code)? onLongPress;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final info = ServiceSingleton.instance.dataService.getCardCached(card.code);
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(card.code),
      onLongPress:
          onLongPress == null ? null : () => onLongPress!(card.code),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CardImage(code: card.code, width: 56, height: 82),
          ),
          // 数量角标
          if (card.count > 1)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'x${card.count}',
                  style: const TextStyle(
                    color: Color(0xFF37E2FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (badge != null) Positioned(right: 0, top: 0, child: badge!),
          if (info != null) _banlistCorner(info),
        ],
      ),
    );
  }

  /// 禁限角标（0=禁 1=限一 2=限二）。
  Widget _banlistCorner(CardInfo info) {
    return const SizedBox.shrink();
  }
}
