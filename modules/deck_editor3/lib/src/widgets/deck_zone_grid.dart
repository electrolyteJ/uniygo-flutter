import 'package:biz/widgets/card_image.dart';
import 'package:flutter/material.dart';
import 'package:resource_data/deck_info.dart';

import 'banlist_badge.dart';

/// 卡组分区网格：主/额外/副三个分区展示卡片，支持移除/详情回调与禁限角标。
class DeckZoneGrid extends StatelessWidget {
  const DeckZoneGrid({
    super.key,
    required this.title,
    required this.cards,
    this.accent = const Color(0xFF37E2FF),
    this.onCardTap,
    this.onCardLongPress,
    this.onRemove,
    this.banlistStatusOf,
    this.cardBuilder,
    this.cardWidth = 56,
    this.cardHeight = 82,
  });

  final String title;
  final List<DeckCard> cards;
  final Color accent;

  /// 卡片缩略图尺寸（详情页可传入更大尺寸以便看清）。
  final double cardWidth;
  final double cardHeight;

  /// 点卡回调（编辑器/详情页 = 看详情）。
  final void Function(int code)? onCardTap;
  final void Function(int code)? onCardLongPress;

  /// 右上角「×」移除按钮回调（编辑器 = 减卡）。
  final void Function(int code)? onRemove;

  /// 禁限状态查询（禁止/限制/准限制），null 表示无限制或未加载禁限表。
  final String? Function(int code)? banlistStatusOf;

  /// 自定义卡片角标。
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
                  onRemove: onRemove,
                  banlistStatusOf: banlistStatusOf,
                  badge: cardBuilder?.call(card),
                  width: cardWidth,
                  height: cardHeight,
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
    this.onRemove,
    this.banlistStatusOf,
    this.badge,
    this.width = 56,
    this.height = 82,
  });

  final DeckCard card;
  final void Function(int code)? onTap;
  final void Function(int code)? onLongPress;
  final void Function(int code)? onRemove;
  final String? Function(int code)? banlistStatusOf;
  final Widget? badge;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final banlistStatus = banlistStatusOf?.call(card.code);
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(card.code),
      onLongPress:
          onLongPress == null ? null : () => onLongPress!(card.code),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CardImage(code: card.code, width: width, height: height),
          ),
          // 数量角标（右下）
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
          // 禁限角标（左上）
          if (banlistStatus != null)
            Positioned(
              top: 2,
              left: 2,
              child: BanlistCornerBadge(status: banlistStatus),
            ),
          // 移除按钮（右上）
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: _RemoveButton(onTap: () => onRemove!(card.code)),
            ),
          // 自定义角标（左下，避免与移除/禁限角标重叠）
          if (badge != null) Positioned(left: 0, bottom: 0, child: badge!),
        ],
      ),
    );
  }
}

/// 右上角圆形「×」移除按钮。
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFFEF5350),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 12, color: Colors.white),
      ),
    );
  }
}
