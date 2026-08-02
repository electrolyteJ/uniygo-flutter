import 'package:flutter/material.dart';
import 'package:duelink/duelink.dart';
import 'package:provider/provider.dart';
import '../../stores/waiting_room_store.dart';
import 'hand_result_display.dart';
import 'playerslot.dart';
import 'select_hand.dart';
import 'select_turn.dart';
import 'deck_selector.dart';

class PlayerPanel extends StatelessWidget {
  final int mySlot;
  final DisplayStyle displayStyle;

  const PlayerPanel({
    super.key,
    required this.mySlot,
    required this.displayStyle,
  });

  @override
  Widget build(BuildContext context) {
    final waitingRoomStore = context.watch<WaitingRoomStore>();
    final showCardResults =
        displayStyle == DisplayStyle.card &&
        (waitingRoomStore.stage is RoomSelectingHand ||
            waitingRoomStore.stage is RoomHandResult ||
            waitingRoomStore.stage is RoomSelectingTurn);
    return Container(
      color: Colors.blueGrey.shade800,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '玩家',
            style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
          ),
          ...waitingRoomStore.players.map(
            (item) => Container(
              margin: EdgeInsets.only(top: 8),
              child: PlayerSlot(
                player: item,
                placeholder: '玩家 ${item.pos + 1}',
                handResult: item.pos == mySlot
                    ? waitingRoomStore.myHandResult
                    : waitingRoomStore.opponentHandResult,
                showResult: showCardResults,
                isHostSlot: item.pos == mySlot
                    ? waitingRoomStore.isHost
                    : (waitingRoomStore.isHost ? false : true),
                isMe: item.pos == mySlot,
                canKick:
                    !(item.pos == mySlot
                        ? waitingRoomStore.isHost
                        : (waitingRoomStore.isHost ? false : true)) &&
                    item.pos != mySlot,
                onKick: () => waitingRoomStore.kickPlayer(item.pos),
                displayStyle: displayStyle,
              ),
            ),
          ),
          const SizedBox(height: 12),
          DeckSelector(waitingRoomStore: waitingRoomStore, mySlot: mySlot),
          const SizedBox(height: 12),
          if (waitingRoomStore.stage is RoomSelectingHand)
            HandSelect(
              onSendHand: waitingRoomStore.sendHand,
              enabled: !waitingRoomStore.autoHandEnabled,
            ),
          if (waitingRoomStore.stage is RoomSelectingTurn)
            TpSelect(
              onSendTp: waitingRoomStore.sendTp,
              enabled: !waitingRoomStore.autoTurnOrderEnabled,
            ),
          const SizedBox(height: 12),
          Divider(color: Colors.blueGrey.shade600, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.visibility, size: 16, color: Colors.blueGrey.shade400),
              const SizedBox(width: 6),
              Text(
                '观战: ${waitingRoomStore.observerCount}人',
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
