import 'dart:async';

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/duel_room_exit.dart';
import '../theme/hud_theme.dart';

/// 决斗**结算页**：房间 tab 序列的第 ④ 页。
///
/// 层面定位：等候页 → 加载页 → 场地页 → **[本页]**。它不再是盖在场地上的
/// 叠层，而是与前三页平级的独立页面——这样四个阶段的代码各自独立，
/// tab 索引也统一由房间状态驱动（见 `_Tab`）。
///
/// **可见性由自己按 `duelResult` 判断**：房间页只负责「该切到第 ④ 页了」
/// （`duelResult != null`），本页拿到实例后再决定画不画。这样避免房间页
/// 与结算页两处各写一遍 `identical` 去重逻辑。
///
/// 「已关掉」状态收敛在本页内部：
/// - 换备阶段（match 局间）按钮为「进入换备阶段」，点击后记录当前 result
///   实例，同一实例不再展示（房间页会把 tab 切回等候页，本页短暂留在树下）；
/// - 其他情况按钮为「返回首页」离房。
/// 新一局 MSG_WIN 会生成新 result 实例，identical 比较失效自动重新展示，
/// 与 room1 的「父页按结果重建组件」行为等价。
class DuelEndPage extends ConsumerStatefulWidget {
  const DuelEndPage({super.key, this.onEnterSideDecking});

  /// 点击「进入换备阶段」时通知房间页切到换备 tab。
  final VoidCallback? onEnterSideDecking;

  @override
  ConsumerState<DuelEndPage> createState() => _DuelEndPageState();
}

class _DuelEndPageState extends ConsumerState<DuelEndPage> {
  /// 已关闭的结果（换备阶段点击「进入换备阶段」后记录；同一局结果不再
  /// 展示，新一局 MSG_WIN 的新实例由 identical 比较失效重新展示）。
  Object? _dismissed;

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(duelFieldProvider.select((s) => s.duelResult));
    if (result == null || identical(_dismissed, result)) {
      // 无结果、或该局结果已被关闭：空白占位（房间页此时通常已切走 tab）。
      return const ColoredBox(color: HudTheme.bgDeep);
    }
    // 防御性解析结果字段：生产端数据漂移/热重载可能缺字段，裸 as 强转
    // 会直接 TypeError 崩溃，缺失时回退合理默认值（对齐 room1）。
    // 观战者没有胜负立场（myController 恒为 1，didWin 不代表「我赢了」），
    // 标题/副标题都用中性文案（对齐 room1）。
    //
    // 但 didWin 仍可安全用于 selfName 那一行：它的定义就是
    // `winPlayer == myController`，而 selfName 也正是
    // `playerNameOf(myController)`。所以无论决斗者还是观战者，didWin
    // 都准确表示「selfName 这一方是否获胜」——只是别把它读成「本用户获胜」。
    final isDuelist = ref.watch(
      duelRoomProvider.select((s) => s.selfType.isDuelist),
    );
    final didWin = result['didWin'] as bool? ?? false;
    final winPlayer = result['winPlayer'] as int?;
    // 这两个是**决斗方**名字。名字缺失时观战者不能兜底成「自己 / 对手」——
    // 观战者不占任何一方的席位，退回中性引擎玩家编号。
    final selfName =
        result['selfName'] as String? ?? (isDuelist ? '自己' : '玩家 1');
    final opponentName =
        result['opponentName'] as String? ?? (isDuelist ? '对手' : '玩家 2');
    final selfLp = result['selfLp'] as int? ?? 0;
    final opponentLp = result['opponentLp'] as int? ?? 0;
    final reason = result['reason'] as int?;
    // 平局：服务端 MSG_WIN 的 winPlayer 为 PLAYER_NONE（ocgcore=2），
    // 此时 didWin 对双方都是 false，不能按「失败」展示。
    final isDraw = winPlayer != null && winPlayer != 0 && winPlayer != 1;
    // 赛博暗色胜负强调色：胜=金、负=蓝（cyan）、平局=中性灰。
    final accent = isDraw
        ? HudTheme.textSecondary
        : didWin
        ? HudTheme.gold
        : HudTheme.cyan;
    final title = isDraw
        ? '平局'
        : isDuelist
        ? (didWin ? '胜利' : '失败')
        : '决斗结束';
    final subtitle = isDraw
        ? '双方战平'
        : isDuelist
        ? (didWin ? '你赢下了这场决斗' : '这场决斗落败')
        : (didWin ? '$selfName 获胜' : '$opponentName 获胜');
    // match 比分：房间状态里累计的跨局战绩（换备页 / 场地页 / 本页共用）。
    // 观战者不计分也不显示（他们没有立场，比分对观战没有意义）。
    final room = ref.watch(duelRoomProvider);
    final showScore = isDuelist && room.matchGamesPlayed > 0;
    // match 局间换备阶段（RoomSideDecking）：按钮改「进入换备阶段」关闭
    // 本页进入换备（自持 _dismissed）；否则「返回首页」离房。
    final isSideDecking = ref.watch(
      duelRoomProvider.select((s) => s.stage is RoomSideDecking),
    );
    final actionLabel = isSideDecking ? '进入换备阶段' : '返回首页';
    final VoidCallback onAction = isSideDecking
        ? () {
            setState(() => _dismissed = result);
            widget.onEnterSideDecking?.call();
          }
        : () => unawaited(leaveRoomAfterNotJoined(context, ref));

    return ColoredBox(
      color: HudTheme.bgDeep,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            decoration: HudTheme.glowPanel(glow: accent, radius: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [Shadow(color: accent, blurRadius: 18)],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: HudTheme.body.copyWith(color: HudTheme.textSecondary),
                ),
                if (showScore) ...[
                  const SizedBox(height: 20),
                  _MatchScore(
                    room: room,
                    accent: accent,
                    selfName: selfName,
                    opponentName: opponentName,
                  ),
                ],
                const SizedBox(height: 28),
                _ResultRow(
                  label: selfName,
                  value: selfLp,
                  highlight: didWin,
                  accent: accent,
                ),
                const SizedBox(height: 12),
                _ResultRow(label: opponentName, value: opponentLp),
                const SizedBox(height: 24),
                Text(
                  '结束原因：${reason == null ? '未知' : _reasonText(reason)}',
                  style: HudTheme.caption,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Text(actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// MSG_WIN 的 reason 码 → 可读文案。
///
/// 取值来自 ocgcore：基础胜负由处理器产生（processor.cpp：
/// 1=LP 归零、2=卡组抽尽），0 为认输（服务器收到 CTOS_SURRENDER 后下发）；
/// 0x10 起为卡片效果的特殊胜利（ocgcore constant.lua 的 WIN_REASON_*）。
/// duelink 未导出这些常量，这里本地维护，未知值保留原始码兜底。
String _reasonText(int reason) {
  switch (reason) {
    case 0x00:
      return '认输';
    case 0x01:
      return 'LP 归零';
    case 0x02:
      return '卡组抽尽';
    case 0x10:
      return '被封印的艾克佐迪亚';
    case 0x11:
      return '终焉的倒计时';
    case 0x12:
      return '蛇神';
    case 0x13:
      return '光之创造神 哈拉克提';
    case 0x14:
      return '艾克佐迪亚之亡灵';
    case 0x15:
      return '通灵字板';
    case 0x16:
      return '最后一回合';
    case 0x17:
      return '木偶狮子';
    case 0x18:
      return '灾厄狮子';
    case 0x19:
      return 'Jackpot 7';
    case 0x1A:
      return '接力灵魂';
    case 0x1B:
      return '鬼计恶作剧';
    case 0x1C:
      return '幻象螺旋';
    case 0x1D:
      return 'FA 胜利者';
    case 0x1E:
      return '飞天象';
    case 0x1F:
      return '艾克佐迪亚守护者';
    case 0x21:
      return '真正的艾克佐迪亚';
    case 0x22:
      return '最终抽卡';
    case 0x30:
      return '创造奇迹';
    case 0x52:
      return 'No.iC1000  numeronius numeronia';
    case 0x53:
      return '虚无之门';
    case 0x54:
      return '平局决胜';
    case 0x56:
      return '卡组大师';
    case 0x57:
      return '命运抽卡';
    case 0x58:
      return '音乐相扑';
    case 0x59:
      return '暑假作业';
    default:
      return '特殊胜利（代码 $reason）';
  }
}

/// 结算页的 match 比分板：`GAME 2 / 3` + `我方 1 : 0 对手`。
///
/// 数据来自房间状态累计的跨局战绩。BO3 里拿到 2 胜即结束，此时额外提示
/// 「本场已结束」，避免玩家以为还要再打一局。
class _MatchScore extends StatelessWidget {
  const _MatchScore({
    required this.room,
    required this.accent,
    required this.selfName,
    required this.opponentName,
  });

  final DuelRoomState room;
  final Color accent;
  final String selfName;
  final String opponentName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          room.matchGameLabel,
          style: HudTheme.caption.copyWith(
            color: HudTheme.textSecondary,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                selfName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: HudTheme.body.copyWith(
                  color: HudTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${room.myMatchWins}',
              style: TextStyle(
                color: accent,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                fontFamily: 'JetBrains Mono',
                shadows: [Shadow(color: accent, blurRadius: 12)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                ':',
                style: TextStyle(
                  color: HudTheme.textSecondary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${room.opponentMatchWins}',
              style: const TextStyle(
                color: HudTheme.textSecondary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                fontFamily: 'JetBrains Mono',
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                opponentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HudTheme.body.copyWith(
                  color: HudTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (room.isMatchOver) ...[
          const SizedBox(height: 6),
          Text('本场已结束', style: HudTheme.caption.copyWith(color: accent)),
        ] else if (room.matchDraws > 0) ...[
          const SizedBox(height: 6),
          Text(
            '平局 ${room.matchDraws} 局（不计胜场）',
            style: HudTheme.caption.copyWith(color: HudTheme.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// 单侧玩家结果行：名字 + LP，胜方金色高亮。
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.accent,
  });

  final String label;
  final int value;
  final bool highlight;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final highlightColor = accent ?? HudTheme.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: highlight
            ? highlightColor.withValues(alpha: 0.10)
            : const Color(0xFF0E1626),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? highlightColor.withValues(alpha: 0.7)
              : HudTheme.panelBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: HudTheme.body.copyWith(
                color: HudTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            'LP $value',
            style: TextStyle(
              color: highlight ? highlightColor : HudTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
