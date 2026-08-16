import 'dart:ui';

import 'package:duelink/duelink.dart' show PlayerInfo;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../duel_field_state.dart';
import '../../../duel_room_exit.dart';
import 'phase_bar.dart';
import 'player_status_card.dart';

/// 顶部 HUD：返回按钮 + 双方 PlayerStatusCard + PhaseBar。
///
/// 玩家名从 [players] 解析，其余字段直连 [duelFieldProvider]；打开区域
/// 浏览器（墓地/除外/额外）与退出决斗分别经 [onOpenZoneBrowser] /
/// backHomeDialog 处理。
class DuelFieldHud extends ConsumerWidget {
  const DuelFieldHud({
    super.key,
    required this.players,
    required this.isMyTurn,
    required this.onOpenZoneBrowser,
  });

  final List<PlayerInfo> players;
  final bool isMyTurn;
  final void Function(String zoneKey) onOpenZoneBrowser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(duelFieldProvider);
    final mc = board.myController;
    final selfName =
        players.where((p) => p.pos == mc).map((p) => p.name).firstOrNull ??
        '我方';
    final oppName =
        players.where((p) => p.pos == 1 - mc).map((p) => p.name).firstOrNull ??
        '对方';
    final turnTimeLeft = board.currentPlayer == mc
        ? board.selfTimeLeft
        : board.opponentTimeLeft;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _hudIconButton(
              icon: Icons.arrow_back,
              onPressed: () {
                backHomeDialog(
                  context: context,
                  ref: ref,
                  title: '退出决斗',
                  content: '是否确认退出当前决斗？',
                );
              },
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerStatusCard(
                      name: oppName,
                      lp: board.opponentLp,
                      lpDelta: board.opponentLpDelta,
                      lpEventId: board.opponentLpEventId,
                      isSelf: false,
                      isActiveTurn: !isMyTurn,
                      handCount: board.opponentHand.length,
                      deckCount: board.oppDeck,
                      extraCount: board.oppExtra,
                      graveCount: board.oppGrave,
                      removedCount: board.oppRemoved,
                      onExtraTap: () => onOpenZoneBrowser('opp_extra'),
                      onGraveTap: () => onOpenZoneBrowser('opp_grave'),
                      onRemovedTap: () => onOpenZoneBrowser('opp_removed'),
                    ),
                    const SizedBox(width: 16),
                    PhaseBar(
                      turnCount: board.turnCount,
                      isMyTurn: isMyTurn,
                      leftTimeSeconds: turnTimeLeft,
                    ),
                    const SizedBox(width: 16),
                    PlayerStatusCard(
                      name: selfName,
                      lp: board.selfLp,
                      lpDelta: board.selfLpDelta,
                      lpEventId: board.selfLpEventId,
                      isSelf: true,
                      isActiveTurn: isMyTurn,
                      handCount: board.selfHand.length,
                      deckCount: board.selfDeck,
                      extraCount: board.selfExtra,
                      graveCount: board.selfGrave,
                      removedCount: board.selfRemoved,
                      onExtraTap: () => onOpenZoneBrowser('self_extra'),
                      onGraveTap: () => onOpenZoneBrowser('self_grave'),
                      onRemovedTap: () => onOpenZoneBrowser('self_removed'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hudIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xB8060B14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x3300F0FF), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x1A00F0FF), blurRadius: 24),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white.withValues(alpha: 0.92)),
            tooltip: '返回',
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
