import 'package:flutter_test/flutter_test.dart';
import 'package:duelink/duelink.dart';
import 'package:uniygopro/models/FieldCard.dart';
import 'package:uniygopro/models/SelectState.dart';
import 'package:uniygopro/stores/duel_room_state.dart';

void main() {
  group('DuelRoomState (duel)', () {
    test('setFieldCard adds card', () {
      final store = DuelRoomState();
      final card = FieldCard(
        code: 89631139,
        controller: 0,
        zone: 4,
        sequence: 3,
      );
      store.setFieldCard(card);
      expect(store.fieldCards['0_4_3']?.code, 89631139);
    });

    test('removeFieldCard removes card', () {
      final store = DuelRoomState();
      store.setFieldCard(FieldCard(
        code: 89631139,
        controller: 0,
        zone: 4,
        sequence: 3,
      ));
      store.removeFieldCard(0, 4, 3);
      expect(store.fieldCards.containsKey('0_4_3'), false);
    });

    test('setSelect sets interaction state', () {
      final store = DuelRoomState();
      store.setSelect(SelectState(type: SelectType.idleCmd, player: 0));
      expect(store.isWaitingForInput, true);
      expect(store.currentSelect?.type, SelectType.idleCmd);
    });

    test('clearSelect clears interaction', () {
      final store = DuelRoomState();
      store.setSelect(SelectState(type: SelectType.idleCmd, player: 0));
      store.clearSelect();
      expect(store.isWaitingForInput, false);
    });

    test('updateFromStart sets initial state', () {
      final store = DuelRoomState();
      store.updateFromStart(
        selfLp: 8000,
        opponentLp: 8000,
        selfDeck: 40,
        selfExtra: 15,
        oppDeck: 40,
        oppExtra: 15,
      );
      expect(store.selfLp, 8000);
      expect(store.selfDeck, 40);
      expect(store.oppExtra, 15);
    });
  });
}
