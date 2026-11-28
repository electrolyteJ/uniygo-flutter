import 'package:biz/duel/room/duel_room_state.dart';
import 'package:flutter/material.dart';

import '../../theme/cyber_side_tokens.dart';
import '../../widgets/player_seats.dart';
import 'side_countdown.dart';
import 'side_top_bar.dart';
import 'side_zone.dart';

/// 等待对手界面（Ardot 531:245「08z-03 换备 · 等待对手」）。
///
/// 版式：左栏卡组快照（换备后卡组 / 已生效换牌 / 副卡组留存 / 主卡组缩略），
/// 右栏就绪圈 + 对手状态 + 本机估算进度条。底栏「重新提交 / 已提交·等待」。
///
/// 与编辑界面的关系：同一页的两种形态，由 [DuelRoomState.sidingSubmitted]
/// 切换。之所以不让玩家在提交后继续编辑，是因为服务端已经收到整包卡组，
/// 再改草稿只会在本地产生「看起来变了但没生效」的错觉——要改必须重新提交。
class SideWaitingView extends StatelessWidget {
  const SideWaitingView({
    super.key,
    required this.room,
    required this.onResubmit,
    required this.onCancelEdit,
  });

  final DuelRoomState room;

  /// 「重新提交」：退回编辑形态。
  final VoidCallback onResubmit;

  /// 「已提交 · 等待」只是状态展示，但设计稿给了它一个按钮位置，
  /// 传入 null 即绘制禁用态。
  final VoidCallback? onCancelEdit;

  @override
  Widget build(BuildContext context) {
    final seats = PlayerSeats.of(room);
    // room3 的换备页对所有身份都会进入：观战者也走这条链路（房间级换备
    // 状态是共享的）。观战者没有「我 / 对手」的立场，称谓全部退回玩家名。
    final isDuelist = room.selfType.isDuelist;
    final me = seats.selfSeat;
    final myName = !isDuelist
        ? (seats.left.isNotEmpty ? seats.left.first.name : '玩家 1')
        : me == null
        ? '我'
        : room.players.where((p) => p.pos == me).firstOrNull?.name ?? '我';
    final opp = seats.right.isNotEmpty ? seats.right.first : null;
    // 观战者视角下「右列」也只是座位对齐的产物，不能兜底成「对手」。
    final oppName = opp?.name ?? (isDuelist ? '对手' : '玩家 2');

    return Column(
      children: [
        // 倒计时每秒重建：只包顶条，不让整页跟着 1s 刷新。
        SideCountdown(
          startedAt: room.sidingStartedAt,
          builder: (context, remaining, critical) => SideTopBar(
            title: isDuelist ? '换备 · 等待对手' : '换备 · 观战',
            subtitle: isDuelist
                ? '卡组已提交，等待对手换备 · 服务端无时限，可自由等待'
                : '双方正在换备 · 服务端无时限，可自由等待',
            accent: CyberSideTokens.heal,
            gameLabel: room.matchGameLabel,
            myName: myName,
            opponentName: opp?.name,
            // 观战者不计分（与换备编辑页 / 场地页 / 结算页一致）。
            myScore: isDuelist ? room.myMatchWins : null,
            opponentScore: isDuelist ? room.opponentMatchWins : null,
            showScore: isDuelist,
            // 已提交后仍在等对手：同样会因久等被服务端断开，故保留倒计时。
            // 这里不挂 onExpired——卡组已经交上去了，超时能做的是服务端
            // 推进阶段或断连，客户端没有可执行的兜底动作。
            timerText: formatCountdown(remaining),
            timerCritical: critical,
            timerHint: '换备计时',
            timerSubHint: critical
                ? (isDuelist ? '即将超时 · 等待对手' : '即将超时 · 等待双方换备')
                : '本地计时 · 仅供参考',
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 左栏是「我自己的卡组」快照：观战者本地没有卡组，
                // sidingSnapshot 要么是空的要么是残留，展示出来既错又与
                // 底栏「不展示卡组细节」自相矛盾，整栏换成中性说明。
                Expanded(
                  flex: 9,
                  child: isDuelist ? _snapshotColumn() : _spectatorColumn(),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 10, child: _waitingColumn(oppName)),
              ],
            ),
          ),
        ),
        _bottomBar(),
      ],
    );
  }

  /// 左栏：换备后卡组快照。
  Widget _snapshotColumn() {
    final snapshot = room.sidingSnapshot ?? room.sidingDeck;
    final baseline = room.sidingBaseline;
    final swaps = room.sidingSwapList;
    final mainCount = snapshot?.main.length ?? 0;
    final extraCount = snapshot?.extra.length ?? 0;
    final sideCount = snapshot?.side.length ?? 0;
    final deckName = room.selectedDeckName ?? '当前卡组';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SideSectionLabel(label: 'DECK SNAPSHOT · 换备后卡组'),
        const SizedBox(height: 2),
        Expanded(
          child: SideZoneBox(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SideText(
                            deckName,
                            size: 10,
                            color: CyberSideTokens.textPrimary,
                            weight: FontWeight.w500,
                          ),
                          const SizedBox(height: 4),
                          SideText(
                            'MAIN $mainCount · EXTRA $extraCount · SIDE $sideCount',
                            size: CyberSideTokens.fsSmall,
                            color: CyberSideTokens.textSecondary,
                            mono: true,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SideText(
                          '禁限表校验',
                          size: CyberSideTokens.fsSmall,
                          color: CyberSideTokens.textSecondary,
                        ),
                        const SizedBox(height: 2),
                        const SideText(
                          '通过',
                          size: 8,
                          color: CyberSideTokens.heal,
                          weight: FontWeight.w700,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: CyberSideTokens.rule),
                const SizedBox(height: 8),
                const SideText(
                  '已生效换牌',
                  size: CyberSideTokens.fsSmall,
                  color: CyberSideTokens.textSecondary,
                ),
                const SizedBox(height: 6),
                for (final e in swaps.inCards)
                  _swapLine(
                    '＋ ${_codeName(e.code)} ×${e.count}',
                    CyberSideTokens.heal,
                  ),
                for (final e in swaps.outCards)
                  _swapLine(
                    '－ ${_codeName(e.code)} ×${e.count}',
                    CyberSideTokens.danger,
                  ),
                if (swaps.inCards.isEmpty && swaps.outCards.isEmpty)
                  const SideText(
                    '本局未调整卡组',
                    size: CyberSideTokens.fsBody,
                    color: CyberSideTokens.textDim,
                  ),
                const SizedBox(height: 8),
                Container(height: 1, color: CyberSideTokens.rule),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SideText(
                      '副卡组留存 ${_baselineSideRemaining()} 张',
                      size: CyberSideTokens.fsSmall,
                      color: CyberSideTokens.textSecondary,
                    ),
                    const Spacer(),
                    SideText(
                      '$sideCount 张',
                      size: CyberSideTokens.fsSmall,
                      color: CyberSideTokens.cyan,
                      mono: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 30,
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: CyberSideTokens.barBg,
                    border: Border.all(color: CyberSideTokens.rule),
                    borderRadius: BorderRadius.circular(CyberSideTokens.radius),
                  ),
                  child: SideText(
                    '$sideCount 张仍在副卡组，下一局仍可换回',
                    size: CyberSideTokens.fsSmall,
                    color: CyberSideTokens.textDim,
                  ),
                ),
                const Spacer(),
                // 换备后主卡组缩略（等宽小格，仅示意构成，不可点击）。
                const SideText(
                  '换备后主卡组预览',
                  size: CyberSideTokens.fsMicro,
                  color: CyberSideTokens.textDim,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 18,
                  child: Row(
                    children: [
                      for (var i = 0; i < 9; i++) ...[
                        Container(
                          width: 12,
                          height: 16,
                          decoration: BoxDecoration(
                            color: CyberSideTokens.cardMainBg,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      const SizedBox(width: 6),
                      const Expanded(
                        child: SideText(
                          '等宽预览 · 仅示意构成',
                          size: CyberSideTokens.fsMicro,
                          color: CyberSideTokens.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                if (baseline == null) const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 观战者左栏：不展示任意一方的卡组细节（那是决斗者隐私，而且本地
  /// 根本没有这份数据），只交代「在等什么、什么时候走」。
  Widget _spectatorColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SideSectionLabel(label: 'SPECTATOR · 观战视角'),
        const SizedBox(height: 2),
        Expanded(
          child: SideZoneBox(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SideText(
                  '双方正在换备',
                  size: 12,
                  color: CyberSideTokens.textPrimary,
                  weight: FontWeight.w600,
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: CyberSideTokens.rule),
                const SizedBox(height: 10),
                const SideText(
                  '换备阶段的卡组明细与换牌清单不对观战者公开。',
                  size: CyberSideTokens.fsBody,
                  color: CyberSideTokens.textSecondary,
                ),
                const SizedBox(height: 8),
                const SideText(
                  '双方提交后由服务端整包校验，通过即载入下一局。',
                  size: CyberSideTokens.fsBody,
                  color: CyberSideTokens.textSecondary,
                ),
                const SizedBox(height: 8),
                const SideText(
                  '观战期间无需任何操作，页面会自动跟随阶段切换。',
                  size: CyberSideTokens.fsBody,
                  color: CyberSideTokens.textDim,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _baselineSideRemaining() => room.sidingSnapshot?.side.length ?? 0;

  Widget _swapLine(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: SideText(text, size: CyberSideTokens.fsBody, color: color),
  );

  /// 右栏：就绪圈 + 对手状态 + 本机估算进度。
  Widget _waitingColumn(String opponentName) {
    final oppReady = room.isOpponentReady;
    // 观战者不是「我」，右栏标题与「已提交」徽标都要中性化。
    final isDuelist = room.selfType.isDuelist;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SideSectionLabel(
          label: isDuelist ? 'WAITING · 等待对手' : 'WAITING · 换备进行中',
        ),
        const SizedBox(height: 2),
        Expanded(
          child: SideZoneBox(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                // 就绪圈：外圈暗、内圈青绿 + 对钩。
                SizedBox(
                  width: 88,
                  height: 88,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: CyberSideTokens.cardMainBg),
                        ),
                      ),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: const Color(0xFF07141A),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CyberSideTokens.heal,
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: SideText(
                            '✓',
                            size: 20,
                            color: CyberSideTokens.heal,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SideText(
                  // 观战者没有提交卡组这个动作。
                  isDuelist ? '已提交' : '换备中',
                  size: CyberSideTokens.fsSmall,
                  color: CyberSideTokens.heal,
                ),
                const SizedBox(height: 18),
                SideText(
                  oppReady
                      ? '$opponentName 已就绪'
                      : (isDuelist ? '对手换备中…' : '$opponentName 换备中…'),
                  size: 11,
                  color: CyberSideTokens.textPrimary,
                  weight: FontWeight.w500,
                ),
                const SizedBox(height: 4),
                SideText(
                  oppReady ? '双方已提交，等待服务端下发下一局' : '$opponentName 仍在换备，具体张数不可见',
                  size: CyberSideTokens.fsSmall,
                  color: CyberSideTokens.textSecondary,
                ),
                const SizedBox(height: 16),
                // 本机估算进度条：服务端不下发换备倒计时，这条只是心理安慰。
                SizedBox(
                  width: 336,
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        decoration: const BoxDecoration(
                          color: CyberSideTokens.rule,
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: oppReady ? 1.0 : 0.36,
                          child: Container(color: CyberSideTokens.danger),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const SideText(
                        '服务端不下发换备倒计时，进度条仅为本机估算',
                        size: CyberSideTokens.fsSmall,
                        color: CyberSideTokens.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: CyberSideTokens.rule),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SideText(
                      isDuelist ? '等待中可做' : '观战中',
                      size: CyberSideTokens.fsSmall,
                      color: CyberSideTokens.textDim,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SideText(
                        isDuelist
                            ? '回顾上一局、查看本局卡组快照；等对手期间不能再改卡组'
                            : '换备完成后自动进入下一局载入，观战期间无需任何操作',
                        size: CyberSideTokens.fsSmall,
                        color: CyberSideTokens.cyan,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    // 观战者没有可提交的卡组，「重新提交 / 已提交」对他不成立，只留说明。
    final isDuelist = room.selfType.isDuelist;
    return Container(
      height: CyberSideTokens.bottomBarHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: CyberSideTokens.pagePadding,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CyberSideTokens.rule)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SideText(
              isDuelist
                  ? '双方提交后服务端逐包校验，通过则进入下一局载入；失败回退到本页。'
                  : '双方正在换备，观战视角下不展示卡组细节与提交操作。',
              size: CyberSideTokens.fsBody,
              color: CyberSideTokens.textDim,
            ),
          ),
          const SizedBox(width: 16),
          if (isDuelist) ...[
            SideButton(
              key: const ValueKey('side-waiting-resubmit'),
              label: '重新提交',
              onPressed: onResubmit,
            ),
            const SizedBox(width: 8),
            SideButton(
              key: const ValueKey('side-waiting-done'),
              label: '已提交 · 等待',
              filled: true,
              accent: CyberSideTokens.heal,
              onPressed: onCancelEdit,
            ),
          ],
        ],
      ),
    );
  }

  String _codeName(int code) {
    for (final c in [
      ...?room.sidingSnapshot?.main,
      ...?room.sidingSnapshot?.extra,
      ...?room.sidingSnapshot?.side,
      ...?room.sidingBaseline?.main,
      ...?room.sidingBaseline?.side,
    ]) {
      if (c.code == code) {
        return c.name.isNotEmpty ? c.name : '${c.code}';
      }
    }
    return '卡片 $code';
  }
}
