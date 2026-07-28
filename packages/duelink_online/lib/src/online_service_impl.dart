import 'dart:async';
import 'dart:developer' as console;
import 'dart:typed_data';

import 'package:duelink/duelink.dart';

import 'online_connection.dart';

/// 在线DuelService实现
class OnlineDuelServiceImpl implements IDuelService {
  final DuelConnection _connection = OnlineConnection();
  final _messageController = StreamController<YgoStocMsg>.broadcast();
  final _stateController = StreamController<RoomState>.broadcast();
  RoomState _roomState = const RoomState();
  StreamSubscription? _connectionSub;
  ConnectionState _connState = ConnectionState.disconnected;

  OnlineDuelServiceImpl() {
    _connection.state.listen((state) {
      _connState = state;
      if (state == ConnectionState.disconnected) {
        _connectionSub?.cancel();
      }
    });
  }

  @override
  ConnectionState get connectionState => _connState;

  @override
  Future<void> connect(String address, int port) async {
    await _connection.connect(address, port);
    _connectionSub = _connection.messages.listen(_handleRawData);
  }

  @override
  Future<void> disconnect() async {
    await _connectionSub?.cancel();
    await _connection.disconnect();
  }

  void _handleRawData(Uint8List data) {
    final packets = YgoProPacket.deserialize(data);
    for (final packet in packets) {
      final stoc = adaptStoc(packet);
      _messageController.add(stoc);
      _updateRoomState(stoc);
    }
  }

  void _updateRoomState(YgoStocMsg stoc) {
    RoomState next = _roomState;
    if (stoc.joinGame != null) {
      console.log('RoomState Update: Joined game');
      next = next.copyWith(
        joined: true,
        roomOptions: stoc.joinGame!.toRoomOptions(),
      );
    } else if (stoc.typeChange != null) {
      final change = stoc.typeChange!;
      console.log(
        'RoomState Update: TypeChange selfType=${change.selfType} isHost=${change.isHost}',
      );
      final selfType = change.selfType == 7
          ? SelfType.observer
          : change.selfType == 0
          ? SelfType.player1
          : SelfType.player2;
      // Determine if this player is first turn based on selfType
      // player1 = first turn (controller 0), player2 = second turn (controller 1)
      final isFirstTurn = change.selfType == 0;
      next = next.copyWith(
        selfType: selfType,
        isHost: change.isHost,
        isFirstTurn: isFirstTurn,
      );
    } else if (stoc.hsPlayerEnter != null) {
      final enter = stoc.hsPlayerEnter!;
      console.log(
        'RoomState Update: PlayerEnter name=${enter.name} pos=${enter.pos}',
      );
      final updated = List<PlayerInfo>.from(next.players);
      updated.add(PlayerInfo(name: enter.name, pos: enter.pos));
      next = next.copyWith(players: updated);
    } else if (stoc.hsPlayerChange != null) {
      final change = stoc.hsPlayerChange!;
      console.log(
        'RoomState Update: PlayerChange pos=${change.pos} state=${change.state}',
      );
      final updated = List<PlayerInfo>.from(next.players);
      // state: 0-3=move, 8=toObserver, 9=ready, 10=notReady, 11=leave
      if (change.state == 11 || change.state == 8) {
        // Player left or moved to observer — remove from player list
        updated.removeWhere((p) => p.pos == change.pos);
        next = next.copyWith(
          players: updated,
          observerCount: change.state == 8
              ? next.observerCount + 1
              : next.observerCount,
        );
      } else if (change.state == 9 || change.state == 10) {
        // Ready / Not ready
        final idx = updated.indexWhere((p) => p.pos == change.pos);
        if (idx >= 0) {
          updated[idx] = updated[idx].copyWith(ready: change.state == 9);
        }
        next = next.copyWith(players: updated);
      } else if (change.state < 4) {
        // Player moved to a different slot
        final idx = updated.indexWhere((p) => p.pos == change.pos);
        if (idx >= 0) {
          updated[idx] = updated[idx].copyWith(pos: change.state);
        }
        next = next.copyWith(players: updated);
      }
    } else if (stoc.hsWatchChange != null) {
      console.log(
        'RoomState Update: WatchChange count=${stoc.hsWatchChange!.count}',
      );
      next = next.copyWith(observerCount: stoc.hsWatchChange!.count);
    } else if (stoc.selectHand != null) {
      console.log('RoomState Update: Stage -> HandSelecting');
      next = next.copyWith(stage: RoomStage.handSelecting);
    } else if (stoc.handResult != null) {
      final res = stoc.handResult!;
      console.log(
        'RoomState Update: HandResult me=${res.meResult} op=${res.opResult}',
      );
      next = next.copyWith(
        stage: RoomStage.handSelected,
        myHandResult: res.meResult,
        opponentHandResult: res.opResult,
      );
    } else if (stoc.selectTp != null) {
      console.log('RoomState Update: Stage -> TpSelecting');
      next = next.copyWith(stage: RoomStage.tpSelecting);
    } else if (stoc.gameMsg != null && stoc.gameMsg!.func == MSG_START) {
      console.log('RoomState Update: Stage -> TpSelected (from MSG_START)');
      next = next.copyWith(stage: RoomStage.tpSelected);
    } else if (stoc.duelStart != null) {
      console.log('RoomState Update: Stage -> DuelStart');
      next = next.copyWith(stage: RoomStage.duelStart);
    }else {
      console.log('RoomState Update: No relevant changes for this message $stoc');
    }
    _roomState = next;
    _stateController.add(next);
  }

  // ── Send methods ──

  void _send(YgoCtosMsg msg) {
    console.log('Sending message: $msg');
    final packet = adaptCtos(msg);
    _connection.send(packet.serialize());
  }

  @override
  void sendPlayerInfo(String name) =>
      _send(YgoCtosMsg.playerInfo(CtosPlayerInfo(name: name)));

  @override
  void sendJoinGame(int gameId, String? passwd) => _send(
    YgoCtosMsg.joinGame(
      CtosJoinGame(version: 4962, gameId: gameId, passwd: passwd ?? ''),
    ),
  );

  @override
  void sendUpdateDeck(Uint8List mainDeck, Uint8List extraDeck) {
    final mainCards = <int>[];
    final extraCards = <int>[];
    final mainBd = ByteData.view(mainDeck.buffer, mainDeck.offsetInBytes);
    for (int i = 0; i < mainDeck.length; i += 4) {
      if (i + 4 <= mainDeck.length) {
        mainCards.add(mainBd.getInt32(i, Endian.little));
      }
    }
    final extraBd = ByteData.view(extraDeck.buffer, extraDeck.offsetInBytes);
    for (int i = 0; i < extraDeck.length; i += 4) {
      if (i + 4 <= extraDeck.length) {
        extraCards.add(extraBd.getInt32(i, Endian.little));
      }
    }
    _send(
      YgoCtosMsg.updateDeck(
        CtosUpdateDeck(
          mainDeck: mainCards,
          extraDeck: extraCards,
          sideDeck: [],
        ),
      ),
    );
  }

  @override
  void sendReady() => _send(YgoCtosMsg.hsReady());

  @override
  void sendNotReady() => _send(YgoCtosMsg.hsNotReady());

  @override
  void sendStart() => _send(YgoCtosMsg.hsStart());

  @override
  void sendKick(int pos) => _send(YgoCtosMsg.hsKick(pos));

  @override
  void sendToObserver() => _send(YgoCtosMsg.hsToObserver());

  @override
  void sendToDuelist() => _send(YgoCtosMsg.hsToDuelist());

  @override
  void sendTimeConfirm() => _send(YgoCtosMsg.timeConfirm());

  @override
  void sendSurrender() => _send(YgoCtosMsg.surrender());

  @override
  void sendChat(String message) =>
      _send(YgoCtosMsg.chat(CtosChat(message: message)));

  @override
  void sendHandResult(HandType hand) =>
      _send(YgoCtosMsg.handResult(CtosHandResult(hand: hand.value)));

  @override
  void sendTpResult(bool first) {
    _send(YgoCtosMsg.tpResult(CtosTpResult(first: first)));
    _roomState = _roomState.copyWith(
      stage: RoomStage.tpSelected,
      isFirstTurn: first,
    );
    _stateController.add(_roomState);
  }

  @override
  void sendResponse(CtosGameMsgResponse response) =>
      _send(YgoCtosMsg.response(response));

  @override
  Stream<YgoStocMsg> get onMessage => _messageController.stream;

  @override
  Stream<RoomState> get onRoomStateChange => _stateController.stream;
}
