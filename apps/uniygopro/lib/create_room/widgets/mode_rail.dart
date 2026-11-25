/// 左侧模式选择：圆钮 rail（匹配 / 好友 / 练习）与环境 rail（自由房间）。
library;

import 'package:flutter/material.dart';

import 'package:ygo_settings/theme/duel_controls.dart';
import 'package:ygo_settings/theme/duel_theme.dart';
import '../models/mode_models.dart';

/// 模式图标（按条目 id）。
IconData iconForMode(String id) {
  return switch (id) {
    'athletic' => Icons.emoji_events_outlined,
    'casual' => Icons.sports_esports_outlined,
    'friend-tag' => Icons.group_outlined,
    'friend-match' => Icons.view_agenda_outlined,
    'friend-single' => Icons.crop_square,
    'friend-408' => Icons.dns_outlined,
    'practice-ai' => Icons.smart_toy_outlined,
    'practice-puzzle' => Icons.adjust,
    'practice-tutorial' => Icons.menu_book_outlined,
    _ => Icons.sports_esports_outlined,
  };
}

/// 左侧模式 rail（圆钮 + 标签，匹配 / 好友 / 练习共用）。
class ModeRail extends StatelessWidget {
  const ModeRail({
    super.key,
    required this.entries,
    required this.selected,
    required this.onSelect,
  });

  final List<DuelModeEntry> entries;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final n = entries.length;
    final start = 166.0 - (n - 1) * 28.0;
    return Stack(
      children: [
        for (var i = 0; i < n; i++)
          Positioned(
            left: 8,
            top: start + i * 56 - 6,
            width: 160,
            height: 56,
            child: DuelHit(
              key: ValueKey('mode-entry-${entries[i].id}'),
              onTap: () => onSelect(i),
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 6,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: i == selected
                            ? DuelColors.surfaceSelected
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i == selected
                              ? DuelColors.accent
                              : const Color(0xFF1A3048),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        iconForMode(entries[i].id),
                        size: 28,
                        color: i == selected
                            ? DuelColors.accent
                            : DuelColors.textMuted,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 60,
                    top: 21,
                    width: 92,
                    child: Text(
                      entries[i].title,
                      style: DuelType.sans(
                        8,
                        color: i == selected
                            ? DuelColors.accent
                            : DuelColors.textGhost,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 自由房间的左侧环境 rail（纵向三行，带副标题与行尾说明）。
class FreeEnvRail extends StatelessWidget {
  const FreeEnvRail({
    super.key,
    required this.entries,
    required this.selected,
    required this.onSelect,
  });

  final List<DuelModeEntry> entries;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var i = 0; i < entries.length; i++)
          Positioned(
            left: 16,
            top: 40 + i * 58,
            width: 176,
            height: 50,
            child: DuelHit(
              key: ValueKey('mode-entry-${entries[i].id}'),
              onTap: () => onSelect(i),
              child: Container(
                decoration: BoxDecoration(
                  color: i == selected
                      ? DuelColors.surfaceSelected
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Stack(
                  children: [
                    if (i == selected)
                      Positioned(
                        left: 0,
                        top: 11,
                        child: Container(
                          width: 3,
                          height: 28,
                          decoration: BoxDecoration(
                            color: DuelColors.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 6,
                      child: Text(
                        entries[i].title,
                        textAlign: TextAlign.center,
                        style: DuelType.sans(
                          12.5,
                          color: i == selected
                              ? DuelColors.textPrimary
                              : DuelColors.textMuted,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 22,
                      child: Text(
                        entries[i].subtitle,
                        textAlign: TextAlign.center,
                        style: DuelType.sans(8, color: DuelColors.textFaint),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 34,
                      child: Text(
                        entries[i].rightText,
                        textAlign: TextAlign.center,
                        style: DuelType.sans(
                          7.5,
                          color: i == selected
                              ? DuelColors.accent
                              : DuelColors.textGhost,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
