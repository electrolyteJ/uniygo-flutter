import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:ygo_data/lf_table.dart';

import '../../../widgets/waiting_room/chat_panel.dart';
import '../../../widgets/waiting_room/control_bar.dart';
import '../../../widgets/waiting_room/player_panel.dart';
import '../../../widgets/waiting_room/room_info_panel.dart';
import '../duel_room_store.dart';

class WaitingRoomPage extends StatefulWidget {
  const WaitingRoomPage({super.key});

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {

  @override
  void initState() {
    super.initState();
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
        ControlBar(
          isHost: duelRoomStore.isHost,
          selfType: duelRoomStore.selfType,
          isSelfReady: duelRoomStore.isSelfReady,
          isAllReady: duelRoomStore.isAllReady,
          autoHandEnabled: duelRoomStore.autoHandEnabled,
          autoTurnOrderEnabled: duelRoomStore.autoTurnOrderEnabled,
          autoDuelEnabled: duelRoomStore.autoDuelEnabled,
          toggleReady: duelRoomStore.toggleReady,
          onToggleAutoHand: duelRoomStore.setAutoHandEnabled,
          onToggleAutoTurnOrder: duelRoomStore.setAutoTurnOrderEnabled,
          onToggleAutoDuel: duelRoomStore.setAutoDuelEnabled,
          onStartDuel: duelRoomStore.startDuel,
          onBecomeDuelist: duelRoomStore.becomeDuelist,
          onBecomeObserver: duelRoomStore.becomeObserver,
        ),
      ],
    );
  }
}