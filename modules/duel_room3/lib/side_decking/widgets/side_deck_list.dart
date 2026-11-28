import 'package:flutter/material.dart';
import 'package:resource_data/card_info.dart' show CardInfo;

import '../../theme/cyber_side_tokens.dart';
import 'side_top_bar.dart' show SideText;

/// 副卡组列表的一行（设计稿 531:2 中栏的四条 `副卡名 + 副卡类`）。
///
/// 设计稿采用「左侧 2px 色条 + 卡名 + 卡类副标」的双行结构，可读性远高于
/// 旧实现的「名字 + →主/→额 按钮」横排——换备时玩家要先认出卡，才能决定
/// 挪哪张，卡类（怪兽/魔法/陷阱 + 星级 + 属性）是认出卡的关键。
class SideDeckRow extends StatelessWidget {
  const SideDeckRow({
    super.key,
    required this.card,
    required this.subtitle,
    this.barColor = CyberSideTokens.cyan,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  final CardInfo card;

  /// `怪兽 · 3 星 · 地属性`，由调用方根据卡信息拼。
  final String subtitle;

  final Color barColor;
  final bool selected;
  final VoidCallback? onTap;

  /// 行尾附加内容（如「→主」小按钮）。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final name = card.name.isNotEmpty ? card.name : '${card.code}';
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: selected ? CyberSideTokens.cardSelectedBg : null,
            border: Border(
              left: BorderSide(
                color: selected ? CyberSideTokens.danger : barColor,
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SideText(
                      name,
                      size: CyberSideTokens.fsBody,
                      color: CyberSideTokens.textPrimary,
                    ),
                    const SizedBox(height: 2),
                    SideText(
                      subtitle,
                      size: CyberSideTokens.fsMicro,
                      color: CyberSideTokens.textSecondary,
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// 副卡组列表。
///
/// 点一行 = 把这张卡从副卡组挪回主卡组（或额外卡组，按卡类型自动判定）。
/// 设计稿的「→主 / →额」小按钮在 158px 宽的栏里放不下两行文字，改成
/// 「点整行即归还」——比旧实现少一次点击，也不会有按错分区的可能。
class SideDeckList extends StatelessWidget {
  const SideDeckList({
    super.key,
    required this.cards,
    required this.subtitleOf,
    this.selectedIndex,
    this.onTapIndex,
    this.emptyHint = '副卡组为空',
  });

  final List<CardInfo> cards;
  final String Function(CardInfo card) subtitleOf;
  final int? selectedIndex;
  final void Function(int index)? onTapIndex;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SideText(
          emptyHint,
          size: CyberSideTokens.fsSmall,
          color: CyberSideTokens.textDim,
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: cards.length,
      itemExtent: 36,
      itemBuilder: (context, i) {
        final selected = selectedIndex == i;
        return SideDeckRow(
          card: cards[i],
          subtitle: subtitleOf(cards[i]),
          selected: selected,
          onTap: onTapIndex == null ? null : () => onTapIndex!(i),
        );
      },
    );
  }
}
