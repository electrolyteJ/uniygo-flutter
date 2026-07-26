import 'dart:typed_data';
import 'package:duelink/duelink.dart';
import 'package:duelink/src/messages/ctos/ctos_hs_to_duelist.dart';
import 'package:duelink/src/messages/ctos/ctos_hs_to_observer.dart';
import 'package:duelink/src/messages/ctos/ctos_hs_ready.dart';
import 'package:duelink/src/messages/ctos/ctos_hs_not_ready.dart';
import 'package:duelink/src/messages/ctos/ctos_hs_start.dart';
import 'package:duelink/src/messages/ctos/ctos_time_confirm.dart';
import 'package:duelink/src/messages/ctos/ctos_surrender.dart';
import 'package:duelink/src/messages/ctos/ctos_player_info.dart';
import 'package:duelink/src/messages/ctos/ctos_hand_result.dart';
import 'package:duelink/src/messages/ctos/ctos_tp_result.dart';
import 'package:duelink/src/messages/ctos/ctos_join_game.dart';
import 'package:duelink/src/messages/ctos/ctos_chat.dart';
import 'package:duelink/src/messages/ctos/ctos_update_deck.dart';
import 'package:duelink/src/messages/ctos/ctos_game_msg_response.dart';
import 'package:duelink/src/constants.dart';
import 'package:test/test.dart';

void main() {
  group('CTOS empty messages', () {
    void testEmpty(String name, dynamic msg, int expectedProtoId) {
      test('$name roundtrip', () {
        final encoded = (msg as dynamic).encode() as Uint8List;
        expect(encoded, isEmpty);
        expect(msg.protoId, expectedProtoId);
      });
    }

    testEmpty('CtosHsToDuelist', const CtosHsToDuelist(), CTOS_HS_TO_DUELIST);
    testEmpty('CtosHsToObserver', const CtosHsToObserver(), CTOS_HS_TO_OBSERVER);
    testEmpty('CtosHsReady', const CtosHsReady(), CTOS_HS_READY);
    testEmpty('CtosHsNotReady', const CtosHsNotReady(), CTOS_HS_NOT_READY);
    testEmpty('CtosHsStart', const CtosHsStart(), CTOS_HS_START);
    testEmpty('CtosTimeConfirm', const CtosTimeConfirm(), CTOS_TIME_CONFIRM);
    testEmpty('CtosSurrender', const CtosSurrender(), CTOS_SURRENDER);
  });

  group('CtosPlayerInfo', () {
    test('encode/decode roundtrip', () {
      final msg = CtosPlayerInfo(name: 'Player1');
      final encoded = msg.encode();
      expect(encoded.length, 40);
      final decoded = CtosPlayerInfo.decode(encoded);
      expect(decoded.name, 'Player1');
    });

    test('empty name', () {
      final msg = CtosPlayerInfo(name: '');
      final decoded = CtosPlayerInfo.decode(msg.encode());
      expect(decoded.name, '');
    });
  });

  group('CtosHandResult', () {
    test('encode/decode roundtrip', () {
      final msg = CtosHandResult(hand: 2);
      final decoded = CtosHandResult.decode(msg.encode());
      expect(decoded.hand, 2);
    });
  });

  group('CtosTpResult', () {
    test('encode/decode roundtrip first', () {
      final msg = CtosTpResult(first: true);
      expect(msg.encode(), Uint8List.fromList([1]));
      expect(CtosTpResult.decode(msg.encode()).first, true);
    });

    test('encode/decode roundtrip second', () {
      final msg = CtosTpResult(first: false);
      expect(CtosTpResult.decode(msg.encode()).first, false);
    });
  });

  group('CtosJoinGame', () {
    test('encode/decode roundtrip', () {
      final msg = CtosJoinGame(version: 0x1337, gameId: 42, passwd: 'pwd');
      final encoded = msg.encode();
      expect(encoded.length, 48);
      final decoded = CtosJoinGame.decode(encoded);
      expect(decoded.version, 0x1337);
      expect(decoded.gameId, 42);
      expect(decoded.passwd, 'pwd');
    });
  });

  group('CtosChat', () {
    test('encode/decode roundtrip', () {
      final msg = CtosChat(message: 'Hello');
      final encoded = msg.encode();
      expect(encoded.length, 12);
      final decoded = CtosChat.decode(encoded);
      expect(decoded.message, 'Hello');
    });
  });

  group('CtosUpdateDeck', () {
    test('encode/decode roundtrip', () {
      final msg = CtosUpdateDeck(
        mainDeck: [89631139, 46986414],
        extraDeck: [],
        sideDeck: [12345678],
      );
      final encoded = msg.encode();
      expect(encoded.length, 20);
      final decoded = CtosUpdateDeck.decode(encoded);
      expect(decoded.mainDeck.length, 2);
      expect(decoded.mainDeck[0], 89631139);
      expect(decoded.sideDeck.length, 1);
    });
  });

  group('CtosGameMsgResponse', () {
    test('selectIdleCmd', () {
      final msg = CtosGameMsgResponse.selectIdleCmd(0x10000000);
      expect(msg.encode().length, 4);
      expect(msg.variantType, 'selectIdleCmd');
    });

    test('selectPlace', () {
      final msg = CtosGameMsgResponse.selectPlace(CtosSelectPlace(player: 0, zone: 0x04, sequence: 3));
      expect(msg.encode(), [0, 4, 3]);
    });

    test('selectMulti', () {
      final msg = CtosGameMsgResponse.selectMulti([0, 2, 1]);
      expect(msg.encode(), [3, 0, 2, 1]);
    });

    test('selectSingle', () {
      final msg = CtosGameMsgResponse.selectSingle(-1);
      expect(msg.encode(), [0xff, 0xff, 0xff, 0xff]);
    });

    test('selectEffectYn', () {
      final msg = CtosGameMsgResponse.selectEffectYn(1);
      expect(msg.encode(), [1, 0, 0, 0]);
    });

    test('selectPosition', () {
      final msg = CtosGameMsgResponse.selectPosition(0x4);
      expect(msg.encode(), [4, 0, 0, 0]);
    });

    test('selectOption', () {
      final msg = CtosGameMsgResponse.selectOption(42);
      expect(msg.encode(), [42, 0, 0, 0]);
    });

    test('selectBattleCmd', () {
      final msg = CtosGameMsgResponse.selectBattleCmd(0x12345678);
      expect(msg.encode().length, 4);
    });

    test('selectCounter', () {
      final msg = CtosGameMsgResponse.selectCounter([1, -2, 256]);
      final encoded = msg.encode();
      expect(encoded.length, 6);
      expect(encoded, [1, 0, 0xfe, 0xff, 0, 1]);
    });

    test('sortCard', () {
      final msg = CtosGameMsgResponse.sortCard([3, 1, 2, 0]);
      expect(msg.encode(), [3, 1, 2, 0]);
    });
  });
}
