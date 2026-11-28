import 'package:biz/duel/room/duel_room_state.dart';
import 'package:flutter/material.dart';

import '../../theme/hud_theme.dart';
import '../../theme/duel_style.dart';

void showDeckCheckDialog(BuildContext context, DuelRoomState room) {
  final issues = room.invalidationDeckResult ?? const <String>[];
  final ok = issues.isEmpty;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: duelPanel,
      title: const Text('卡组校验明细', style: HudTheme.title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.verified : Icons.error_outline,
                  size: 16,
                  color: ok ? duelHeal : duelDanger,
                ),
                const SizedBox(width: 6),
                Text(
                  ok ? '校验通过' : '${issues.length} 项未通过',
                  style: HudTheme.body.copyWith(
                    color: ok ? duelHeal : duelDanger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: duelLine),
            const SizedBox(height: 8),
            if (ok)
              Text('当前卡组符合禁限卡表与卡组数量规则', style: HudTheme.caption)
            else
              for (final issue in issues.take(12))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(Icons.circle, size: 4, color: duelDanger),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          issue,
                          style: HudTheme.caption.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
            if (issues.length > 12) ...[
              const SizedBox(height: 4),
              Text(
                '…还有 ${issues.length - 12} 项',
                style: HudTheme.caption.copyWith(fontSize: 10),
              ),
            ],
            if (!ok) ...[
              const SizedBox(height: 8),
              Text(
                '可点「变更」切换或编辑卡组后重新校验',
                style: HudTheme.caption.copyWith(fontSize: 10, color: duelCyan),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
