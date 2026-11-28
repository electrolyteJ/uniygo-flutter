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
import 'widgets/hand_button.dart';
import 'widgets/hand_circle.dart';

/// 猜拳页（RoomSelectingHand / RoomHandResult）：只有阶段内容与倒计时。
class HandPage3D extends ConsumerWidget {
  const HandPage3D({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(duelRoomProvider);
    final stage = room.stage;
    // 观战者没有出拳动作，进度条暗示的「到点自动出拳」对他不成立。
    final showProgress =
        room.selfType.isDuelist &&
        stage is RoomSelectingHand &&
        !room.autoHandEnabled;
    Widget content = const SizedBox.shrink();
    if (stage is RoomSelectingHand) {
      content = _buildRps(room, ref);
    } else if (stage is RoomHandResult) {
      content = _buildResult(room, stage);
    }
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

  Widget _buildRps(DuelRoomState room, WidgetRef ref) {
    final notifier = ref.read(duelRoomProvider.notifier);
    final chosen = room.myHandResult != null;
    // 观战者不能出拳：隐藏按钮（不然点了会向服务端发一个非法动作），
    // 「你 / 对手」「已出拳，等待对方」也都说不通，改用 M1 / M2 指代。
    final isDuelist = room.selfType.isDuelist;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 300;
        final handSize = compact ? 60.0 : 84.0;
        final btnW = compact ? 58.0 : 72.0;
        final btnH = compact ? 48.0 : 64.0;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('猜拳 · 决定先后攻', style: HudTheme.title),
              SizedBox(height: compact ? 6 : 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      HandCircle(size: handSize, highlight: true),
                      const SizedBox(height: 6),
                      Text(
                        isDuelist ? '你' : '1 号位',
                        style: HudTheme.caption.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                  SizedBox(width: compact ? 16 : 28),
                  Column(
                    children: [
                      HandCircle(size: handSize),
                      const SizedBox(height: 6),
                      Text(
                        isDuelist ? '对手' : '2 号位',
                        style: HudTheme.caption.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: compact ? 6 : 16),
              if (isDuelist) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HandButton(
                      width: btnW,
                      height: btnH,
                      icon: Icons.circle_outlined,
                      label: '石头',
                      enabled: !chosen,
                      onTap: () => notifier.sendHand(HandType.rock),
                    ),
                    const SizedBox(width: 10),
                    HandButton(
                      width: btnW,
                      height: btnH,
                      icon: Icons.content_cut,
                      label: '剪刀',
                      enabled: !chosen,
                      onTap: () => notifier.sendHand(HandType.scissors),
                    ),
                    const SizedBox(width: 10),
                    HandButton(
                      width: btnW,
                      height: btnH,
                      icon: Icons.back_hand_outlined,
                      label: '布',
                      enabled: !chosen,
                      onTap: () => notifier.sendHand(HandType.paper),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 8 : 12),
                Text(
                  chosen ? '已出拳，等待对方…' : '双方选择中 · 倒计时结束后自动出拳',
                  style: HudTheme.caption.copyWith(
                    fontSize: 9,
                    color: chosen ? duelHeal : duelCyan,
                  ),
                ),
              ] else
                Text(
                  '双方出拳中 · 倒计时结束后自动判定',
                  style: HudTheme.caption.copyWith(
                    fontSize: 9,
                    color: duelCyan,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResult(DuelRoomState room, RoomHandResult result) {
    final outcome = rpsOutcome(result.myHand, result.opponentHand);
    // 观战者没有立场：不判「你胜出 / 对手胜出」，只报平局或「n 号位胜出」。
    final isDuelist = room.selfType.isDuelist;
    final title = switch (outcome) {
      1 => isDuelist ? '你胜出' : '1 号位胜出',
      -1 => isDuelist ? '对手胜出' : '2 号位胜出',
      _ => '平局 · 重新出拳',
    };
    final color = switch (outcome) {
      1 => duelHeal,
      -1 => duelDanger,
      _ => duelSub,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 300;
        final handSize = compact ? 60.0 : 84.0;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('出拳结果', style: HudTheme.title),
              SizedBox(height: compact ? 10 : 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      HandCircle(
                        size: handSize,
                        hand: result.myHand,
                        highlight: outcome == 1,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${isDuelist ? '你' : '1 号位'} · '
                        '${_handName(result.myHand)}',
                        style: HudTheme.caption.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                  SizedBox(width: compact ? 16 : 28),
                  Column(
                    children: [
                      HandCircle(
                        size: handSize,
                        hand: result.opponentHand,
                        highlight: outcome == -1,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${isDuelist ? '对手' : '2 号位'} · '
                        '${_handName(result.opponentHand)}',
                        style: HudTheme.caption.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: compact ? 10 : 16),
              Text(
                title,
                style: HudTheme.title.copyWith(color: color, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                outcome == 0 ? '平局后重新猜拳' : '${outcome == 1 ? '1' : '2'} 号位优先选择',
                style: HudTheme.caption.copyWith(fontSize: 9),
              ),
            ],
          ),
        );
      },
    );
  }

  String _handName(int hand) => switch (hand) {
    1 => '剪刀',
    2 => '石头',
    3 => '布',
    _ => '—',
  };
}
