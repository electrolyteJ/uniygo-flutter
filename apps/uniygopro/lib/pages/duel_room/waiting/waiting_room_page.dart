import 'package:duelink/duelink.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:ygo_card/lf_table.dart';

import '../../../widgets/waiting_room/chat_panel.dart';
import '../../../widgets/waiting_room/control_bar.dart';
import '../../../widgets/waiting_room/hand_result_display.dart';
import '../../../widgets/waiting_room/player_panel.dart';
import '../../../widgets/waiting_room/room_info_panel.dart';
import '../duel_room_store.dart';

class WaitingRoomPage extends StatefulWidget {
  const WaitingRoomPage({super.key});

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  late DisplayStyle _displayStyle;

  @override
  void initState() {
    super.initState();
    _displayStyle = DisplayStyle.card;
  }

  @override
  Widget build(BuildContext context) {
    final duelRoomStore = context.watch<DuelRoomStore>();
    final opts = duelRoomStore.roomOptions;
    final mySlotVal = duelRoomStore.selfType.slot;
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
                    if (opts != null)
                      FutureBuilder<LfTable?>(
                        future: duelRoomStore.getLfTable(opts.lfTableHash),
                        builder: (context, snapshot) {
                          return RoomInfoPanel(
                            opts: opts,
                            lfTable: snapshot.data,
                          );
                        },
                      ),
                    Expanded(child: ChatPanel()),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_displayStyle == DisplayStyle.statusBar &&
            (duelRoomStore.stage is RoomSelectingHand ||
                duelRoomStore.stage is RoomHandResult ||
                duelRoomStore.stage is RoomSelectingTurn)) ...[
          _buildStatusBarResult(duelRoomStore),
        ],
        ControlBar(
          isHost: duelRoomStore.isHost,
          selfType: duelRoomStore.selfType,
          isSelfReady: duelRoomStore.isSelfReady,
          displayStyle: _displayStyle,
          onToggleDisplay: () {
            setState(() {
              _displayStyle = _displayStyle == DisplayStyle.card
                  ? DisplayStyle.statusBar
                  : DisplayStyle.card;
            });
          },
          autoHandEnabled: duelRoomStore.autoHandEnabled,
          autoTurnOrderEnabled: duelRoomStore.autoTurnOrderEnabled,
          toggleReady: duelRoomStore.toggleReady,
          onToggleAutoHand: duelRoomStore.setAutoHandEnabled,
          onToggleAutoTurnOrder: duelRoomStore.setAutoTurnOrderEnabled,
          onStartDuel: duelRoomStore.startDuel,
          onBecomeDuelist: duelRoomStore.becomeDuelist,
          onBecomeObserver: duelRoomStore.becomeObserver,
        ),
      ],
    );
  }
}

Widget _buildStatusBarResult(DuelRoomStore duelRoomStore) {
  final myName = duelRoomStore.selfPlayer?.name ?? '我';
  final opSlot = duelRoomStore.selfType.slot == 0 ? 1 : 0;
  final opPlayer = duelRoomStore.players
      .where((p) => p.pos == opSlot)
      .toList();
  final opName = opPlayer.isNotEmpty ? opPlayer.first.name : '对手';

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: HandResultDisplay(
      myHandResult: duelRoomStore.myHandResult,
      opponentHandResult: duelRoomStore.opponentHandResult,
      isFirstTurn: duelRoomStore.isFirstTurn,
      stage: duelRoomStore.stage,
      style: DisplayStyle.statusBar,
      myName: myName,
      opponentName: opName,
    ),
  );
}
