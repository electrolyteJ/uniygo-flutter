import 'package:duelink/duelink.dart';
import 'package:test/test.dart';

void main() {
  group('HandType', () {
    test('fromValue returns correct enum', () {
      expect(HandType.fromValue(1), HandType.scissors);
      expect(HandType.fromValue(2), HandType.rock);
      expect(HandType.fromValue(3), HandType.paper);
      expect(HandType.fromValue(0), HandType.unknown);
      expect(HandType.fromValue(99), HandType.unknown);
    });

    test('value property matches constant', () {
      expect(HandType.rock.value, 2);
      expect(HandType.paper.value, 3);
    });
  });

  group('CardZone', () {
    test('fromNumber maps hex values', () {
      expect(CardZone.fromNumber(0x01), CardZone.deck);
      expect(CardZone.fromNumber(0x04), CardZone.mzone);
      expect(CardZone.fromNumber(0x0c), CardZone.onfield);
    });

    test('value property matches constant', () {
      expect(CardZone.hand.value, 0x02);
      expect(CardZone.grave.value, 0x10);
    });
  });

  group('Protocol IDs', () {
    test('CTOS IDs are unique', () {
      final ids = [
        CTOS_RESPONSE,
        CTOS_UPDATE_DECK,
        CTOS_HAND_RESULT,
        CTOS_TP_RESULT,
        CTOS_PLAYER_INFO,
        CTOS_JOIN_GAME,
        CTOS_TIME_CONFIRM,
        CTOS_CHAT,
        CTOS_SURRENDER,
        CTOS_HS_TO_DUELIST,
        CTOS_HS_TO_OBSERVER,
        CTOS_HS_READY,
        CTOS_HS_NOT_READY,
        CTOS_HS_START,
      ];
      expect(ids.toSet().length, ids.length);
    });

    test('STOC IDs are unique', () {
      final ids = [
        STOC_GAME_MSG,
        STOC_ERROR_MSG,
        STOC_SELECT_HAND,
        STOC_SELECT_TP,
        STOC_HAND_RESULT,
        STOC_CHANGE_SIDE,
        STOC_WAITING_SIDE,
        STOC_DECK_COUNT,
        STOC_JOIN_GAME,
        STOC_TYPE_CHANGE,
        STOC_DUEL_START,
        STOC_DUEL_END,
        STOC_TIME_LIMIT,
        STOC_CHAT,
        STOC_HS_PLAYER_ENTER,
        STOC_HS_PLAYER_CHANGE,
        STOC_HS_WATCH_CHANGE,
      ];
      expect(ids.toSet().length, ids.length);
    });
  });
}
