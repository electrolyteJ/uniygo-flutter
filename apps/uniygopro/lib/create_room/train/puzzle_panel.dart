/// 残局面板：页内残局选择层（设计语言对齐建房页，不是旧的 bottom sheet）。
library;

import 'package:duelink_ai_edo/duelink_puzzle.dart';
import 'package:flutter/material.dart';

import 'package:ygo_settings/theme/duel_controls.dart';
import 'package:ygo_settings/theme/duel_theme.dart';

/// 残局选择层（页内弹层，非旧 sheet）。
class PuzzlePanel extends StatelessWidget {
  const PuzzlePanel({
    super.key,
    required this.future,
    required this.onSelect,
    required this.onClose,
  });

  final Future<List<PuzzleInfo>>? future;
  final ValueChanged<PuzzleInfo> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onClose,
              child: Container(color: Colors.black.withValues(alpha: 0.62)),
            ),
          ),
          Positioned(
            left: 162,
            top: 46,
            width: 520,
            height: 286,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF080F19),
                border: Border.all(color: DuelColors.borderPanel),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
                    child: Row(
                      children: [
                        Text('残局挑战', style: DuelType.sans(11)),
                        const SizedBox(width: 8),
                        Text(
                          '选择残局后进入本地对局',
                          style: DuelType.sans(
                            8,
                            color: DuelColors.textFaint,
                          ),
                        ),
                        const Spacer(),
                        DuelHit(
                          onTap: onClose,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              '✕',
                              style: DuelType.sans(
                                10,
                                color: DuelColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: DuelColors.divider),
                  Expanded(
                    child: FutureBuilder<List<PuzzleInfo>>(
                      future: future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return Center(
                            child: Text(
                              '加载残局…',
                              style: DuelType.sans(
                                9,
                                color: DuelColors.textMuted,
                              ),
                            ),
                          );
                        }
                        final puzzles = snapshot.data ?? const <PuzzleInfo>[];
                        if (puzzles.isEmpty) {
                          return Center(
                            child: Text(
                              '没有可用残局',
                              style: DuelType.sans(
                                9,
                                color: DuelColors.textMuted,
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: puzzles.length,
                          itemBuilder: (context, i) {
                            final p = puzzles[i];
                            return DuelHit(
                              onTap: () => onSelect(p),
                              child: Container(
                                height: 24,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: DuelType.sans(
                                          9,
                                          color: DuelColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '进入 ›',
                                      style: DuelType.sans(
                                        8,
                                        color: DuelColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
