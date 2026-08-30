import 'package:flutter/material.dart';

import 'hud_theme.dart';

/// 双方 HAND / DECK / EXTRA / GY / B 区域计数条（紧凑 chip 风格）。
///
/// 数据由调用方从 duelFieldProvider 派生传入（selfDeck / selfExtra /
/// selfGrave / selfRemoved / selfHand.length 等），本组件不做任何状态读取，
/// 保持纯展示 + 回调，便于 widget 测试与复用。
///
/// GY / EXTRA / B 可点击打开 room3 已有的区域浏览器
/// （FieldOverlayNotifier.openZoneBrowser），HAND / DECK 只读。
class ZoneCountBar extends StatelessWidget {
  const ZoneCountBar({
    super.key,
    required this.handCount,
    required this.deckCount,
    required this.extraCount,
    required this.graveCount,
    required this.removedCount,
    this.onExtraTap,
    this.onGraveTap,
    this.onRemovedTap,
  });

  final int handCount;
  final int deckCount;
  final int extraCount;
  final int graveCount;
  final int removedCount;
  final VoidCallback? onExtraTap;
  final VoidCallback? onGraveTap;
  final VoidCallback? onRemovedTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: HudTheme.panel(radius: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoneChip(label: 'HAND', count: handCount),
          const SizedBox(width: 4),
          _ZoneChip(label: 'DECK', count: deckCount),
          const SizedBox(width: 4),
          _ZoneChip(label: 'EXTRA', count: extraCount, onTap: onExtraTap),
          const SizedBox(width: 4),
          _ZoneChip(label: 'GY', count: graveCount, onTap: onGraveTap),
          const SizedBox(width: 4),
          _ZoneChip(label: 'B', count: removedCount, onTap: onRemovedTap),
        ],
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  const _ZoneChip({required this.label, required this.count, this.onTap});

  final String label;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null;
    final accent = tappable ? HudTheme.cyan : HudTheme.textSecondary;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tappable
            ? HudTheme.cyan.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: tappable
              ? HudTheme.cyan.withValues(alpha: 0.5)
              : HudTheme.panelBorder,
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: '$count',
              style: const TextStyle(
                color: HudTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
    if (!tappable) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: chip,
    );
  }
}
