import 'package:duelink/duelink.dart';
import 'package:flutter/cupertino.dart';

import '../stores/duel_room_state.dart';
import '../stores/match_store.dart';
import '../widgets/waiting_room/chat_panel.dart';
import '../widgets/waiting_room/control_bar.dart';
import '../widgets/waiting_room/hand_result_display.dart';
import '../widgets/waiting_room/player_panel.dart';
import '../widgets/waiting_room/room_info_panel.dart';

class WaitingRoomPage extends StatelessWidget {
  final DuelRoomState state;
  final MatchStore match;
  final DisplayStyle _displayStyle = DisplayStyle.card;
  final void Function(HandType) onSendHand;
  final void Function(bool) onSendTp;
  final void Function(int) onKick;
  final TextEditingController chatCtrl;
  final ScrollController chatScrollCtrl;
  final VoidCallback onSend;
  final VoidCallback onToggleReady;
  final VoidCallback onSwitchToObserver;
  final VoidCallback onSwitchToDuelist;
  final VoidCallback onStart;

  WaitingRoomPage({
    super.key,
    required this.state,
    required this.match,
    required this.onSendHand,
    required this.onSendTp,
    required this.onKick,
    required this.chatCtrl,
    required this.chatScrollCtrl,
    required this.onSend,
    required this.onToggleReady,
    required this.onSwitchToObserver,
    required this.onSwitchToDuelist,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final opts = state.roomOptions;
    final mySlotVal = state.selfType.slot;
    final isPlayer = mySlotVal >= 0 && mySlotVal <= 1;
    final isReady =
        isPlayer &&
        state.players.where((p) => p.pos == mySlotVal).any((p) => p.ready);

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PlayerPanel(
                  state: state,
                  match: match,
                  mySlot: mySlotVal,
                  onSendHand: onSendHand,
                  onSendTp: onSendTp,
                  onKick: onKick,
                  displayStyle: _displayStyle,
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    if (opts != null) RoomInfoPanel(opts: opts),
                    Expanded(
                      child: ChatPanel(
                        state: state,
                        chatCtrl: chatCtrl,
                        chatScrollCtrl: chatScrollCtrl,
                        onSend: onSend,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_displayStyle == DisplayStyle.statusBar &&
            (state.stage is RoomSelectingHand ||
                state.stage is RoomHandResult ||
                state.stage is RoomSelectingTurn)) ...[
          _buildStatusBarResult(state),
        ],
        ControlBar(
          state: state,
          mySlot: mySlotVal,
          isPlayer: isPlayer,
          isReady: isReady,
          onToggleReady: onToggleReady,
          onSwitchToObserver: onSwitchToObserver,
          onSwitchToDuelist: onSwitchToDuelist,
          onStart: onStart,
          onToggleDisplay: () {
            // setState(() {
            //   _displayStyle = _displayStyle == DisplayStyle.card
            //       ? DisplayStyle.statusBar
            //       : DisplayStyle.card;
            // });
          },
          displayStyle: _displayStyle,
          onToggleAutoHand: (value) => state.setAutoHandEnabled(value),
          onToggleAutoTurnOrder: (value) =>
              state.setAutoTurnOrderEnabled(value),
        ),
      ],
    );
  }
}

Widget _buildStatusBarResult(DuelRoomState state) {
  final mySlotVal = state.selfType.slot;
  final myPlayer = state.players.where((p) => p.pos == mySlotVal).toList();
  final myName = myPlayer.isNotEmpty ? myPlayer.first.name : '我';

  final opSlot = mySlotVal == 0 ? 1 : 0;
  final opPlayer = state.players.where((p) => p.pos == opSlot).toList();
  final opName = opPlayer.isNotEmpty ? opPlayer.first.name : '对手';

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: HandResultDisplay(
      myHandResult: state.myHandResult,
      opponentHandResult: state.opponentHandResult,
      isFirstTurn: state.isFirstTurn,
      stage: state.stage,
      style: DisplayStyle.statusBar,
      myName: myName,
      opponentName: opName,
    ),
  );
}
