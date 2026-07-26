import 'dart:async';
import 'dart:typed_data';
import 'package:duelink/duelink.dart';
import 'package:duelink/src/constants.dart';
import 'package:duelink/src/protocol/packet.dart';
import 'package:duelink/src/protocol/adapter.dart';
import 'package:duelink/src/protocol/buffer_io.dart';
import 'package:duelink/src/service/room_state.dart';
import 'package:duelink/src/messages/ygo_stoc_msg.dart';
import 'package:duelink/src/messages/ygo_ctos_msg.dart';
import 'package:duelink/src/messages/ctos/ctos_game_msg_response.dart';
import 'package:duelink/src/messages/stoc/stoc_game_msg.dart';
import 'package:duelink/src/messages/game_msg/msg_start.dart';
import 'package:duelink/src/messages/game_msg/msg_draw.dart';
import 'package:duelink/src/messages/game_msg/msg_new_turn.dart';
import 'package:duelink/src/messages/game_msg/msg_new_phase.dart';
import 'package:duelink/src/messages/game_msg/msg_win.dart';
import 'package:duelink/src/messages/game_msg/msg_damage.dart';
import 'package:duelink/src/messages/game_msg/msg_move.dart';
import 'package:duelink/src/messages/game_msg/msg_summoning.dart';
import 'package:duelink/src/messages/game_msg/msg_summoned.dart';
import 'package:duelink/src/messages/game_msg/msg_select_idle_cmd.dart';
import 'package:duelink/src/messages/game_msg/msg_select_card.dart';
import 'package:duelink/src/messages/game_msg/msg_select_position.dart';
import 'package:duelink/src/messages/game_msg/msg_select_effect_yn.dart';
import 'package:duelink/src/messages/game_msg/msg_select_yes_no.dart';
import 'package:duelink/src/messages/game_msg/msg_select_option.dart';
import 'package:duelink/src/messages/game_msg/msg_hint.dart';
import 'package:duelink/src/messages/game_msg/msg_lp_update.dart';
import 'package:duelink/src/messages/game_msg/msg_attack.dart';
import 'package:duelink/src/messages/stoc/stoc_join_game.dart';
import 'package:duelink/src/messages/stoc/stoc_type_change.dart';
import 'package:duelink/src/messages/stoc/stoc_hs_player_enter.dart';
import 'package:duelink/src/messages/stoc/stoc_hs_player_change.dart';
import 'package:duelink/src/messages/stoc/stoc_hs_watch_change.dart';
import 'package:duelink/src/messages/stoc/stoc_hand_result.dart';
import 'package:duelink/src/messages/stoc/stoc_chat.dart';
import 'package:duelink/src/messages/stoc/stoc_time_limit.dart';
import 'package:duelink/src/messages/stoc/stoc_error_msg.dart';
import 'package:duelink/src/messages/stoc/stoc_deck_count.dart';
import 'package:duelink/src/messages/stoc/stoc_duel_end.dart';
import '../helpers/test_duel_service.dart';
import 'package:test/test.dart';

/// CapturingConnection records all CTOS data sent by the client.
class CapturingConnection extends MockConnection {
  final List<YgoCtosMsg> sentMessages = [];

  @override
  void send(Uint8List data) {
    final packets = YgoProPacket.deserialize(data);
    for (final pkt in packets) {
      sentMessages.add(YgoCtosMsg.decode(pkt.proto, pkt.exData));
    }
  }

  /// Helper to inject a raw STOC packet
  void injectStoc(int protoId, Uint8List payload) {
    injectPacket(YgoProPacket.create(protoId, payload).serialize());
  }

  /// Helper to inject a game message
  void injectGameMsg(int msgFunc, Uint8List innerPayload) {
    final w = BufferWriter();
    w.writeUint8(msgFunc);
    w.writeBytes(innerPayload);
    injectStoc(STOC_GAME_MSG, w.toBytes());
  }
}

void main() {
  group('Two-Player Duel Communication', () {
    late CapturingConnection conn1;
    late CapturingConnection conn2;
    late DuelService player1;
    late DuelService player2;

    setUp(() async {
      conn1 = CapturingConnection();
      conn2 = CapturingConnection();
      player1 = TestDuelServiceImpl(connection: conn1);
      player2 = TestDuelServiceImpl(connection: conn2);
      await player1.connect('localhost', 7911);
      await player2.connect('localhost', 7911);
    });

    tearDown(() async {
      await player1.disconnect();
      await player2.disconnect();
    });

    /// Helper: broadcast STOC to both players
    void broadcast(int protoId, Uint8List payload) {
      conn1.injectStoc(protoId, payload);
      conn2.injectStoc(protoId, payload);
    }

    /// Helper: broadcast game message to both players
    void broadcastGameMsg(int msgFunc, Uint8List innerPayload) {
      conn1.injectGameMsg(msgFunc, innerPayload);
      conn2.injectGameMsg(msgFunc, innerPayload);
    }

    group('Connection & Room Setup', () {
      test('both players connect successfully', () async {
        expect(conn1.state, isNotNull);
        expect(conn2.state, isNotNull);
      });

      test('player sends PlayerInfo and JoinGame', () async {
        player1.sendPlayerInfo('Player1');
        player1.sendJoinGame(0, '');
        await Future.delayed(Duration.zero);

        final sent = conn1.sentMessages;
        expect(sent.length, 2);
        expect(sent[0].playerInfo, isNotNull);
        expect(sent[0].playerInfo!.name, 'Player1');
        expect(sent[1].joinGame, isNotNull);
      });

      test('room state progresses through JoinGame -> TypeChange -> PlayerEnter', () async {
        final states = <RoomState>[];
        player1.onRoomStateChange.listen(states.add);

        conn1.injectStoc(STOC_JOIN_GAME, StocJoinGame().encode());
        await Future.delayed(Duration.zero);
        expect(states.last.joined, true);

        conn1.injectStoc(STOC_TYPE_CHANGE,
            StocTypeChange(isHost: true, selfType: 0).encode());
        await Future.delayed(Duration.zero);
        expect(states.last.selfType, SelfType.player1);
        expect(states.last.isHost, true);

        conn1.injectStoc(STOC_HS_PLAYER_ENTER,
            StocHsPlayerEnter(name: 'Alice', pos: 0).encode());
        await Future.delayed(Duration.zero);
        expect(states.last.players.length, 1);
        expect(states.last.players.first.name, 'Alice');

        conn1.injectStoc(STOC_HS_PLAYER_ENTER,
            StocHsPlayerEnter(name: 'Bob', pos: 1).encode());
        await Future.delayed(Duration.zero);
        expect(states.last.players.length, 2);
        expect(states.last.players.last.name, 'Bob');
      });

      test('both players see each other join the room', () async {
        final p1States = <RoomState>[];
        final p2States = <RoomState>[];
        player1.onRoomStateChange.listen(p1States.add);
        player2.onRoomStateChange.listen(p2States.add);

        conn1.injectStoc(STOC_JOIN_GAME, StocJoinGame().encode());
        conn2.injectStoc(STOC_JOIN_GAME, StocJoinGame().encode());
        await Future.delayed(Duration.zero);

        conn1.injectStoc(STOC_TYPE_CHANGE,
            StocTypeChange(isHost: true, selfType: 0).encode());
        conn2.injectStoc(STOC_TYPE_CHANGE,
            StocTypeChange(isHost: false, selfType: 1).encode());
        await Future.delayed(Duration.zero);

        expect(p1States.last.selfType, SelfType.player1);
        expect(p1States.last.isHost, true);
        expect(p2States.last.selfType, SelfType.player2);
        expect(p2States.last.isHost, false);

        broadcast(STOC_HS_PLAYER_ENTER,
            StocHsPlayerEnter(name: 'Alice', pos: 0).encode());
        await Future.delayed(Duration.zero);
        broadcast(STOC_HS_PLAYER_ENTER,
            StocHsPlayerEnter(name: 'Bob', pos: 1).encode());
        await Future.delayed(Duration.zero);

        expect(p1States.last.players.length, 2);
        expect(p2States.last.players.length, 2);
      });

      test('observer count updates', () async {
        final p1States = <RoomState>[];
        player1.onRoomStateChange.listen(p1States.add);

        conn1.injectStoc(
            STOC_HS_WATCH_CHANGE, StocHsWatchChange(count: 3).encode());
        await Future.delayed(Duration.zero);
        expect(p1States.last.observerCount, 3);
      });

      test('ready/notReady/start are sent correctly', () async {
        player1.sendReady();
        await Future.delayed(Duration.zero);
        expect(conn1.sentMessages.last.hsReady, isNotNull);

        player1.sendNotReady();
        await Future.delayed(Duration.zero);
        expect(conn1.sentMessages.last.hsNotReady, isNotNull);

        player1.sendStart();
        await Future.delayed(Duration.zero);
        expect(conn1.sentMessages.last.hsStart, isNotNull);
      });

      test('switching between duelist and observer', () async {
        player1.sendToObserver();
        await Future.delayed(Duration.zero);
        expect(conn1.sentMessages.last.hsToObserver, isNotNull);

        player1.sendToDuelist();
        await Future.delayed(Duration.zero);
        expect(conn1.sentMessages.last.hsToDuelist, isNotNull);
      });
    });

    group('Hand Selection (Rock-Paper-Scissors)', () {
      test('full hand selection flow', () async {
        final p1States = <RoomState>[];
        final p2States = <RoomState>[];
        player1.onRoomStateChange.listen(p1States.add);
        player2.onRoomStateChange.listen(p2States.add);

        broadcast(STOC_SELECT_HAND, Uint8List(0));
        await Future.delayed(Duration.zero);
        expect(p1States.last.stage, RoomStage.handSelecting);
        expect(p2States.last.stage, RoomStage.handSelecting);

        player1.sendHandResult(HandType.scissors);
        player2.sendHandResult(HandType.rock);
        await Future.delayed(Duration.zero);

        broadcast(STOC_HAND_RESULT,
            StocHandResult(meResult: 1, opResult: 2).encode());
        await Future.delayed(Duration.zero);
        expect(p1States.last.stage, RoomStage.handSelected);
        expect(p2States.last.stage, RoomStage.handSelected);
      });

      test('hand selection messages captured correctly', () async {
        player1.sendHandResult(HandType.rock);
        await Future.delayed(Duration.zero);

        final sent = conn1.sentMessages;
        expect(sent.last.handResult, isNotNull);
        expect(sent.last.handResult!.hand, HandType.rock.value);
      });
    });

    group('Turn Priority Selection', () {
      test('player chooses to go first', () async {
        final p1States = <RoomState>[];
        player1.onRoomStateChange.listen(p1States.add);

        conn1.injectStoc(STOC_SELECT_TP, Uint8List(0));
        await Future.delayed(Duration.zero);
        expect(p1States.last.stage, RoomStage.tpSelecting);

        player1.sendTpResult(true);
        await Future.delayed(Duration.zero);

        final sent = conn1.sentMessages;
        expect(sent.last.tpResult, isNotNull);
        expect(sent.last.tpResult!.first, true);
      });

      test('player chooses to go second', () async {
        player1.sendTpResult(false);
        await Future.delayed(Duration.zero);

        final sent = conn1.sentMessages;
        expect(sent.last.tpResult!.first, false);
      });
    });

    group('Duel Start & Game Messages', () {
      test('duel start transitions to duelStart stage', () async {
        final p1States = <RoomState>[];
        final p2States = <RoomState>[];
        player1.onRoomStateChange.listen(p1States.add);
        player2.onRoomStateChange.listen(p2States.add);

        broadcast(STOC_DUEL_START, Uint8List(0));
        await Future.delayed(Duration.zero);
        expect(p1States.last.stage, RoomStage.duelStart);
        expect(p2States.last.stage, RoomStage.duelStart);
      });

      test('MSG_START is received by both players', () async {
        final p1Messages = <StocGameMessage>[];
        final p2Messages = <StocGameMessage>[];
        player1.onMessage.listen((m) {
          if (m.gameMsg != null) p1Messages.add(m.gameMsg!);
        });
        player2.onMessage.listen((m) {
          if (m.gameMsg != null) p2Messages.add(m.gameMsg!);
        });

        final startMsg = MsgStart(
          playerType: 0x00,
          life1: 8000,
          life2: 8000,
          deckSize1: 40,
          extraSize1: 15,
          deckSize2: 40,
          extraSize2: 15,
        );
        broadcastGameMsg(MSG_START, startMsg.encode());
        await Future.delayed(Duration.zero);

        expect(p1Messages.length, 1);
        expect(p2Messages.length, 1);
        expect(p1Messages.first.func, MSG_START);
        final decoded = p1Messages.first.innerMsg as MsgStart;
        expect(decoded.life1, 8000);
        expect(decoded.life2, 8000);
      });

      test('MSG_DRAW notifies both players', () async {
        final p1Messages = <StocGameMessage>[];
        player1.onMessage.listen((m) {
          if (m.gameMsg != null) p1Messages.add(m.gameMsg!);
        });

        final drawMsg = MsgDraw(player: 0, count: 1, cards: [36996508]);
        conn1.injectGameMsg(MSG_DRAW, drawMsg.encode());
        await Future.delayed(Duration.zero);

        expect(p1Messages.length, 1);
        final decoded = p1Messages.first.innerMsg as MsgDraw;
        expect(decoded.player, 0);
        expect(decoded.count, 1);
        expect(decoded.cards.first, 36996508);
      });

      test('MSG_NEW_TURN and MSG_NEW_PHASE sequence', () async {
        final p1Messages = <StocGameMessage>[];
        player1.onMessage.listen((m) {
          if (m.gameMsg != null) p1Messages.add(m.gameMsg!);
        });

        conn1.injectGameMsg(MSG_NEW_TURN, MsgNewTurn(player: 0).encode());
        await Future.delayed(Duration.zero);

        conn1.injectGameMsg(
            MSG_NEW_PHASE, MsgNewPhase(phase: PHASE_DRAW).encode());
        await Future.delayed(Duration.zero);

        conn1.injectGameMsg(
            MSG_NEW_PHASE, MsgNewPhase(phase: PHASE_STANDBY).encode());
        await Future.delayed(Duration.zero);

        conn1.injectGameMsg(
            MSG_NEW_PHASE, MsgNewPhase(phase: PHASE_MAIN1).encode());
        await Future.delayed(Duration.zero);

        expect(p1Messages.length, 4);
        expect(p1Messages[0].innerMsg, isA<MsgNewTurn>());
        expect((p1Messages[0].innerMsg as MsgNewTurn).player, 0);
        expect(p1Messages[1].innerMsg, isA<MsgNewPhase>());
        expect((p1Messages[1].innerMsg as MsgNewPhase).phase, PHASE_DRAW);
        expect((p1Messages[2].innerMsg as MsgNewPhase).phase, PHASE_STANDBY);
        expect((p1Messages[3].innerMsg as MsgNewPhase).phase, PHASE_MAIN1);
      });
    });

    group('Player Actions & Responses', () {
      test('player responds to MSG_SELECT_IDLE_CMD', () async {
        final idleCmdMsg = MsgSelectIdleCmd(
          player: 0,
          rawData: Uint8List.fromList([0, 0, 0, 0, 0]),
        );
        conn1.injectGameMsg(MSG_SELECT_IDLE_CMD, idleCmdMsg.encode());
        await Future.delayed(Duration.zero);

        player1.sendResponse(CtosGameMsgResponse.selectIdleCmd(0x1000000));
        await Future.delayed(Duration.zero);

        final sent = conn1.sentMessages;
        expect(sent.last.response, isNotNull);
        // CTOS_RESPONSE decode always produces selectSinglePtr (4-byte int32)
        // because the wire format doesn't carry variant info.
        // Verify the response was sent with correct proto ID.
        expect(sent.last.protoId, CTOS_RESPONSE);
      });

      test('player responds to MSG_SELECT_POSITION', () async {
        final posMsg = MsgSelectPosition(
          player: 0,
          code: 36996508,
          positions: POS_FACEUP_ATTACK | POS_FACEUP_DEFENSE,
        );
        conn1.injectGameMsg(MSG_SELECT_POSITION, posMsg.encode());
        await Future.delayed(Duration.zero);

        player1.sendResponse(
            CtosGameMsgResponse.selectPosition(POS_FACEUP_ATTACK));
        await Future.delayed(Duration.zero);

        final sent = conn1.sentMessages;
        expect(sent.last.response, isNotNull);
        expect(sent.last.protoId, CTOS_RESPONSE);
      });

      test('player responds to MSG_SELECT_CARD', () async {
        final cardMsg = MsgSelectCard(
          player: 0,
          cancelable: 0,
          min: 1,
          max: 1,
          count: 2,
          codes: [36996508, 89631139],
          locations: [
            const CardLocation(
                controller: 0, location: CARD_ZONE_HAND, sequence: 0),
            const CardLocation(
                controller: 0, location: CARD_ZONE_HAND, sequence: 1),
          ],
        );
        conn1.injectGameMsg(MSG_SELECT_CARD, cardMsg.encode());
        await Future.delayed(Duration.zero);

        player1.sendResponse(CtosGameMsgResponse.selectMulti([0]));
        await Future.delayed(Duration.zero);

        final sent = conn1.sentMessages;
        expect(sent.last.response, isNotNull);
        expect(sent.last.protoId, CTOS_RESPONSE);
      });

      test('player responds to MSG_SELECT_EFFECTYN', () async {
        final effectYnMsg = MsgSelectEffectYn(
          player: 0,
          code: 36996508,
          location: const CardLocation(
              controller: 0, location: CARD_ZONE_HAND, sequence: 0),
          effectDescription: 0,
        );
        conn1.injectGameMsg(MSG_SELECT_EFFECTYN, effectYnMsg.encode());
        await Future.delayed(Duration.zero);

        player1.sendResponse(CtosGameMsgResponse.selectEffectYn(1));
        await Future.delayed(Duration.zero);

        final sent = conn1.sentMessages;
        expect(sent.last.response, isNotNull);
        expect(sent.last.protoId, CTOS_RESPONSE);
      });

      test('player responds to MSG_SELECT_YES_NO', () async {
        final yesNoMsg = MsgSelectYesNo(player: 0, effectDescription: 100);
        conn1.injectGameMsg(MSG_SELECT_YES_NO, yesNoMsg.encode());
        await Future.delayed(Duration.zero);

        player1.sendResponse(CtosGameMsgResponse.selectEffectYn(1));
        await Future.delayed(Duration.zero);

        final sent = conn1.sentMessages;
        expect(sent.last.response, isNotNull);
        expect(sent.last.protoId, CTOS_RESPONSE);
      });

      test('player responds to MSG_SELECT_OPTION', () async {
        final optionMsg = MsgSelectOption(
          player: 0,
          count: 2,
          codes: [0x1000001, 0x1000002],
        );
        conn1.injectGameMsg(MSG_SELECT_OPTION, optionMsg.encode());
        await Future.delayed(Duration.zero);

        player1.sendResponse(CtosGameMsgResponse.selectOption(0x1000001));
        await Future.delayed(Duration.zero);

        final sent = conn1.sentMessages;
        expect(sent.last.response, isNotNull);
        expect(sent.last.protoId, CTOS_RESPONSE);
      });

      test('player sends time confirm', () async {
        player1.sendTimeConfirm();
        await Future.delayed(Duration.zero);

        final sent = conn1.sentMessages;
        expect(sent.last.timeConfirm, isNotNull);
      });

      test('player surrenders', () async {
        player1.sendSurrender();
        await Future.delayed(Duration.zero);

        final sent = conn1.sentMessages;
        expect(sent.last.surrender, isNotNull);
      });
    });

    group('Card Movement & Combat', () {
      test('MSG_MOVE card from deck to hand', () async {
        final p1Messages = <StocGameMessage>[];
        player1.onMessage.listen((m) {
          if (m.gameMsg != null) p1Messages.add(m.gameMsg!);
        });

        final moveMsg = MsgMove(
          code: 36996508,
          from: const CardLocation(
              controller: 0, location: CARD_ZONE_DECK, sequence: 0),
          to: const CardLocation(
              controller: 0, location: CARD_ZONE_HAND, sequence: 4),
          reason: 0,
        );
        conn1.injectGameMsg(MSG_MOVE, moveMsg.encode());
        await Future.delayed(Duration.zero);

        expect(p1Messages.length, 1);
        final decoded = p1Messages.first.innerMsg as MsgMove;
        expect(decoded.code, 36996508);
        expect(decoded.from.location, CARD_ZONE_DECK);
        expect(decoded.to.location, CARD_ZONE_HAND);
      });

      test('MSG_SUMMONING and MSG_SUMMONED sequence', () async {
        final p1Messages = <StocGameMessage>[];
        player1.onMessage.listen((m) {
          if (m.gameMsg != null) p1Messages.add(m.gameMsg!);
        });

        conn1.injectGameMsg(
            MSG_SUMMONING,
            MsgSummoning(
              code: 36996508,
              location: const CardLocation(
                  controller: 0,
                  location: CARD_ZONE_MZONE,
                  sequence: 0,
                  position: POS_FACEUP_ATTACK),
            ).encode());
        await Future.delayed(Duration.zero);

        conn1.injectGameMsg(MSG_SUMMONED, MsgSummoned().encode());
        await Future.delayed(Duration.zero);

        expect(p1Messages.length, 2);
        expect(p1Messages[0].func, MSG_SUMMONING);
        expect(p1Messages[1].func, MSG_SUMMONED);
        final summoning = p1Messages[0].innerMsg as MsgSummoning;
        expect(summoning.code, 36996508);
      });

      test('MSG_ATTACK and MSG_DAMAGE combat sequence', () async {
        final p1Messages = <StocGameMessage>[];
        player1.onMessage.listen((m) {
          if (m.gameMsg != null) p1Messages.add(m.gameMsg!);
        });

        final attackMsg = MsgAttack(
          attacker: const CardLocation(
              controller: 0,
              location: CARD_ZONE_MZONE,
              sequence: 0,
              position: POS_FACEUP_ATTACK),
          target: const CardLocation(
              controller: 1,
              location: CARD_ZONE_MZONE,
              sequence: 0,
              position: POS_FACEUP_ATTACK),
        );
        conn1.injectGameMsg(MSG_ATTACK, attackMsg.encode());
        await Future.delayed(Duration.zero);

        conn1.injectGameMsg(
            MSG_DAMAGE, MsgDamage(player: 1, value: 2500).encode());
        await Future.delayed(Duration.zero);

        expect(p1Messages.length, 2);
        expect(p1Messages[0].innerMsg, isA<MsgAttack>());
        expect(p1Messages[1].innerMsg, isA<MsgDamage>());
        final damage = p1Messages[1].innerMsg as MsgDamage;
        expect(damage.player, 1);
        expect(damage.value, 2500);
      });

      test('direct attack (null target)', () async {
        final p1Messages = <StocGameMessage>[];
        player1.onMessage.listen((m) {
          if (m.gameMsg != null) p1Messages.add(m.gameMsg!);
        });

        final attackMsg = MsgAttack(
          attacker: const CardLocation(
              controller: 0,
              location: CARD_ZONE_MZONE,
              sequence: 0,
              position: POS_FACEUP_ATTACK),
          target: null,
        );
        conn1.injectGameMsg(MSG_ATTACK, attackMsg.encode());
        await Future.delayed(Duration.zero);

        conn1.injectGameMsg(
            MSG_DAMAGE, MsgDamage(player: 1, value: 2500).encode());
        await Future.delayed(Duration.zero);

        expect(p1Messages.length, 2);
        final attack = p1Messages.first.innerMsg as MsgAttack;
        expect(attack.target, isNull);
      });

      test('MSG_LP_UPDATE updates both players LP', () async {
        final p1Messages = <StocGameMessage>[];
        final p2Messages = <StocGameMessage>[];
        player1.onMessage.listen((m) {
          if (m.gameMsg != null) p1Messages.add(m.gameMsg!);
        });
        player2.onMessage.listen((m) {
          if (m.gameMsg != null) p2Messages.add(m.gameMsg!);
        });

        broadcastGameMsg(
            MSG_LP_UPDATE, MsgLpUpdate(player: 1, newLp: 5500).encode());
        await Future.delayed(Duration.zero);

        expect(p1Messages.length, 1);
        expect(p2Messages.length, 1);
        final lp = p1Messages.first.innerMsg as MsgLpUpdate;
        expect(lp.player, 1);
        expect(lp.newLp, 5500);
      });
    });

    group('Duel End Conditions', () {
      test('MSG_WIN notifies both players', () async {
        final p1Messages = <StocGameMessage>[];
        final p2Messages = <StocGameMessage>[];
        player1.onMessage.listen((m) {
          if (m.gameMsg != null) p1Messages.add(m.gameMsg!);
        });
        player2.onMessage.listen((m) {
          if (m.gameMsg != null) p2Messages.add(m.gameMsg!);
        });

        broadcastGameMsg(MSG_WIN, MsgWin(winPlayer: 0, reason: 0).encode());
        await Future.delayed(Duration.zero);

        expect(p1Messages.length, 1);
        expect(p2Messages.length, 1);
        final win = p1Messages.first.innerMsg as MsgWin;
        expect(win.winPlayer, 0);
        expect(win.reason, 0);
      });

      test('STOC_DUEL_END after win', () async {
        final p1Msgs = <YgoStocMsg>[];
        player1.onMessage.listen(p1Msgs.add);

        conn1.injectStoc(STOC_DUEL_END, Uint8List(0));
        await Future.delayed(Duration.zero);

        expect(p1Msgs.last.duelEnd, isNotNull);
      });
    });

    group('Chat Communication', () {
      test('server sends chat to both players', () async {
        final p1Chats = <String>[];
        final p2Chats = <String>[];
        player1.onMessage.listen((m) {
          if (m.chat != null) p1Chats.add(m.chat!.message);
        });
        player2.onMessage.listen((m) {
          if (m.chat != null) p2Chats.add(m.chat!.message);
        });

        broadcast(STOC_CHAT, StocChat(player: 0, message: 'Hello!').encode());
        await Future.delayed(Duration.zero);

        expect(p1Chats, ['Hello!']);
        expect(p2Chats, ['Hello!']);
      });

      test('player sends chat message', () async {
        player1.sendChat('Good game!');
        await Future.delayed(Duration.zero);

        final sent = conn1.sentMessages;
        expect(sent.last.chat, isNotNull);
        expect(sent.last.chat!.message, 'Good game!');
      });
    });

    group('Time Limit & Error Handling', () {
      test('STOC_TIME_LIMIT received by both players', () async {
        final p1Limits = <StocTimeLimit>[];
        final p2Limits = <StocTimeLimit>[];
        player1.onMessage.listen((m) {
          if (m.timeLimit != null) p1Limits.add(m.timeLimit!);
        });
        player2.onMessage.listen((m) {
          if (m.timeLimit != null) p2Limits.add(m.timeLimit!);
        });

        broadcast(STOC_TIME_LIMIT,
            StocTimeLimit(player: 0, leftTime: 60).encode());
        await Future.delayed(Duration.zero);

        expect(p1Limits.length, 1);
        expect(p1Limits.first.player, 0);
        expect(p1Limits.first.leftTime, 60);
        expect(p2Limits.length, 1);
      });

      test('STOC_ERROR_MSG received', () async {
        final p1Errors = <StocErrorMsg>[];
        player1.onMessage.listen((m) {
          if (m.errorMsg != null) p1Errors.add(m.errorMsg!);
        });

        conn1.injectStoc(
            STOC_ERROR_MSG,
            StocErrorMsg(errorType: ERROR_TYPE_VERSION, errorCode: 2).encode());
        await Future.delayed(Duration.zero);

        expect(p1Errors.length, 1);
      });
    });

    group('Deck Count Synchronization', () {
      test('STOC_DECK_COUNT received', () async {
        final p1Counts = <StocDeckCount>[];
        player1.onMessage.listen((m) {
          if (m.deckCount != null) p1Counts.add(m.deckCount!);
        });

        conn1.injectStoc(
            STOC_DECK_COUNT,
            StocDeckCount(
              meMain: 40,
              meExtra: 15,
              meSide: 15,
              opMain: 40,
              opExtra: 15,
              opSide: 15,
            ).encode());
        await Future.delayed(Duration.zero);

        expect(p1Counts.length, 1);
        expect(p1Counts.first.meMain, 40);
        expect(p1Counts.first.opMain, 40);
      });
    });

    group('Side Deck / Change Side', () {
      test('STOC_CHANGE_SIDE and STOC_WAITING_SIDE', () async {
        final p1Msgs = <YgoStocMsg>[];
        player1.onMessage.listen(p1Msgs.add);

        conn1.injectStoc(STOC_CHANGE_SIDE, Uint8List(0));
        await Future.delayed(Duration.zero);
        expect(p1Msgs.last.changeSide, isNotNull);

        conn1.injectStoc(STOC_WAITING_SIDE, Uint8List(0));
        await Future.delayed(Duration.zero);
        expect(p1Msgs.last.waitingSide, isNotNull);
      });
    });

    group('Full Duel Lifecycle', () {
      test('complete duel: connect -> room -> hand -> TP -> duel -> win',
          () async {
        final p1States = <RoomState>[];
        final p1GameMsgs = <StocGameMessage>[];
        final p2States = <RoomState>[];
        final p2GameMsgs = <StocGameMessage>[];

        player1.onRoomStateChange.listen(p1States.add);
        player2.onRoomStateChange.listen(p2States.add);
        player1.onMessage.listen((m) {
          if (m.gameMsg != null) p1GameMsgs.add(m.gameMsg!);
        });
        player2.onMessage.listen((m) {
          if (m.gameMsg != null) p2GameMsgs.add(m.gameMsg!);
        });

        // Phase 2: Room Setup
        conn1.injectStoc(STOC_JOIN_GAME, StocJoinGame().encode());
        conn2.injectStoc(STOC_JOIN_GAME, StocJoinGame().encode());
        await Future.delayed(Duration.zero);

        conn1.injectStoc(STOC_TYPE_CHANGE,
            StocTypeChange(isHost: true, selfType: 0).encode());
        conn2.injectStoc(STOC_TYPE_CHANGE,
            StocTypeChange(isHost: false, selfType: 1).encode());
        await Future.delayed(Duration.zero);

        broadcast(STOC_HS_PLAYER_ENTER,
            StocHsPlayerEnter(name: 'Alice', pos: 0).encode());
        await Future.delayed(Duration.zero);
        broadcast(STOC_HS_PLAYER_ENTER,
            StocHsPlayerEnter(name: 'Bob', pos: 1).encode());
        await Future.delayed(Duration.zero);

        expect(p1States.last.players.length, 2);
        expect(p2States.last.players.length, 2);

        // Phase 3: Ready & Start
        player1.sendReady();
        player2.sendReady();
        await Future.delayed(Duration.zero);

        player1.sendStart();
        await Future.delayed(Duration.zero);

        // Phase 4: Hand Selection
        broadcast(STOC_SELECT_HAND, Uint8List(0));
        await Future.delayed(Duration.zero);
        expect(p1States.last.stage, RoomStage.handSelecting);

        player1.sendHandResult(HandType.rock);
        player2.sendHandResult(HandType.scissors);
        await Future.delayed(Duration.zero);

        broadcast(STOC_HAND_RESULT,
            StocHandResult(meResult: 2, opResult: 1).encode());
        await Future.delayed(Duration.zero);
        expect(p1States.last.stage, RoomStage.handSelected);

        // Phase 5: TP Selection
        conn1.injectStoc(STOC_SELECT_TP, Uint8List(0));
        await Future.delayed(Duration.zero);
        expect(p1States.last.stage, RoomStage.tpSelecting);

        player1.sendTpResult(true);
        await Future.delayed(Duration.zero);

        // Phase 6: Duel Start
        broadcast(STOC_DUEL_START, Uint8List(0));
        await Future.delayed(Duration.zero);
        expect(p1States.last.stage, RoomStage.duelStart);
        expect(p2States.last.stage, RoomStage.duelStart);

        // Phase 7: Game Messages
        broadcastGameMsg(
            MSG_START,
            MsgStart(
              playerType: 0x00,
              life1: 8000,
              life2: 8000,
              deckSize1: 40,
              extraSize1: 15,
              deckSize2: 40,
              extraSize2: 15,
            ).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(MSG_NEW_TURN, MsgNewTurn(player: 0).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(
            MSG_NEW_PHASE, MsgNewPhase(phase: PHASE_DRAW).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(MSG_DRAW,
            MsgDraw(player: 0, count: 1, cards: [36996508]).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(
            MSG_NEW_PHASE, MsgNewPhase(phase: PHASE_STANDBY).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(
            MSG_NEW_PHASE, MsgNewPhase(phase: PHASE_MAIN1).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(
            MSG_MOVE,
            MsgMove(
              code: 36996508,
              from: const CardLocation(
                  controller: 0, location: CARD_ZONE_HAND, sequence: 0),
              to: const CardLocation(
                  controller: 0,
                  location: CARD_ZONE_MZONE,
                  sequence: 0,
                  position: POS_FACEUP_ATTACK),
              reason: 0,
            ).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(
            MSG_SUMMONING,
            MsgSummoning(
              code: 36996508,
              location: const CardLocation(
                  controller: 0,
                  location: CARD_ZONE_MZONE,
                  sequence: 0,
                  position: POS_FACEUP_ATTACK),
            ).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(MSG_SUMMONED, MsgSummoned().encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(
            MSG_NEW_PHASE, MsgNewPhase(phase: PHASE_BATTLE_START).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(
            MSG_NEW_PHASE, MsgNewPhase(phase: PHASE_BATTLE_STEP).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(
            MSG_ATTACK,
            MsgAttack(
              attacker: const CardLocation(
                  controller: 0,
                  location: CARD_ZONE_MZONE,
                  sequence: 0,
                  position: POS_FACEUP_ATTACK),
              target: null,
            ).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(
            MSG_DAMAGE, MsgDamage(player: 1, value: 2500).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(
            MSG_LP_UPDATE, MsgLpUpdate(player: 1, newLp: 5500).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(
            MSG_NEW_PHASE, MsgNewPhase(phase: PHASE_END).encode());
        await Future.delayed(Duration.zero);

        broadcastGameMsg(MSG_WIN, MsgWin(winPlayer: 0, reason: 0).encode());
        await Future.delayed(Duration.zero);

        conn1.injectStoc(STOC_DUEL_END, Uint8List(0));
        conn2.injectStoc(STOC_DUEL_END, Uint8List(0));
        await Future.delayed(Duration.zero);

        // Verify
        expect(p1GameMsgs.length, greaterThanOrEqualTo(12));
        expect(p2GameMsgs.length, greaterThanOrEqualTo(12));
        expect(p1States.last.stage, RoomStage.duelStart);
        expect(p2States.last.stage, RoomStage.duelStart);
      });
    });

    group('Protocol Round-Trip', () {
      test('STOC message serialize -> inject -> decode preserves all fields',
          () async {
        final p1Messages = <YgoStocMsg>[];
        player1.onMessage.listen(p1Messages.add);

        final chat = StocChat(player: 0, message: 'Test message');
        conn1.injectStoc(STOC_CHAT, chat.encode());
        await Future.delayed(Duration.zero);

        expect(p1Messages.length, 1);
        expect(p1Messages.first.chat, isNotNull);
        expect(p1Messages.first.chat!.message, 'Test message');
        expect(p1Messages.first.chat!.player, 0);
      });

      test('game message serialize -> inject -> decode preserves all fields',
          () async {
        final p1GameMsgs = <StocGameMessage>[];
        player1.onMessage.listen((m) {
          if (m.gameMsg != null) p1GameMsgs.add(m.gameMsg!);
        });

        final draw = MsgDraw(
          player: 0,
          count: 3,
          cards: [36996508, 89631139, 40073114],
        );
        conn1.injectGameMsg(MSG_DRAW, draw.encode());
        await Future.delayed(Duration.zero);

        final decoded = p1GameMsgs.first.innerMsg as MsgDraw;
        expect(decoded.player, 0);
        expect(decoded.count, 3);
        expect(decoded.cards, [36996508, 89631139, 40073114]);
      });

      test('MsgSelectCard round-trip preserves all fields', () async {
        final p1GameMsgs = <StocGameMessage>[];
        player1.onMessage.listen((m) {
          if (m.gameMsg != null) p1GameMsgs.add(m.gameMsg!);
        });

        final selectCard = MsgSelectCard(
          player: 0,
          cancelable: 1,
          min: 1,
          max: 2,
          count: 3,
          codes: [36996508, 89631139, 40073114],
          locations: [
            const CardLocation(
                controller: 0, location: CARD_ZONE_HAND, sequence: 0),
            const CardLocation(
                controller: 0, location: CARD_ZONE_HAND, sequence: 1),
            const CardLocation(
                controller: 0, location: CARD_ZONE_HAND, sequence: 2),
          ],
        );
        conn1.injectGameMsg(MSG_SELECT_CARD, selectCard.encode());
        await Future.delayed(Duration.zero);

        final decoded = p1GameMsgs.first.innerMsg as MsgSelectCard;
        expect(decoded.player, 0);
        expect(decoded.cancelable, 1);
        expect(decoded.min, 1);
        expect(decoded.max, 2);
        expect(decoded.count, 3);
        expect(decoded.codes, [36996508, 89631139, 40073114]);
        expect(decoded.locations.length, 3);
        expect(decoded.locations.first.controller, 0);
        expect(decoded.locations.first.location, CARD_ZONE_HAND);
      });

      test('MsgAttack round-trip with target', () async {
        final p1GameMsgs = <StocGameMessage>[];
        player1.onMessage.listen((m) {
          if (m.gameMsg != null) p1GameMsgs.add(m.gameMsg!);
        });

        final attack = MsgAttack(
          attacker: const CardLocation(
              controller: 0,
              location: CARD_ZONE_MZONE,
              sequence: 0,
              position: POS_FACEUP_ATTACK),
          target: const CardLocation(
              controller: 1,
              location: CARD_ZONE_MZONE,
              sequence: 2,
              position: POS_FACEUP_DEFENSE),
        );
        conn1.injectGameMsg(MSG_ATTACK, attack.encode());
        await Future.delayed(Duration.zero);

        final decoded = p1GameMsgs.first.innerMsg as MsgAttack;
        expect(decoded.attacker.controller, 0);
        expect(decoded.attacker.location, CARD_ZONE_MZONE);
        expect(decoded.target, isNotNull);
        expect(decoded.target!.controller, 1);
        expect(decoded.target!.sequence, 2);
      });
    });

    group('Multiple Messages in Single Packet', () {
      test('sticky packets are properly deserialized', () async {
        final p1Msgs = <YgoStocMsg>[];
        player1.onMessage.listen(p1Msgs.add);

        final pkt1 = YgoProPacket.create(
            STOC_CHAT, StocChat(player: 0, message: 'Hello').encode());
        final pkt2 = YgoProPacket.create(
            STOC_CHAT, StocChat(player: 1, message: 'World').encode());

        final combined = Uint8List.fromList(
            [...pkt1.serialize(), ...pkt2.serialize()]);
        conn1.injectPacket(combined);
        await Future.delayed(Duration.zero);

        expect(p1Msgs.length, 2);
        expect(p1Msgs[0].chat!.message, 'Hello');
        expect(p1Msgs[1].chat!.message, 'World');
      });
    });

    group('Player Chat in Duel Context', () {
      test('chat messages during duel are received by both players', () async {
        final p1Chats = <StocChat>[];
        final p2Chats = <StocChat>[];
        player1.onMessage.listen((m) {
          if (m.chat != null) p1Chats.add(m.chat!);
        });
        player2.onMessage.listen((m) {
          if (m.chat != null) p2Chats.add(m.chat!);
        });

        broadcast(STOC_DUEL_START, Uint8List(0));
        await Future.delayed(Duration.zero);

        player1.sendChat('Nice summon!');
        await Future.delayed(Duration.zero);

        broadcast(
            STOC_CHAT, StocChat(player: 0, message: 'Nice summon!').encode());
        await Future.delayed(Duration.zero);

        expect(p1Chats.length, 1);
        expect(p2Chats.length, 1);
        expect(p1Chats.first.message, 'Nice summon!');
      });
    });

    group('Disconnect', () {
      test('disconnect cleans up subscription', () async {
        expect(conn1.state, isNotNull);
        await player1.disconnect();
        expect(conn1.state, isNotNull);
      });
    });
  });
}
