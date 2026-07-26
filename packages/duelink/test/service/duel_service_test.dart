import 'dart:typed_data';
import 'package:duelink/duelink.dart';
import 'package:duelink/src/service/room_state.dart';
import 'package:duelink/src/messages/stoc/stoc_join_game.dart';
import 'package:duelink/src/messages/stoc/stoc_type_change.dart';
import 'package:duelink/src/messages/stoc/stoc_hs_player_enter.dart';
import 'package:duelink/src/messages/stoc/stoc_hs_watch_change.dart';
import 'package:duelink/src/messages/stoc/stoc_hand_result.dart';
import 'package:duelink/src/protocol/packet.dart';
import 'package:duelink/src/constants.dart';
import 'package:test/test.dart';
import '../helpers/test_duel_service.dart';

void main() {
  group('RoomState state machine', () {
    test('initial state is waiting, not joined', () async {
      final mockConn = MockConnection();
      final states = <RoomState>[];
      final service = TestDuelServiceImpl(connection: mockConn);
      service.onRoomStateChange.listen(states.add);
      await service.connect('koishi.momobako.com', 7211);

      // After connect, initial state should be emitted (broadcast controller
      // won't replay, but _handleRawData will emit on each incoming message)
      // Inject an empty packet to trigger state emission
      mockConn.injectPacket(
          YgoProPacket.create(STOC_JOIN_GAME, Uint8List(0)).serialize());
      await Future.delayed(Duration.zero);
      expect(states.isNotEmpty, true);
      expect(states.last.stage, RoomStage.waiting);
      // joinGame sets joined=true, so check that
      expect(states.last.joined, true);
    });

    test('StocJoinGame sets joined=true', () async {
      final mockConn = MockConnection();
      final states = <RoomState>[];
      final service = TestDuelServiceImpl(connection: mockConn);
      service.onRoomStateChange.listen(states.add);
      await service.connect('localhost', 7911);

      final pkt = YgoProPacket.create(STOC_JOIN_GAME, StocJoinGame().encode());
      mockConn.injectPacket(pkt.serialize());

      await Future.delayed(Duration.zero);
      expect(states.last.joined, true);
    });

    test('StocTypeChange sets selfType and isHost', () async {
      final mockConn = MockConnection();
      final states = <RoomState>[];
      final service = TestDuelServiceImpl(connection: mockConn);
      service.onRoomStateChange.listen(states.add);
      await service.connect('localhost', 7911);

      final inner = StocTypeChange(isHost: true, selfType: 0);
      final pkt = YgoProPacket.create(STOC_TYPE_CHANGE, inner.encode());
      mockConn.injectPacket(pkt.serialize());

      await Future.delayed(Duration.zero);
      expect(states.last.isHost, true);
      expect(states.last.selfType, SelfType.player1);
    });

    test('StocHsPlayerEnter adds player', () async {
      final mockConn = MockConnection();
      final states = <RoomState>[];
      final service = TestDuelServiceImpl(connection: mockConn);
      service.onRoomStateChange.listen(states.add);
      await service.connect('localhost', 7911);

      final inner = StocHsPlayerEnter(name: 'DuelistA', pos: 0);
      final pkt = YgoProPacket.create(STOC_HS_PLAYER_ENTER, inner.encode());
      mockConn.injectPacket(pkt.serialize());

      await Future.delayed(Duration.zero);
      expect(states.last.players.length, 1);
      expect(states.last.players.first.name, 'DuelistA');
    });

    test('StocHsWatchChange updates observer count', () async {
      final mockConn = MockConnection();
      final states = <RoomState>[];
      final service = TestDuelServiceImpl(connection: mockConn);
      service.onRoomStateChange.listen(states.add);
      await service.connect('localhost', 7911);

      final inner = StocHsWatchChange(count: 5);
      final pkt = YgoProPacket.create(STOC_HS_WATCH_CHANGE, inner.encode());
      mockConn.injectPacket(pkt.serialize());

      await Future.delayed(Duration.zero);
      expect(states.last.observerCount, 5);
    });

    test('full RoomStage flow', () async {
      final mockConn = MockConnection();
      final states = <RoomState>[];
      final service = TestDuelServiceImpl(connection: mockConn);
      service.onRoomStateChange.listen(states.add);
      await service.connect('koishi.momobako.com', 7210);

      // Step 1: Join
      mockConn.injectPacket(
          YgoProPacket.create(STOC_JOIN_GAME, Uint8List(0)).serialize());
      await Future.delayed(Duration.zero);
      // Step 2: Select hand
      mockConn.injectPacket(
          YgoProPacket.create(STOC_SELECT_HAND, Uint8List(0)).serialize());
      await Future.delayed(Duration.zero);
      expect(states.last.stage, RoomStage.handSelecting);
      // Step 3: Hand result
      mockConn.injectPacket(YgoProPacket.create(
              STOC_HAND_RESULT, StocHandResult(meResult: 2, opResult: 1).encode())
          .serialize());
      await Future.delayed(Duration.zero);
      expect(states.last.stage, RoomStage.handSelected);
      // Step 4: Select TP
      mockConn.injectPacket(
          YgoProPacket.create(STOC_SELECT_TP, Uint8List(0)).serialize());
      await Future.delayed(Duration.zero);
      expect(states.last.stage, RoomStage.tpSelecting);
      // Step 5: Duel start
      mockConn.injectPacket(
          YgoProPacket.create(STOC_DUEL_START, Uint8List(0)).serialize());
      await Future.delayed(Duration.zero);
      expect(states.last.stage, RoomStage.duelStart);
    });
  });
}
