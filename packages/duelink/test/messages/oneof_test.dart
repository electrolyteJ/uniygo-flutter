import 'dart:typed_data';
import 'package:duelink/duelink.dart';
import 'package:test/test.dart';

void main() {
  group('YgoCtosMsg', () {
    test('playerInfo factory sets correct protoId', () {
      final msg = YgoCtosMsg.playerInfo(CtosPlayerInfo(name: 'Test'));
      expect(msg.protoId, CTOS_PLAYER_INFO);
      expect(msg.playerInfo, isNotNull);
    });

    test('joinGame factory sets correct protoId', () {
      final msg =
          YgoCtosMsg.joinGame(CtosJoinGame(version: 0x1337, gameId: 1,passwd: ""));
      expect(msg.protoId, CTOS_JOIN_GAME);
    });

    test('decode creates correct variant', () {
      final inner = CtosPlayerInfo(name: 'Player');
      final decoded = YgoCtosMsg.decode(CTOS_PLAYER_INFO, inner.encode());
      expect(decoded.protoId, CTOS_PLAYER_INFO);
      expect(decoded.playerInfo?.name, 'Player');
    });

    test('decode empty messages', () {
      final decoded = YgoCtosMsg.decode(CTOS_HS_READY, Uint8List(0));
      expect(decoded.protoId, CTOS_HS_READY);
    });
  });

  group('YgoStocMsg', () {
    test('joinGame factory sets correct protoId', () {
      final msg = YgoStocMsg.joinGame(StocJoinGame());
      expect(msg.protoId, STOC_JOIN_GAME);
    });

    test('typeChange factory sets correct protoId', () {
      final msg =
          YgoStocMsg.typeChange(StocTypeChange(isHost: true, selfType: 0));
      expect(msg.protoId, STOC_TYPE_CHANGE);
    });

    test('decode STOC_JOIN_GAME', () {
      final decoded = YgoStocMsg.decode(STOC_JOIN_GAME, Uint8List(0));
      expect(decoded.protoId, STOC_JOIN_GAME);
    });

    test('decode STOC_TYPE_CHANGE', () {
      final inner = StocTypeChange(isHost: true, selfType: 0);
      final decoded = YgoStocMsg.decode(STOC_TYPE_CHANGE, inner.encode());
      expect(decoded.typeChange?.isHost, true);
    });

    test('decode STOC_GAME_MSG', () {
      final inner = StocGameMessage(func: MSG_WIN, innerMsg: MsgWin(winPlayer: 0, reason: 1));
      final decoded = YgoStocMsg.decode(STOC_GAME_MSG, inner.encode());
      expect(decoded.gameMsg?.func, MSG_WIN);
    });

    test('roundtrip encode/decode', () {
      final msg =
          YgoStocMsg.hsPlayerEnter(StocHsPlayerEnter(name: 'Test', pos: 0));
      final decoded = YgoStocMsg.decode(msg.protoId, msg.encode());
      expect(decoded.protoId, STOC_HS_PLAYER_ENTER);
      expect(decoded.hsPlayerEnter?.name, 'Test');
    });
  });
}
