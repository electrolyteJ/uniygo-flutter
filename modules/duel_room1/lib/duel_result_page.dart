import 'dart:async';
import 'dart:math' as math;

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:duel_room1/layout/responsive_panel.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'duel_room_exit.dart';

/// 结算强调色：对齐 room3 `HudTheme` 的既有胜负规则
/// （胜=金 / 负=青 / 平=中性灰）。
///
/// room1 不依赖 duel_room3（两个房间模块互不引用），这里本地复刻同值色板，
/// 色值逐字取自 `modules/duel_room3/lib/hud/hud_theme.dart` 的
/// `gold` / `cyan` / `textSecondary`，不另造色值。
const Color kDuelResultWinAccent = Color(0xFFFFD75A); // HudTheme.gold
const Color kDuelResultLoseAccent = Color(0xFF37E2FF); // HudTheme.cyan
const Color kDuelResultDrawAccent = Color(0xFF8A93A8); // HudTheme.textSecondary

/// 危险操作色（弃权离房确认按钮），取 room3 `HudTheme.danger` 同值。
const Color kDuelResultDanger = Color(0xFFFF5A5A);

/// 结算面板在 regular / wide 档的最大宽度。
const double kDuelResultPanelMaxWidth = 560;

/// 结算面板在 compact 档的宽度上限（实际取 `min(viewport.width * 0.9, 420)`）。
const double kDuelResultPanelCompactCap = 420;

/// LP 条比例尺下限：常规开局 LP（match/tag 初始可能更高，按实际数值抬升），
/// 只用来把 LP 换算成条长，不参与任何结算数据推导。
const int kDuelResultLpBaseline = 8000;

/// 全屏居中模态半弹窗：决斗结果展示。
///
/// 仅当服务端下发 MSG_WIN（duelResult 非空）时由决斗页挂载；组件自持
/// 全屏遮罩（ModalBarrier，点击不关闭）：
/// - 换备阶段（match 局间）按钮为「进入换备阶段」，通过 [onDismissed]
///   通知父页按结果 identity 关闭弹窗；同时给出「返回首页」次按钮，
///   避免换备阶段被模态锁死在房间内（此前唯一出口只有进入换备）。
///   换备阶段离房等于放弃本场（判负），因此该按钮必须先过二次确认；
/// - 其他情况按钮为「返回首页」离房。
/// 新一局 MSG_WIN 产生新结果 map 时，父页自动恢复展示。
/// 结果 [Map] 键：didWin / winPlayer / reason / selfName / opponentName /
/// selfLp / opponentLp，防御性解析缺字段回退默认值（LP 缺失时整块 LP 区
/// 不展示，不拿 0 冒充真实数据）。
///
/// 档位沿用房间页注入的 [DuelRoomLayoutSpec]（真实视口推导，不引入新的
/// 全局缩放）：wide/regular 面板宽 560、胜者侧 LP 条、按钮并排；
/// compact 面板宽 `min(viewport.width * 0.9, 420)`、按钮纵向堆叠且最小高 48。
class DuelResultPage extends ConsumerStatefulWidget {
  final Map<String, Object?> result;
  final VoidCallback? onAction;
  final VoidCallback? onDismissed;

  /// 换备阶段「返回首页」二次确认通过后的离房动作。
  ///
  /// 缺省走 [leaveRoomAfterNotJoined]（断开并回首页）；宿主可注入自定义
  /// 离房流程，测试也借此断言「确认后才离房」。
  final VoidCallback? onLeave;

  const DuelResultPage({
    super.key,
    required this.result,
    this.onAction,
    this.onDismissed,
    this.onLeave,
  });

  @override
  ConsumerState<DuelResultPage> createState() => _DuelResultPageState();
}

class _DuelResultPageState extends ConsumerState<DuelResultPage> {
  /// 换备阶段离房 = 放弃本场（判负）：先二次确认，避免误触丢局。
  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃本场比赛？'),
        content: const Text('换备阶段离开房间将放弃本场对局（判负）并返回首页，确定吗？'),
        actions: [
          TextButton(
            key: const ValueKey('duel-result-leave-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('duel-result-leave-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: kDuelResultDanger,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放弃并返回首页'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (widget.onLeave != null) {
      widget.onLeave!();
      return;
    }
    await leaveRoomAfterNotJoined(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    // 防御性解析结果字段：深链/热重载/生产端数据漂移可能缺字段，
    // 裸 as 强转会直接 TypeError 崩溃，缺失时回退合理默认值。
    final didWin = widget.result['didWin'] as bool? ?? false;
    final winPlayer = widget.result['winPlayer'] as int?;
    final selfName = widget.result['selfName'] as String? ?? '自己';
    final opponentName = widget.result['opponentName'] as String? ?? '对手';
    // LP 允许缺失（部分结算来源不下发）：缺失就不展示 LP 区，不造数据。
    final selfLp = widget.result['selfLp'] as int?;
    final opponentLp = widget.result['opponentLp'] as int?;
    final hasLp = selfLp != null || opponentLp != null;
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
        ? kDuelResultDrawAccent
        : didWin
        ? kDuelResultWinAccent
        : kDuelResultLoseAccent;
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

    // 档位来自房间页注入的真实视口规格；未注入（孤立挂载/调试）时
    // DuelRoomLayout.of 回退 fixed（regular），与 ResponsivePanel 一致。
    final spec = DuelRoomLayout.of(context);
    final isCompact = spec.tier == DuelRoomLayoutTier.compact;
    final panelMaxWidth = isCompact
        ? math.min(spec.viewport.width * 0.9, kDuelResultPanelCompactCap)
        : kDuelResultPanelMaxWidth;
    final minButtonHeight = isCompact ? 48.0 : 44.0;
    final maxLp = math.max(
      kDuelResultLpBaseline,
      math.max(selfLp ?? 0, opponentLp ?? 0),
    );

    // 文字色块：胜方高亮只对局内玩家有意义（观战者没有胜负立场）。
    final highlightSelf = isDuelist && !isDraw && didWin;
    final highlightOpponent = isDuelist && !isDraw && !didWin;

    // 主按钮固定 key `duel-result-action`（集成测试与既有用例依赖）；
    // 换备阶段追加「返回首页」次按钮（真实出口，非占位死按钮）。
    final actions = <Widget>[
      FilledButton(
        key: const ValueKey('duel-result-action'),
        onPressed: onAction,
        style: FilledButton.styleFrom(
          minimumSize: Size(44, minButtonHeight),
          backgroundColor: accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        child: Text(actionLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      if (isSideDecking)
        OutlinedButton(
          key: const ValueKey('duel-result-leave'),
          // 弃权离房：先弹二次确认，确认后才走离房流程。
          onPressed: () => unawaited(_confirmLeave()),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(44, minButtonHeight),
            foregroundColor: accent,
            side: BorderSide(color: accent.withValues(alpha: 0.6)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text(
            '返回首页',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];

    return Stack(
      children: [
        // 模态遮罩：拦截点击，不关闭。
        ModalBarrier(
          dismissible: false,
          color: Colors.black.withValues(alpha: 0.55),
        ),
        ResponsivePanel(
          panelKey: const ValueKey('duel-result-panel'),
          maxWidth: panelMaxWidth,
          // 结算面板是固定宽度的信息卡（不由内容宽度撑缩），
          // 免得长对局名/短原因把面板宽度拉得各不相同。
          wrapWidth: false,
          decoration: BoxDecoration(
            color: const Color(0xEE10141C),
            borderRadius: BorderRadius.circular(isCompact ? 18 : 24),
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
                    fontSize: isCompact ? 28 : 34,
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
                SizedBox(height: isCompact ? 14 : 20),
                _ResultDivider(color: accent),
                if (hasLp) ...[
                  const SizedBox(height: 14),
                  if (selfLp != null)
                    _ResultRow(
                      label: selfName,
                      value: selfLp,
                      ratio: selfLp / maxLp,
                      highlight: highlightSelf,
                      accent: accent,
                      showBar: !isCompact,
                      compact: isCompact,
                    ),
                  if (selfLp != null && opponentLp != null)
                    const SizedBox(height: 10),
                  if (opponentLp != null)
                    _ResultRow(
                      label: opponentName,
                      value: opponentLp,
                      ratio: opponentLp / maxLp,
                      highlight: highlightOpponent,
                      accent: accent,
                      showBar: !isCompact,
                      compact: isCompact,
                    ),
                  const SizedBox(height: 14),
                  _ResultDivider(color: accent),
                ],
                const SizedBox(height: 12),
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
          actions: _ResultActionRow(stacked: isCompact, buttons: actions),
        ),
      ],
    );
  }
}

/// 结算按钮组：宽档并排等分，compact 档纵向堆叠（每个按钮撑满整行）。
///
/// 单按钮时不另加容器，交给 ResponsivePanel 的 stretch 列撑满宽度，
/// 保持与旧实现一致的「整行主按钮」观感。
class _ResultActionRow extends StatelessWidget {
  const _ResultActionRow({required this.stacked, required this.buttons});

  final bool stacked;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    if (buttons.length == 1) return buttons.single;
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            buttons[i],
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }
}

/// 结算面板内的细分隔线（按胜负强调色淡染）。
class _ResultDivider extends StatelessWidget {
  const _ResultDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0.0),
          ],
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

/// 单侧玩家结果行：名字 + LP（胜方高亮），宽档附 LP 比例条。
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.ratio,
    required this.highlight,
    required this.accent,
    required this.showBar,
    required this.compact,
  });

  final String label;
  final int value;
  final double ratio;
  final bool highlight;
  final Color accent;
  final bool showBar;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? accent.withValues(alpha: 0.12)
            : const Color(0xFF171C27),
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(
          color: highlight
              ? accent.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'LP $value',
                style: TextStyle(
                  color: highlight ? accent : Colors.white70,
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (showBar) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(
                  highlight ? accent : accent.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
