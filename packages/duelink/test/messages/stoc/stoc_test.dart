import 'dart:typed_data';
import 'package:duelink/duelink.dart';
import 'package:test/test.dart';

void main() {
  group('STOC empty messages', () {
    void verify(dynamic msg, int protoId) {
      expect(msg.encode(), isEmpty);
      expect(msg.protoId, protoId);
    }
    test('StocChangeSide', () => verify(const StocChangeSide(), STOC_CHANGE_SIDE));
    test('StocDuelStart', () => verify(const StocDuelStart(), STOC_DUEL_START));
    test('StocDuelEnd', () => verify(const StocDuelEnd(), STOC_DUEL_END));
    test('StocSelectHand', () => verify(const StocSelectHand(), STOC_SELECT_HAND));
    test('StocSelectTp', () => verify(const StocSelectTp(), STOC_SELECT_TP));
    test('StocWaitingSide', () => verify(const StocWaitingSide(), STOC_WAITING_SIDE));
    test('StocJoinGame', () => verify(const StocJoinGame(), STOC_JOIN_GAME));
  });

  group('StocTypeChange', () {
    test('encode/decode roundtrip', () {
      final msg = StocTypeChange(isHost: true, selfType: 0);
      final decoded = StocTypeChange.decode(msg.encode());
      expect(decoded.isHost, true);
      expect(decoded.selfType, 0);
    });
    test('observer', () {
      final msg = StocTypeChange(isHost: false, selfType: 7);
      final decoded = StocTypeChange.decode(msg.encode());
      expect(decoded.isHost, false);
      expect(decoded.selfType, 7);
    });
  });

  group('StocHsPlayerEnter', () {
    test('encode/decode roundtrip', () {
      final msg = StocHsPlayerEnter(name: 'Duelist', pos: 1);
      final encoded = msg.encode();
      expect(encoded.length, 41);
      final decoded = StocHsPlayerEnter.decode(encoded);
      expect(decoded.name, 'Duelist');
      expect(decoded.pos, 1);
    });
  });

  group('StocHsPlayerChange', () {
    test('encode/decode roundtrip', () {
      final msg = StocHsPlayerChange(pos: 1, state: HS_PLAYER_STATE_READY);
      final decoded = StocHsPlayerChange.decode(msg.encode());
      expect(decoded.pos, 1);
      expect(decoded.state, HS_PLAYER_STATE_READY);
    });
  });

  group('StocHsWatchChange', () {
    test('encode/decode roundtrip', () {
      final msg = StocHsWatchChange(count: 42);
      final decoded = StocHsWatchChange.decode(msg.encode());
      expect(decoded.count, 42);
    });
  });

  group('StocChat', () {
    test('encode/decode roundtrip', () {
      final msg = StocChat(player: 0, message: 'Hello');
      final encoded = msg.encode();
      expect(encoded.length, 14); // 2(player) + 6*2(utf16)
      final decoded = StocChat.decode(encoded);
      expect(decoded.player, 0);
      expect(decoded.message, 'Hello');
    });
  });

  group('StocHandResult', () {
    test('encode/decode roundtrip', () {
      final msg = StocHandResult(meResult: 3, opResult: 1);
      final decoded = StocHandResult.decode(msg.encode());
      expect(decoded.meResult, 3);
      expect(decoded.opResult, 1);
    });
  });

  group('StocDeckCount', () {
    test('encode/decode roundtrip', () {
      final msg = StocDeckCount(
        meMain: 40,
        meExtra: 15,
        meSide: 0,
        opMain: 60,
        opExtra: 15,
        opSide: 0,
      );
      final decoded = StocDeckCount.decode(msg.encode());
      expect(decoded.meMain, 40);
      expect(decoded.opMain, 60);
    });
  });

  group('StocTimeLimit', () {
    test('encode/decode roundtrip', () {
      final msg = StocTimeLimit(player: 0, leftTime: 300);
      final decoded = StocTimeLimit.decode(msg.encode());
      expect(decoded.player, 0);
      expect(decoded.leftTime, 300);
    });
  });

  group('StocErrorMsg', () {
    test('encode/decode roundtrip', () {
      final msg = StocErrorMsg(errorType: ERROR_TYPE_DECK, errorCode: 42);
      final encoded = msg.encode();
      expect(encoded.length, 8);
      final decoded = StocErrorMsg.decode(encoded);
      expect(decoded.errorType, ERROR_TYPE_DECK);
      expect(decoded.errorCode, 42);
    });
  });
}
