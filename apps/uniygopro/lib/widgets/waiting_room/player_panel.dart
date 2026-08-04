import 'package:flutter/material.dart';
import 'package:duelink/duelink.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../pages/deck_editor/deck_editor_session.dart';
import '../../pages/duel_room/duel_room_store.dart';
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
    final duelRoomStore = context.watch<DuelRoomStore>();
    final showCardResults =
        displayStyle == DisplayStyle.card &&
        (duelRoomStore.stage is RoomSelectingHand ||
            duelRoomStore.stage is RoomHandResult ||
            duelRoomStore.stage is RoomSelectingTurn);

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
          ...duelRoomStore.players.map(
            (item) => Container(
              margin: EdgeInsets.only(top: 8),
              child: PlayerSlot(
                player: item,
                placeholder: '玩家 ${item.pos + 1}',
                handResult: item.pos == mySlot
                    ? duelRoomStore.myHandResult
                    : duelRoomStore.opponentHandResult,
                showResult: showCardResults,
                isHostSlot: item.pos == mySlot
                    ? duelRoomStore.isHost
                    : (duelRoomStore.isHost ? false : true),
                isMe: item.pos == mySlot,
                canKick:
                    !(item.pos == mySlot
                        ? duelRoomStore.isHost
                        : (duelRoomStore.isHost ? false : true)) &&
                    item.pos != mySlot,
                onKick: () => duelRoomStore.kickPlayer(item.pos),
                displayStyle: displayStyle,
              ),
            ),
          ),
          const SizedBox(height: 12),
          DeckSelector(
            enabled: !duelRoomStore.isSelfReady,
            decks: duelRoomStore.availableDecks,
            selectedDeckName: duelRoomStore.selectedDeckName,
            mySlot: mySlot,
            onSelectDeck: (value) {
              if (value != null) {
                duelRoomStore.selectDeck(context, value);
              }
            },
            onEditDeck: duelRoomStore.selectedDeckName == null
                ? null
                : () async {
                    final result = await context.push<DeckEditorSaveResult?>(
                      '/deck-editor',
                      extra: DeckEditorRouteArgs(
                        initialDeckName: duelRoomStore.selectedDeckName,
                        validationContext: duelRoomStore.roomOptions == null
                            ? null
                            : DeckValidationContext(
                                noCheckDeck:
                                    duelRoomStore.roomOptions!.noCheckDeck,
                                lfTableHash:
                                    duelRoomStore.roomOptions!.lfTableHash,
                              ),
                        lockDeckSelection: true,
                        lockDeckName: true,
                      ),
                    );
                    if (context.mounted && (result?.saved ?? false)) {
                      await duelRoomStore.refreshSelectedDeckValidation(
                        context,
                      );
                    }
                  },
            invalidationResult: duelRoomStore.invalidationDeckResult,
          ),
          const SizedBox(height: 12),
          if (duelRoomStore.stage is RoomSelectingHand)
            HandSelect(
              enabled: !duelRoomStore.autoHandEnabled,
              onSendHand: duelRoomStore.sendHand,
            ),
          if (duelRoomStore.stage is RoomSelectingTurn)
            TpSelect(
              enabled: !duelRoomStore.autoTurnOrderEnabled,
              onSendTp: duelRoomStore.sendTp,
            ),
          const SizedBox(height: 12),
          Divider(color: Colors.blueGrey.shade600, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.visibility, size: 16, color: Colors.blueGrey.shade400),
              const SizedBox(width: 6),
              Text(
                '观战: ${duelRoomStore.observerCount}人',
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
