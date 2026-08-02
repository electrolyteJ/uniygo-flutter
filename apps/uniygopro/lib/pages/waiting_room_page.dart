import 'package:duelink/duelink.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../stores/waiting_room_store.dart';
import '../widgets/waiting_room/chat_panel.dart';
import '../widgets/waiting_room/control_bar.dart';
import '../widgets/waiting_room/hand_result_display.dart';
import '../widgets/waiting_room/player_panel.dart';
import '../widgets/waiting_room/room_info_panel.dart';

class WaitingRoomPage extends StatefulWidget {
  const WaitingRoomPage({super.key});

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  DisplayStyle _displayStyle = DisplayStyle.card;

  @override
  Widget build(BuildContext context) {
    final waitingRoomStore = context.watch<WaitingRoomStore>();

    final opts = waitingRoomStore.roomOptions;
    final mySlotVal = waitingRoomStore.selfType.slot;
    final isPlayer = mySlotVal >= 0 && mySlotVal <= 1;
    final isReady =
        isPlayer &&
        waitingRoomStore.players
            .where((p) => p.pos == mySlotVal)
            .any((p) => p.ready);
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PlayerPanel(
                  mySlot: mySlotVal,
                  displayStyle: _displayStyle,
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    if (opts != null) RoomInfoPanel(opts: opts),
                    Expanded(child: ChatPanel()),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_displayStyle == DisplayStyle.statusBar &&
            (waitingRoomStore.stage is RoomSelectingHand ||
                waitingRoomStore.stage is RoomHandResult ||
                waitingRoomStore.stage is RoomSelectingTurn)) ...[
          _buildStatusBarResult(waitingRoomStore),
        ],
        ControlBar(
          mySlot: mySlotVal,
          isPlayer: isPlayer,
          isReady: isReady,
          displayStyle: _displayStyle,
          onToggleDisplay: () {
            setState(() {
              _displayStyle = _displayStyle == DisplayStyle.card
                  ? DisplayStyle.statusBar
                  : DisplayStyle.card;
            });
          },
        ),
      ],
    );
  }
}

Widget _buildStatusBarResult(WaitingRoomStore waitingRoomStore) {
  final mySlotVal = waitingRoomStore.selfType.slot;
  final myPlayer = waitingRoomStore.players
      .where((p) => p.pos == mySlotVal)
      .toList();
  final myName = myPlayer.isNotEmpty ? myPlayer.first.name : '我';

  final opSlot = mySlotVal == 0 ? 1 : 0;
  final opPlayer = waitingRoomStore.players
      .where((p) => p.pos == opSlot)
      .toList();
  final opName = opPlayer.isNotEmpty ? opPlayer.first.name : '对手';

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: HandResultDisplay(
      myHandResult: waitingRoomStore.myHandResult,
      opponentHandResult: waitingRoomStore.opponentHandResult,
      isFirstTurn: waitingRoomStore.isFirstTurn,
      stage: waitingRoomStore.stage,
      style: DisplayStyle.statusBar,
      myName: myName,
      opponentName: opName,
    ),
  );
}
