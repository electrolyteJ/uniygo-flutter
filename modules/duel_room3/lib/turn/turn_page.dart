import 'dart:math' as math;

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duel_room3/util/util.dart';
import 'package:duelink/duelink.dart' hide CardInfo, ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lobby/widgets/player_card.dart';
import '../theme/duel_style.dart';
import '../theme/hud_theme.dart';
import '../widgets/phase_status_bar.dart';
import '../widgets/player_seats.dart';
import '../widgets/duel_backdrop.dart';
import 'widgets/turn_button.dart';

/// 选择先后攻页（RoomSelectingTurn）：只有阶段内容与倒计时。
class TurnPage3D extends ConsumerWidget {
  const TurnPage3D({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(duelRoomProvider);
    final stage = room.stage;
    final inTurn = stage is RoomSelectingTurn;
    // 进度条只在「轮到我选」时出现：它表达的是 10s 兜底倒计时，
    // 等对手时毫无意义（对手超时也轮不到我动），反而误导玩家。
    final mine = room.myHandResult;
    final other = room.opponentHandResult;
    final iLost =
        mine != null && other != null && rpsOutcome(mine, other) == -1;
    // 观战者没有选攻动作，进度条暗示的「10s 兜底自动选」对他不成立。
    final showProgress =
        room.selfType.isDuelist &&
        inTurn &&
        !iLost &&
        !room.autoTurnOrderEnabled;
    final content = inTurn ? _buildTurn(room, ref) : const SizedBox.shrink();
    final seats = PlayerSeats.of(room);
    final size = MediaQuery.sizeOf(context);
    final k = (math.min(size.width / 844, size.height / 390)).clamp(0.85, 2.4);
    return DuelRoomBackdrop(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(k)),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Row(
                  children: [
                    SizedBox(
                      width: 190 * k,
                      child: PlayerCard(
                        room: room,
                        roomId: room.roomId,
                        seats: seats.left,
                        isAlly: true,
                        selfSlot: seats.selfSeat,
                        showDeckActions: false,
                        onChangeDeck: () {},
                        onEditDeck: () {},
                        onShowDeckCheck: () {},
                        onInvite: () {},
                      ),
                    ),
                    SizedBox(width: 12 * k),
                    Expanded(child: Center(child: content)),
                    SizedBox(width: 12 * k),
                    SizedBox(
                      width: 190 * k,
                      child: PlayerCard(
                        room: room,
                        roomId: room.roomId,
                        seats: seats.right,
                        isAlly: false,
                        selfSlot: seats.selfSeat,
                        showDeckActions: false,
                        onChangeDeck: () {},
                        onEditDeck: () {},
                        onShowDeckCheck: () {},
                        onInvite: () {},
                      ),
                    ),
                  ],
                ),
              ),
              if (showProgress)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: WaitingPhaseStatusBar(room: room, stage: stage),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTurn(DuelRoomState room, WidgetRef ref) {
    final notifier = ref.read(duelRoomProvider.notifier);
    // 观战者不能选先后攻：没有按钮可点，文案也不能说「你」。
    final isDuelist = room.selfType.isDuelist;
    final mine = room.myHandResult;
    final other = room.opponentHandResult;
    // 猜拳输了 → 先后攻由对手决定，我只能等。
    final iLost =
        mine != null && other != null && rpsOutcome(mine, other) == -1;
    // 只在「我输了」时等待。**不要**再用 `isFirstTurn != null` 兜底：
    // 那是上一局残留的值，会让第二局的两个按钮永久禁用（match 换备后卡死）。
    final waiting = iLost;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 300;
        final btnW = compact ? 84.0 : 104.0;
        final btnH = compact ? 56.0 : 68.0;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDuelist)
                // 三段：对手已选定 → 告知结果；我输了在等 → 等待；我可以选。
                Text(
                  iLost && room.isFirstTurn != null
                      ? (room.isFirstTurn!
                            ? '对手选择了先攻 · 你为后攻'
                            : '对手选择了后攻 · 你为先攻')
                      : (waiting ? '等待对手选择先后攻' : '猜拳胜出 · 你先选'),
                  style: HudTheme.title.copyWith(
                    color: waiting ? duelTextColor : duelCyan,
                  ),
                )
              else
                // 观战者只说「谁在选择」，不预告「你」是先后攻。
                Text(
                  room.isFirstTurn == null
                      ? '等待胜出方选择先后攻'
                      : (room.isFirstTurn!
                            ? '胜出方选择了先攻 · 先手开局'
                            : '胜出方选择了后攻 · 后手开局'),
                  style: HudTheme.title.copyWith(
                    color: room.isFirstTurn == null ? duelTextColor : duelCyan,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                isDuelist
                    ? (waiting ? '对手正在选择先攻或后攻' : '选择先攻或后攻，进入决斗场地')
                    : (room.isFirstTurn == null
                          ? '观战中 · 等待胜出方决定'
                          : '观战中 · 先攻方即将开始回合'),
                style: HudTheme.caption.copyWith(fontSize: 9),
              ),
              if (isDuelist) ...[
                SizedBox(height: compact ? 12 : 18),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TurnButton(
                      width: btnW,
                      height: btnH,
                      label: '先攻',
                      caption: waiting ? '等待中' : '先手开局',
                      enabled: !waiting,
                      onTap: () => notifier.sendTp(true),
                    ),
                    const SizedBox(width: 12),
                    TurnButton(
                      width: btnW,
                      height: btnH,
                      label: '后攻',
                      caption: waiting ? '等待中' : '后手开局',
                      enabled: !waiting,
                      onTap: () => notifier.sendTp(false),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 8 : 12),
                Text(
                  waiting ? '对手正在选择…' : '选择后等待对手确认',
                  style: HudTheme.caption.copyWith(
                    fontSize: 9,
                    color: waiting ? duelSub : duelCyan,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
