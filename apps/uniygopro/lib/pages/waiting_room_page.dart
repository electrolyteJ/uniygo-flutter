import 'package:duelink/duelink.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../stores/duel_chat_store.dart';
import '../stores/waiting_room_store.dart';
import '../stores/match_store.dart';
import '../widgets/waiting_room/chat_panel.dart';
import '../widgets/waiting_room/control_bar.dart';
import '../widgets/waiting_room/hand_result_display.dart';
import '../widgets/waiting_room/player_panel.dart';
import '../widgets/waiting_room/room_info_panel.dart';

class WaitingRoomPage extends StatefulWidget {
  final MatchStore match;
  final DisplayStyle _displayStyle = DisplayStyle.card;
  final void Function(HandType) onSendHand;
  final void Function(bool) onSendTp;
  final void Function(int) onKick;
  final TextEditingController chatCtrl;
  final ScrollController chatScrollCtrl;
  final VoidCallback onSend;
  final VoidCallback onSwitchToObserver;
  final VoidCallback onSwitchToDuelist;
  final VoidCallback onStart;
  final ValueChanged<bool> onToggleAutoHand;
  final ValueChanged<bool> onToggleAutoTurnOrder;

  const WaitingRoomPage({
    super.key,
    required this.match,
    required this.onSendHand,
    required this.onSendTp,
    required this.onKick,
    required this.chatCtrl,
    required this.chatScrollCtrl,
    required this.onSend,
    required this.onSwitchToObserver,
    required this.onSwitchToDuelist,
    required this.onStart,
    required this.onToggleAutoHand,
    required this.onToggleAutoTurnOrder,
  });

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  late final WaitingRoomStore waitingRoomStore;
  late final DuelChatStore chatState;

  @override
  void initState() {
    super.initState();
    waitingRoomStore = context.read<WaitingRoomStore>();
    chatState = context.read<DuelChatStore>();
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final onSendHand = widget.onSendHand;
    final onSendTp = widget.onSendTp;
    final onKick = widget.onKick;
    final chatCtrl = widget.chatCtrl;
    final chatScrollCtrl = widget.chatScrollCtrl;
    final onSend = widget.onSend;
    final onSwitchToObserver = widget.onSwitchToObserver;
    final onSwitchToDuelist = widget.onSwitchToDuelist;
    final onStart = widget.onStart;
    final onToggleAutoHand = widget.onToggleAutoHand;
    final onToggleAutoTurnOrder = widget.onToggleAutoTurnOrder;
    final _displayStyle = widget._displayStyle;
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
                  waitingRoomStore: waitingRoomStore,
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
                        chatState: chatState,
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
            (waitingRoomStore.stage is RoomSelectingHand ||
                waitingRoomStore.stage is RoomHandResult ||
                waitingRoomStore.stage is RoomSelectingTurn)) ...[
          _buildStatusBarResult(waitingRoomStore),
        ],
        ControlBar(
          waitingRoomStore: waitingRoomStore,
          mySlot: mySlotVal,
          isPlayer: isPlayer,
          isReady: isReady,
          onToggleReady: () => waitingRoomStore.toggleReady(context, mounted),
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
          onToggleAutoHand: onToggleAutoHand,
          onToggleAutoTurnOrder: (value) => onToggleAutoTurnOrder(value),
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
