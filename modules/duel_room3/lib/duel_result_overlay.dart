import 'dart:async';
import 'dart:math' as math;

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'duel_room_exit.dart';
import 'hud/hud_theme.dart';

/// 结算面板在 regular / wide 档的最大宽度（room3 窄于 room1 的 560）。
const double _panelMaxWidthWide = 520;

/// 结算面板在 compact 档的宽度上限（实际取 `min(viewport.width * 0.9, 420)`）。
const double _panelMaxWidthCompactCap = 420;

/// LP 条比例尺下限：常规开局 LP（match/tag 初始可能更高，按实际数值抬升）。
/// 只用于把 LP 换算成条长，不参与结算数据推导。
const int _lpBaseline = 8000;

/// 内建全屏结算 overlay（room3 宿主未注册结算页路由，改为房间内自绘）。
///
/// 自己 watch duelFieldProvider 的 duelResult：非空时盖在场地/等待室之上，
/// 空时返回透明占位（SizedBox.shrink）不拦截任何点击，因此父页只需把它
/// 常驻挂在 body Stack 顶层，无需按结果是否存在条件挂载。
///
/// 遮罩（ModalBarrier，点击不关闭）与「已关闭」状态收敛在本组件内部：
/// - 换备阶段（match 局间）按钮为「进入换备阶段」，点击后记录当前 result
///   实例，同一实例不再弹出；同时提供「返回首页」次按钮作为离房出口
///   （此前换备阶段被模态锁死，只能一路进入换备）。换备阶段离房等于放弃
///   本场（判负），因此该按钮必须先过二次确认；
/// - 其他情况按钮为「返回首页」离房。
/// 新一局 MSG_WIN 会生成新 result 实例，identical 比较失效自动重新弹出，
/// 与 room1 的「父页按结果重建组件」行为等价。
///
/// 档位取真实视口（`MediaQuery`，扣除安全区；与 `DuelRoomLayoutSpec` 同一
/// 套断点）：wide/regular 面板宽 520、胜者侧 LP 条、按钮并排；
/// compact（可用宽 < 1024 或高 < 600）面板宽
/// `min(viewport.width * 0.9, 420)`、LP 条收起为纯数值、按钮纵向堆叠且
/// 最小高 48。
class DuelResultOverlay extends ConsumerStatefulWidget {
  /// 换备阶段「返回首页」二次确认通过后的离房动作。
  ///
  /// 缺省走 [leaveRoomAfterNotJoined]（断开并回首页）；宿主可注入自定义
  /// 离房流程，测试也借此断言「确认后才离房」。
  final VoidCallback? onLeave;

  const DuelResultOverlay({super.key, this.onLeave});

  @override
  ConsumerState<DuelResultOverlay> createState() => _DuelResultOverlayState();
}

class _DuelResultOverlayState extends ConsumerState<DuelResultOverlay> {
  /// 已关闭的结果 map（换备阶段点击「进入换备阶段」后记录；同一局结果
  /// 不再重复弹出，新一局 MSG_WIN 的新实例由 identical 比较失效重新弹出）。
  Object? _dismissed;

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
              backgroundColor: HudTheme.danger,
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
    final result = ref.watch(duelFieldProvider.select((s) => s.duelResult));
    if (result == null || identical(_dismissed, result)) {
      // 无结果、或该局结果已被关闭（进入换备）：透明占位不拦截点击。
      return const SizedBox.shrink();
    }
    // 防御性解析结果字段：生产端数据漂移/热重载可能缺字段，裸 as 强转
    // 会直接 TypeError 崩溃，缺失时回退合理默认值（对齐 room1）。
    final didWin = result['didWin'] as bool? ?? false;
    final winPlayer = result['winPlayer'] as int?;
    final selfName = result['selfName'] as String? ?? '自己';
    final opponentName = result['opponentName'] as String? ?? '对手';
    // LP 允许缺失（部分结算来源不下发）：缺失即不展示 LP 区，不造 0。
    final selfLp = result['selfLp'] as int?;
    final opponentLp = result['opponentLp'] as int?;
    final hasLp = selfLp != null || opponentLp != null;
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
    // 弹窗进入换备（自持 _dismissed）；否则「返回首页」离房。
    final isSideDecking = ref.watch(
      duelRoomProvider.select((s) => s.stage is RoomSideDecking),
    );
    final actionLabel = isSideDecking ? '进入换备阶段' : '返回首页';
    final VoidCallback onAction = isSideDecking
        ? () => setState(() => _dismissed = result)
        : () => unawaited(leaveRoomAfterNotJoined(context, ref));

    // 真实视口档位（与 duel_room1 的 DuelRoomLayoutSpec 同一套断点）：
    // room3 没有注入布局 spec 的 InheritedWidget，这里直接从 MediaQuery 推导，
    // 不做任何全局缩放改写。
    final media = MediaQuery.of(context);
    final viewport = media.size;
    final available = Size(
      viewport.width - media.padding.horizontal,
      viewport.height - media.padding.vertical,
    );
    final isCompact = available.width < 1024 || available.height < 600;
    final panelMaxWidth = isCompact
        ? math.min(viewport.width * 0.9, _panelMaxWidthCompactCap)
        : _panelMaxWidthWide;
    final minButtonHeight = isCompact ? 48.0 : 44.0;
    final maxLp = math.max(_lpBaseline, math.max(selfLp ?? 0, opponentLp ?? 0));
    // 胜方高亮只对局内玩家有意义（观战者没有胜负立场）。
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
      fit: StackFit.expand,
      children: [
        // 模态遮罩：拦截点击，不关闭。
        ModalBarrier(
          dismissible: false,
          color: HudTheme.bgDeep.withValues(alpha: 0.72),
        ),
        Center(
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: panelMaxWidth,
                maxHeight: available.height * 0.94,
              ),
              child: Container(
                key: const ValueKey('duel-result-panel'),
                padding: isCompact
                    ? const EdgeInsets.fromLTRB(20, 24, 20, 18)
                    : const EdgeInsets.fromLTRB(28, 32, 28, 24),
                decoration: HudTheme.glowPanel(
                  glow: accent,
                  radius: isCompact ? 18 : 24,
                ),
                // 面板宽度固定在 panelMaxWidth（信息卡不随内容宽度抖动）。
                // 结构：信息区可滚动 + 按钮区常驻面板底部——与 room1 的
                // ResponsivePanel（actions 在 Flexible(body) 之外）对齐。
                // 若把按钮塞进滚动区，640×360 + 换备双按钮时第二颗按钮会被
                // 裁掉半截（实测 rect.bottom 361.8 > 视口 360），用户必须先
                // 滚动才能看到出口，compact 下等于不可用。
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: isCompact ? 28 : 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(color: accent, blurRadius: 18),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                style: HudTheme.body.copyWith(
                                  color: HudTheme.textSecondary,
                                ),
                              ),
                              SizedBox(height: isCompact ? 16 : 24),
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
                                '结束原因：${reason == null ? '未知' : _reasonText(reason)}',
                                textAlign: TextAlign.center,
                                style: HudTheme.caption,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? 16 : 24),
                      _ResultActionRow(stacked: isCompact, buttons: actions),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 结算按钮组：宽档并排等分，compact 档纵向堆叠（撑满整行）。
class _ResultActionRow extends StatelessWidget {
  const _ResultActionRow({required this.stacked, required this.buttons});

  final bool stacked;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    if (buttons.length == 1) {
      return SizedBox(width: double.infinity, child: buttons.single);
    }
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
    final highlightColor = accent;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? highlightColor.withValues(alpha: 0.10)
            : const Color(0xFF0E1626),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(
          color: highlight
              ? highlightColor.withValues(alpha: 0.7)
              : HudTheme.panelBorder,
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
                  style: HudTheme.body.copyWith(
                    color: HudTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12 : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'LP $value',
                style: TextStyle(
                  color: highlight ? highlightColor : HudTheme.textSecondary,
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
                  highlight
                      ? highlightColor
                      : highlightColor.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
