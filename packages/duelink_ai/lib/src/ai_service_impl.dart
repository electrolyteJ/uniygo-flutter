import 'dart:async';
import 'dart:typed_data';

import 'package:duelink/duelink.dart';

import 'ai_connection.dart';

/// AI 本地决斗服务实现。
class AiDuelServiceImpl implements IDuelService {
  final DuelConnection _connection;
  final _messageController = StreamController<YgoStocMsg>.broadcast();
  final _stateController = StreamController<RoomState>.broadcast();
  RoomState _roomState = const RoomNotJoined();
  StreamSubscription? _connectionSub;
  ConnectionState _connState = ConnectionState.disconnected;

  AiDuelServiceImpl({DuelConnection? connection})
      : _connection = connection ?? AiConnection() {
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
    _roomState = const RoomNotJoined();
    _stateController.add(_roomState);
  }

  void _handleRawData(Uint8List data) {
    final packets = YgoProPacket.deserialize(data);
    for (final packet in packets) {
      final stoc = adaptStoc(packet);
      _messageController.add(stoc);
      _applyStoc(stoc);
    }
  }

  void _applyStoc(YgoStocMsg stoc) {
    if (stoc.joinGame != null) {
      _pendingOptions = stoc.joinGame!.toRoomOptions();
    } else if (stoc.typeChange != null) {
      final m = stoc.typeChange!;
      final selfType = m.selfType == 7
          ? SelfType.observer : m.selfType == 0
          ? SelfType.player1 : SelfType.player2;
      _roomState = RoomInLobby(
        players: _p, observerCount: _o,
        selfType: selfType, isHost: m.isHost,
        options: _pendingOptions ?? const RoomOptions(),
      );
      _pendingOptions = null;
    } else if (stoc.hsPlayerEnter != null) {
      final m = stoc.hsPlayerEnter!;
      final updated = List<RoomPlayer>.from(_p);
      updated.add(RoomPlayer(name: m.name, pos: m.pos));
      _setPlayers(updated);
    } else if (stoc.hsPlayerChange != null) {
      final m = stoc.hsPlayerChange!;
      final updated = List<RoomPlayer>.from(_p);
      if (m.state == 11 || m.state == 8) {
        updated.removeWhere((p) => p.pos == m.pos);
        _roomState = _withP(updated);
        if (m.state == 8) _roomState = _withO(_o + 1);
      } else if (m.state == 9 || m.state == 10) {
        final idx = updated.indexWhere((p) => p.pos == m.pos);
        if (idx >= 0) updated[idx] = updated[idx].copyWith(ready: m.state == 9);
        _setPlayers(updated);
      } else if (m.state < 4) {
        final idx = updated.indexWhere((p) => p.pos == m.pos);
        if (idx >= 0) updated[idx] = updated[idx].copyWith(pos: m.state);
        _setPlayers(updated);
      }
    } else if (stoc.hsWatchChange != null) {
      _roomState = _withO(stoc.hsWatchChange!.count);
    } else if (stoc.selectHand != null) {
      _roomState = RoomSelectingHand(players: _p, observerCount: _o);
    } else if (stoc.handResult != null) {
      final m = stoc.handResult!;
      _roomState = RoomSelectingTurn(players: _p, observerCount: _o, myHand: m.meResult, opponentHand: m.opResult);
    } else if (stoc.selectTp != null) {
      if (_roomState is! RoomSelectingTurn) {
        _roomState = RoomSelectingTurn(players: _p, observerCount: _o, myHand: 0, opponentHand: 0);
      }
    } else if (stoc.gameMsg != null && stoc.gameMsg!.func == MSG_START) {
      final isFirst = _roomState is RoomInLobby
          ? (_roomState as RoomInLobby).selfType == SelfType.player1 : true;
      _roomState = RoomPreDuel(players: _p, observerCount: _o, isFirstTurn: isFirst);
    } else if (stoc.duelStart != null) {
      _roomState = RoomInDuel(players: _p, observerCount: _o);
    } else if (stoc.duelEnd != null) {
      _roomState = RoomDuelEnded(players: _p, observerCount: _o);
    } else if (stoc.changeSide != null) {
      _roomState = RoomSideDecking(players: _p, observerCount: _o);
    }

    _stateController.add(_roomState);
  }

  RoomOptions? _pendingOptions;
  List<RoomPlayer> get _p => _roomState.players;
  int get _o => _roomState.observerCount;

  void _setPlayers(List<RoomPlayer> players) {
    _roomState = _withP(players);
  }

  RoomState _withP(List<RoomPlayer> players) {
    return switch (_roomState) {
      RoomNotJoined() => RoomNotJoined(),
      RoomInLobby(:final selfType, :final isHost, :final options) =>
        RoomInLobby(players: players, observerCount: _o, selfType: selfType, isHost: isHost, options: options),
      RoomSelectingHand() => RoomSelectingHand(players: players, observerCount: _o),
      RoomSelectingTurn(:final myHand, :final opponentHand) =>
        RoomSelectingTurn(players: players, observerCount: _o, myHand: myHand, opponentHand: opponentHand),
      RoomPreDuel(:final isFirstTurn) => RoomPreDuel(players: players, observerCount: _o, isFirstTurn: isFirstTurn),
      RoomInDuel() => RoomInDuel(players: players, observerCount: _o),
      RoomDuelEnded() => RoomDuelEnded(players: players, observerCount: _o),
      RoomSideDecking() => RoomSideDecking(players: players, observerCount: _o),
    };
  }

  RoomState _withO(int count) {
    return switch (_roomState) {
      RoomNotJoined() => RoomNotJoined(),
      RoomInLobby(:final selfType, :final isHost, :final options) =>
        RoomInLobby(players: _p, observerCount: count, selfType: selfType, isHost: isHost, options: options),
      RoomSelectingHand() => RoomSelectingHand(players: _p, observerCount: count),
      RoomSelectingTurn(:final myHand, :final opponentHand) =>
        RoomSelectingTurn(players: _p, observerCount: count, myHand: myHand, opponentHand: opponentHand),
      RoomPreDuel(:final isFirstTurn) => RoomPreDuel(players: _p, observerCount: count, isFirstTurn: isFirstTurn),
      RoomInDuel() => RoomInDuel(players: _p, observerCount: count),
      RoomDuelEnded() => RoomDuelEnded(players: _p, observerCount: count),
      RoomSideDecking() => RoomSideDecking(players: _p, observerCount: count),
    };
  }

  void _send(YgoCtosMsg msg) {
    final packet = adaptCtos(msg);
    _connection.send(packet.serialize());
  }

  @override void setPlayerName(String name) =>
      _send(YgoCtosMsg.playerInfo(CtosPlayerInfo(name: name)));

  @override void enterRoom(String password) =>
      _send(YgoCtosMsg.joinGame(CtosJoinGame(version: 4962, gameId: 0, passwd: password)));

  @override void submitDeck(Uint8List mainDeck, Uint8List extraDeck) {
    final bd = ByteData.view(mainDeck.buffer, mainDeck.offsetInBytes);
    final mainCards = List.generate(mainDeck.length ~/ 4, (i) => bd.getInt32(i * 4, Endian.little));
    final eb = ByteData.view(extraDeck.buffer, extraDeck.offsetInBytes);
    final extraCards = List.generate(extraDeck.length ~/ 4, (i) => eb.getInt32(i * 4, Endian.little));
    _send(YgoCtosMsg.updateDeck(CtosUpdateDeck(mainDeck: mainCards, extraDeck: extraCards, sideDeck: [])));
  }

  @override void ready()             => _send(YgoCtosMsg.hsReady());
  @override void unready()           => _send(YgoCtosMsg.hsNotReady());
  @override void startDuel()         => _send(YgoCtosMsg.hsStart());
  @override void kickPlayer(int pos) => _send(YgoCtosMsg.hsKick(pos));
  @override void becomeObserver()    => _send(YgoCtosMsg.hsToObserver());
  @override void becomeDuelist()     => _send(YgoCtosMsg.hsToDuelist());
  @override void confirmTime()       => _send(YgoCtosMsg.timeConfirm());
  @override void surrender()         => _send(YgoCtosMsg.surrender());

  @override void sendChat(String m) =>
      _send(YgoCtosMsg.chat(CtosChat(message: m)));

  @override void chooseHand(HandType hand) =>
      _send(YgoCtosMsg.handResult(CtosHandResult(hand: hand.value)));

  @override void chooseTurnOrder(bool goFirst) {
    _send(YgoCtosMsg.tpResult(CtosTpResult(first: goFirst)));
    if (_roomState is RoomSelectingTurn) {
      _roomState = RoomPreDuel(players: _p, observerCount: _o, isFirstTurn: goFirst);
      _stateController.add(_roomState);
    }
  }

  @override void playGameResponse(CtosGameMsgResponse r) =>
      _send(YgoCtosMsg.response(r));

  @override Stream<YgoStocMsg> get onServerMessage => _messageController.stream;

  @override Stream<RoomState> get onRoomStateChange => _stateController.stream;
}
