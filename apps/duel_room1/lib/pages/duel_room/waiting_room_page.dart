import 'package:biz/service_singleton.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ygo_data/lf_table.dart';

import '../../widgets/waiting_room/chat_panel.dart';
import '../../widgets/waiting_room/control_bar.dart';
import '../../widgets/waiting_room/player_panel.dart';
import '../../widgets/waiting_room/room_info_panel.dart';
import 'duel_room_store.dart';
import 'duel_chat_store.dart';

class WaitingRoomPage extends StatelessWidget {
  const WaitingRoomPage({super.key});

  void _onToggleAutomation(bool value, ValueChanged<bool> action) {
    final sound = ServiceSingleton.instance.ygoSoundService;
    if (value) {
      sound.playToggleOn();
    } else {
      sound.playToggleOff();
    }
    action(value);
  }

  /// 编辑当前所选卡组：打开卡组编辑器，保存后刷新卡组校验。
  ///
  /// 路由参数用通用 Map 传递（不依赖卡组编辑器的类型）：
  /// `initialDeckName` / `noCheckDeck` / `lfTableHash` /
  /// `lockDeckSelection` / `lockDeckName`；返回值同为 Map，
  /// 含 `saved`（bool）。
  Future<void> _onEditDeck(
    BuildContext context,
    DuelRoomStore duelRoomStore,
  ) async {
    final opts = duelRoomStore.roomOptions;
    final result = await context.push<Map<String, Object?>>(
      '/deck-editor',
      extra: <String, Object?>{
        'initialDeckName': duelRoomStore.selectedDeckName,
        if (opts != null) 'noCheckDeck': opts.noCheckDeck,
        if (opts != null) 'lfTableHash': opts.lfTableHash,
        'lockDeckSelection': true,
        'lockDeckName': true,
      },
    );
    if (context.mounted && (result?['saved'] == true)) {
      await duelRoomStore.refreshSelectedDeckValidation(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duelRoomStore = context.watch<DuelRoomStore>();
    final duelChatStore = context.watch<DuelChatStore>();
    final opts = duelRoomStore.roomOptions;
    final mySlotVal = duelRoomStore.selfType.slot;
    final stage = duelRoomStore.stage;
    final showHandResults = stage is RoomSelectingHand ||
        stage is RoomHandResult ||
        stage is RoomSelectingTurn;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PlayerPanel(
                  mySlot: mySlotVal,
                  players: duelRoomStore.players,
                  showHandResults: showHandResults,
                  isSelectingHand: stage is RoomSelectingHand,
                  isSelectingTurn: stage is RoomSelectingTurn,
                  myHandResult: duelRoomStore.myHandResult,
                  opponentHandResult: duelRoomStore.opponentHandResult,
                  isHost: duelRoomStore.isHost,
                  onKick: duelRoomStore.kickPlayer,
                  deckSelectionEnabled: !duelRoomStore.isSelfReady,
                  decks: duelRoomStore.availableDecks,
                  selectedDeckName: duelRoomStore.selectedDeckName,
                  onSelectDeck: (value) {
                    if (value != null) {
                      duelRoomStore.selectDeck(context, value);
                    }
                  },
                  onEditDeck: duelRoomStore.selectedDeckName == null
                      ? null
                      : () => _onEditDeck(context, duelRoomStore),
                  deckInvalidationResult:
                      duelRoomStore.invalidationDeckResult,
                  handSelectEnabled: !duelRoomStore.autoHandEnabled,
                  onSendHand: duelRoomStore.sendHand,
                  turnSelectEnabled: !duelRoomStore.autoTurnOrderEnabled,
                  onSendTp: duelRoomStore.sendTp,
                  observerCount: duelRoomStore.observerCount,
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
                            cardLoader: ServiceSingleton.instance.dataService.getCard,
                          );
                        },
                      ),
                    Expanded(
                      child: ChatPanel(
                        messages: duelChatStore.chatMessages,
                        onSend: duelChatStore.sendChat,
                      ),
                    ),
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
          onToggleAutoHand: (v) => _onToggleAutomation(v, duelRoomStore.setAutoHandEnabled),
          onToggleAutoTurnOrder: (v) => _onToggleAutomation(v, duelRoomStore.setAutoTurnOrderEnabled),
          onToggleAutoDuel: (v) => _onToggleAutomation(v, duelRoomStore.setAutoDuelEnabled),
          onStartDuel: duelRoomStore.startDuel,
          onBecomeDuelist: duelRoomStore.becomeDuelist,
          onBecomeObserver: duelRoomStore.becomeObserver,
        ),
      ],
    );
  }
}
