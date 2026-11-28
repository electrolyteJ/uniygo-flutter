import 'package:flutter/material.dart';

import '../../theme/cyber_side_tokens.dart';
import 'side_top_bar.dart' show SideText;

/// 卡面在界面里的五种形态（设计稿 531:2 与 531:147 提炼）。
enum SideCardKind {
  /// 主卡组卡：青底青边。
  main,

  /// 额外卡组卡：紫底紫边。
  extra,

  /// 副卡组卡：深青底青边（更暗，示意「在场外」）。
  side,

  /// 被选中、等待交换：紫红底品红边（531:147 的「选中主卡」）。
  selected,

  /// 空位（缺卡）：只有橄榄色虚线边 + 「待补」。
  pending,
}

/// 换备卡面。
///
/// 三种尺寸复用同一个组件：主卡组网格 30×30、额外卡组 28×24、
/// 副卡组缩略 28×38。设计稿卡面内不画卡图，只画色块 + 右下角的
/// `×N` 张数角标——换备是数字操作，认卡牌靠名字不靠图案。
class SideCard extends StatelessWidget {
  const SideCard({
    super.key,
    required this.kind,
    this.width = CyberSideTokens.gridCardSize,
    this.height = CyberSideTokens.gridCardSize,
    this.count,
    this.badge,
    this.label,
    this.onTap,
    this.selected = false,
  });

  final SideCardKind kind;
  final double width;
  final double height;

  /// 右下角张数角标（`×3`），null 不显示。
  final String? count;

  /// 中央角标（「选中」/「待补」），null 不显示。
  final String? badge;

  /// 卡名（副卡组列表用；卡面网格不显示）。
  final String? label;

  final VoidCallback? onTap;

  /// 是否高亮（选中态或点击高亮）。
  final bool selected;

  ({Color fill, Color line}) get _colors => switch (kind) {
    SideCardKind.main => (
      fill: CyberSideTokens.cardMainBg,
      line: CyberSideTokens.cyan,
    ),
    SideCardKind.extra => (
      fill: CyberSideTokens.cardExtraBg,
      line: CyberSideTokens.extraViolet,
    ),
    SideCardKind.side => (
      fill: CyberSideTokens.cardSideBg,
      line: CyberSideTokens.cyan,
    ),
    SideCardKind.selected => (
      fill: CyberSideTokens.cardSelectedBg,
      line: CyberSideTokens.danger,
    ),
    SideCardKind.pending => (
      fill: Colors.transparent,
      line: CyberSideTokens.pendingLine,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(CyberSideTokens.radius),
        border: Border.all(
          color: c.line,
          width: selected && kind != SideCardKind.selected ? 1.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          if (badge != null)
            Center(
              child: SideText(
                badge!,
                size: CyberSideTokens.fsMicro,
                color: kind == SideCardKind.pending
                    ? CyberSideTokens.acid
                    : CyberSideTokens.danger,
              ),
            ),
          if (count != null)
            Positioned(
              right: 2,
              bottom: 1,
              child: SideText(
                count!,
                size: CyberSideTokens.fsSmall,
                color: CyberSideTokens.acid,
                weight: FontWeight.w700,
                mono: true,
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      ),
    );
  }
}

/// 卡面网格（主卡组 / 额外卡组共用）。
///
/// 设计稿用绝对坐标一格格摆，这里用 [Wrap] 保证列数由可用宽度决定——
/// 屏幕变窄时自动减少列数而不是溢出。
///
/// 每格右下角的 `×N` 是**连续同名卡的聚合**：YGOPro 卡组里同名牌的份数
/// 只受禁限表约束，逐张画 40 格会让人数不清，画成「一张卡 ×3」更接近
/// 玩家心智，也与设计稿一致。聚合只发生在**相邻同名**卡之间，点击时
/// 传回的是该组**首张卡的真实下标**（[onTapIndex]），保证换卡不会错位。
class SideCardGrid extends StatelessWidget {
  const SideCardGrid({
    super.key,
    required this.items,
    required this.kind,
    this.cardWidth = CyberSideTokens.gridCardSize,
    this.cardHeight = CyberSideTokens.gridCardSize,
    this.gap = CyberSideTokens.gridGap,
    this.selectedIndex,
    this.pendingCount = 0,
    this.onTapIndex,
    this.onTapPending,
  });

  /// 逐张卡的名字（同名卡会出现多次）。
  final List<String> items;

  final SideCardKind kind;
  final double cardWidth;
  final double cardHeight;
  final double gap;

  /// 当前选中（等待交换）的下标。
  final int? selectedIndex;

  /// 末尾补几个空位（缺卡时提示「待补」）。
  final int pendingCount;

  /// 点击第 [index] 项（[items] 的下标，不是聚合后的组下标）。
  final void Function(int index)? onTapIndex;

  final VoidCallback? onTapPending;

  /// 把连续同名卡聚合成 `(名字, 首张下标, 张数)` 组。
  ///
  /// 只聚合**连续**同名——换备里卡组按卡名排序，连续才符合同名卡成群
  /// 的观感；跨位置的同名卡仍分开显示，便于精确点中要挪走的那一张。
  static List<({String name, int start, int count})> group(List<String> items) {
    final groups = <({String name, int start, int count})>[];
    for (var i = 0; i < items.length; i++) {
      final last = groups.isEmpty ? null : groups.last;
      if (last != null && last.name == items[i]) {
        groups[groups.length - 1] = (
          name: last.name,
          start: last.start,
          count: last.count + 1,
        );
      } else {
        groups.add((name: items[i], start: i, count: 1));
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = group(items);
    return Wrap(
      spacing: gap,
      runSpacing: gap == CyberSideTokens.gridGap ? 8 : gap,
      children: [
        for (final g in groups)
          SideCard(
            kind: _isSelected(g) ? SideCardKind.selected : kind,
            width: cardWidth,
            height: cardHeight,
            // 角标：×N 与「选中」在同一格右下/中央，不冲突。
            count: g.count > 1 ? '×${g.count}' : null,
            badge: _isSelected(g) && cardHeight >= 30 ? '选中' : null,
            onTap: onTapIndex == null ? null : () => onTapIndex!(g.start),
          ),
        for (var i = 0; i < pendingCount; i++)
          SideCard(
            kind: SideCardKind.pending,
            width: cardWidth,
            height: cardHeight,
            badge: cardHeight >= 30 ? '待补' : null,
            onTap: onTapPending,
          ),
      ],
    );
  }

  /// 组内任意一张被选中：整组显示为选中态（同名卡视觉上是一个整体）。
  bool _isSelected(({String name, int start, int count}) g) {
    final s = selectedIndex;
    if (s == null) return false;
    return s >= g.start && s < g.start + g.count;
  }
}
