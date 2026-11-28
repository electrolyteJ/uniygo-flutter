import 'dart:async';

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../duel_room_exit.dart';
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
  const DuelEndPage({super.key});

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
    final didWin = result['didWin'] as bool? ?? false;
    final winPlayer = result['winPlayer'] as int?;
    final selfName = result['selfName'] as String? ?? '自己';
    final opponentName = result['opponentName'] as String? ?? '对手';
    final selfLp = result['selfLp'] as int? ?? 0;
    final opponentLp = result['opponentLp'] as int? ?? 0;
    final reason = result['reason'] as int?;
    // 平局：服务端 MSG_WIN 的 winPlayer 为 PLAYER_NONE（ocgcore=2），
    // 此时 didWin 对双方都是 false，不能按「失败」展示。
    final isDraw = winPlayer != null && winPlayer != 0 && winPlayer != 1;
    // 观战者没有胜负立场（myController 恒为 1，didWin 只是随机的座位
    // 对齐结果），标题/副标题都用中性文案（对齐 room1）。
    final isDuelist = ref.watch(
      duelRoomProvider.select((s) => s.selfType.isDuelist),
    );
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
    // match 局间换备阶段（RoomSideDecking）：按钮改「进入换备阶段」关闭
    // 本页进入换备（自持 _dismissed）；否则「返回首页」离房。
    final isSideDecking = ref.watch(
      duelRoomProvider.select((s) => s.stage is RoomSideDecking),
    );
    final actionLabel = isSideDecking ? '进入换备阶段' : '返回首页';
    final VoidCallback onAction = isSideDecking
        ? () => setState(() => _dismissed = result)
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
