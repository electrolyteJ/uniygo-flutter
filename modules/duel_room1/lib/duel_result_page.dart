import 'dart:async';

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'duel_room_exit.dart';
import 'package:duel_room1/layout/responsive_panel.dart';

/// 全屏居中模态半弹窗：决斗结果展示。
///
/// 仅当服务端下发 MSG_WIN（duelResult 非空）时由决斗页挂载；组件自持
/// 全屏遮罩（ModalBarrier，点击不关闭）：
/// - 换备阶段（match 局间）按钮为「进入换备阶段」，通过 [onDismissed]
///   通知父页按结果 identity 关闭弹窗；
/// - 其他情况按钮为「返回首页」离房。
/// 新一局 MSG_WIN 产生新结果 map 时，父页自动恢复展示。
/// 结果 [Map] 键：didWin / winPlayer / reason / selfName / opponentName /
/// selfLp / opponentLp，防御性解析缺字段回退默认值。
class DuelResultPage extends ConsumerStatefulWidget {
  final Map<String, Object?> result;
  final VoidCallback? onAction;
  final VoidCallback? onDismissed;

  const DuelResultPage({
    super.key,
    required this.result,
    this.onAction,
    this.onDismissed,
  });

  @override
  ConsumerState<DuelResultPage> createState() => _DuelResultPageState();
}

class _DuelResultPageState extends ConsumerState<DuelResultPage> {
  @override
  Widget build(BuildContext context) {
    // 防御性解析结果字段：深链/热重载/生产端数据漂移可能缺字段，
    // 裸 as 强转会直接 TypeError 崩溃，缺失时回退合理默认值。
    final didWin = widget.result['didWin'] as bool? ?? false;
    final winPlayer = widget.result['winPlayer'] as int?;
    final selfName = widget.result['selfName'] as String? ?? '自己';
    final opponentName = widget.result['opponentName'] as String? ?? '对手';
    final selfLp = widget.result['selfLp'] as int? ?? 0;
    final opponentLp = widget.result['opponentLp'] as int? ?? 0;
    final rawReason = widget.result['reason'];
    final reason = rawReason is int ? rawReason : null;
    // 平局：服务端 MSG_WIN 的 winPlayer 为 PLAYER_NONE（ocgcore=2），
    // 此时 didWin 对双方都是 false，不能按「失败」展示。
    final isDraw = winPlayer != null && winPlayer != 0 && winPlayer != 1;
    // 观战者没有胜负立场（myController 恒为 1，didWin 只是随机的座位
    // 对齐结果），标题/副标题都用中性文案。
    final isDuelist = ref.watch(
      duelRoomProvider.select((s) => s.selfType.isDuelist),
    );
    final accent = isDraw
        ? const Color(0xFF9E9E9E)
        : didWin
        ? const Color(0xFFD7B65A)
        : const Color(0xFF7BA7D9);
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
    // 弹窗进入换备（自持 _dismissed）；否则「返回首页」离房。
    final isSideDecking = ref.watch(
      duelRoomProvider.select((s) => s.stage is RoomSideDecking),
    );
    final actionLabel = isSideDecking ? '进入换备阶段' : '返回首页';
    final VoidCallback onAction = isSideDecking
        ? widget.onDismissed ?? () {}
        : widget.onAction ??
              () => unawaited(leaveRoomAfterNotJoined(context, ref));
    return Stack(
      children: [
        // 模态遮罩：拦截点击，不关闭。
        ModalBarrier(
          dismissible: false,
          color: Colors.black.withValues(alpha: 0.55),
        ),
        ResponsivePanel(
          panelKey: const ValueKey('duel-result-panel'),
          maxWidth: 520,
          wrapWidth: true,
          decoration: BoxDecoration(
            color: const Color(0xEE10141C),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withValues(alpha: 0.75)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.16),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          header: const SizedBox.shrink(),
          body: SingleChildScrollView(
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                _ResultRow(label: selfName, value: selfLp, highlight: didWin),
                const SizedBox(height: 12),
                _ResultRow(label: opponentName, value: opponentLp),
                const SizedBox(height: 20),
                Text(
                  '结束原因：${_reasonText(reason)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          // 宽度由 ResponsivePanel 的 stretch 撑满；去掉 width: double.infinity
          // 以免其无穷固有宽度让 IntrinsicWidth 无法收缩面板。
          actions: FilledButton(
            key: const ValueKey('duel-result-action'),
            onPressed: onAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size(44, 44),
              backgroundColor: accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

/// MSG_WIN 的 reason 码 → 可读文案。
///
/// 取值来自 ocgcore：基础胜负由处理器产生（processor.cpp：
/// 1=LP 归零、2=卡组抽尽），0 为认输（服务器收到 CTOS_SURRENDER 后下发）；
/// 0x10 起为卡片效果的特殊胜利（ocgcore constant.lua 的 WIN_REASON_*）。
/// duelink 未导出这些常量，这里本地维护，未知值保留原始码兜底。
String _reasonText(int? reason) {
  if (reason == null) return '未知';
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

class _ResultRow extends StatelessWidget {
  final String label;
  final int value;
  final bool highlight;

  const _ResultRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: highlight ? const Color(0x1FD7B65A) : const Color(0xFF171C27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight
              ? const Color(0x80D7B65A)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            'LP $value',
            style: TextStyle(
              color: highlight ? const Color(0xFFD7B65A) : Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
