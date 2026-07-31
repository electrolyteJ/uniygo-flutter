import 'dart:async';
import 'dart:developer' as console;
import 'dart:typed_data';

import 'package:duelink/duelink.dart';

import 'online_connection.dart';

/// 在线决斗服务实现。
class OnlineDuelServiceImpl implements IDuelService {
  final DuelConnection _connection = OnlineConnection();
  final _messageController = StreamController<YgoStocMsg>.broadcast();
  final _stateController = StreamController<RoomState>.broadcast();
  RoomState _roomState = const RoomNotJoined();
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
    _roomState = const RoomNotJoined();
    _stateController.add(_roomState);
  }

  // ── 消息处理 ──

  void _handleRawData(Uint8List data) {
    final packets = YgoProPacket.deserialize(data);
    for (final packet in packets) {
      final stoc = adaptStoc(packet);
      _messageController.add(stoc);
      _applyStoc(stoc);
    }
  }

  void _applyStoc(YgoStocMsg stoc) {
    if (stoc.joinGame != null) _onJoinGame(stoc.joinGame!);
    else if (stoc.typeChange != null) _onTypeChange(stoc.typeChange!);
    else if (stoc.hsPlayerEnter != null) _onPlayerEnter(stoc.hsPlayerEnter!);
    else if (stoc.hsPlayerChange != null) _onPlayerChange(stoc.hsPlayerChange!);
    else if (stoc.hsWatchChange != null) _onWatchChange(stoc.hsWatchChange!);
    else if (stoc.selectHand != null) _onSelectHand();
    else if (stoc.handResult != null) _onHandResult(stoc.handResult!);
    else if (stoc.selectTp != null) _onSelectTp();
    else if (stoc.gameMsg != null && stoc.gameMsg!.func == MSG_START) _onTpSelected();
    else if (stoc.duelStart != null) _onDuelStart();
    else if (stoc.duelEnd != null) _onDuelEnd();
    else if (stoc.changeSide != null) _onChangeSide();
    else if (stoc.waitingSide != null) _onWaitingSide();

    _stateController.add(_roomState);
  }

  // ── 状态转换 handler ──

  void _onJoinGame(StocJoinGame m) {
    console.log('RoomState: JOIN_GAME → accumulating options');
    // 累积 options，等待 TypeChange 合并后生成 InLobby
    _pendingOptions = m.toRoomOptions();
  }

  RoomOptions? _pendingOptions;

  void _onTypeChange(StocTypeChange m) {
    final selfType = m.selfType == 7
        ? SelfType.observer
        : m.selfType == 0
            ? SelfType.player1
            : SelfType.player2;
    console.log('RoomState: TYPE_CHANGE → RoomInLobby self:$selfType host:${m.isHost}');
    _roomState = RoomInLobby(
      players: _playersOf(_roomState),
      observerCount: _obsOf(_roomState),
      selfType: selfType,
      isHost: m.isHost,
      options: _pendingOptions ?? const RoomOptions(),
    );
    _pendingOptions = null;
  }

  void _onPlayerEnter(StocHsPlayerEnter m) {
    console.log('RoomState: PLAYER_ENTER ${m.name} pos:${m.pos}');
    final updated = List<RoomPlayer>.from(_playersOf(_roomState));
    updated.add(RoomPlayer(name: m.name, pos: m.pos));
    _setPlayers(updated);
  }

  void _onPlayerChange(StocHsPlayerChange m) {
    console.log('RoomState: PLAYER_CHANGE pos:${m.pos} state:${m.state}');
    final updated = List<RoomPlayer>.from(_playersOf(_roomState));
    // state 0-3 = move-slots, 8 = toObserver, 9 = ready, 10 = notReady, 11 = leave
    if (m.state == 11 || m.state == 8) {
      updated.removeWhere((p) => p.pos == m.pos);
      _roomState = _withPlayers(updated);
      if (m.state == 8) _roomState = _withObs(_obsOf(_roomState) + 1);
    } else if (m.state == 9 || m.state == 10) {
      final idx = updated.indexWhere((p) => p.pos == m.pos);
      if (idx >= 0) updated[idx] = updated[idx].copyWith(ready: m.state == 9);
      _setPlayers(updated);
    } else if (m.state < 4) {
      final idx = updated.indexWhere((p) => p.pos == m.pos);
      if (idx >= 0) updated[idx] = updated[idx].copyWith(pos: m.state);
      _setPlayers(updated);
    }
  }

  void _onWatchChange(StocHsWatchChange m) {
    console.log('RoomState: WATCH_CHANGE → ${m.count}');
    _roomState = _withObs(m.count);
  }

  void _onSelectHand() {
    console.log('RoomState: SELECT_HAND → RoomSelectingHand');
    _roomState = RoomSelectingHand(
      players: _playersOf(_roomState),
      observerCount: _obsOf(_roomState),
    );
  }

  void _onHandResult(StocHandResult m) {
    console.log('RoomState: HAND_RESULT → RoomSelectingTurn');
    _roomState = RoomSelectingTurn(
      players: _playersOf(_roomState),
      observerCount: _obsOf(_roomState),
      myHand: m.meResult,
      opponentHand: m.opResult,
    );
  }

  void _onSelectTp() {
    console.log('RoomState: SELECT_TP → RoomSelectingTurn');
    // 如果还没进入 SelectingTurn（直接收到 SELECT_TP 的情况）
    if (_roomState is! RoomSelectingTurn) {
      _roomState = RoomSelectingTurn(
        players: _playersOf(_roomState),
        observerCount: _obsOf(_roomState),
        myHand: 0,
        opponentHand: 0,
      );
    }
  }

  void _onTpSelected() {
    console.log('RoomState: tp selected → RoomPreDuel');
    final isFirst = _roomState is RoomInLobby
        ? (_roomState as RoomInLobby).selfType == SelfType.player1
        : true;
    _roomState = RoomPreDuel(
      players: _playersOf(_roomState),
      observerCount: _obsOf(_roomState),
      isFirstTurn: isFirst,
    );
  }

  void _onDuelStart() {
    console.log('RoomState: DUEL_START → RoomInDuel');
    _roomState = RoomInDuel(
      players: _playersOf(_roomState),
      observerCount: _obsOf(_roomState),
    );
  }

  void _onDuelEnd() {
    console.log('RoomState: DUEL_END → RoomDuelEnded');
    _roomState = RoomDuelEnded(
      players: _playersOf(_roomState),
      observerCount: _obsOf(_roomState),
    );
  }

  void _onChangeSide() {
    console.log('RoomState: CHANGE_SIDE → RoomSideDecking');
    _roomState = RoomSideDecking(
      players: _playersOf(_roomState),
      observerCount: _obsOf(_roomState),
    );
  }

  void _onWaitingSide() {
    // companion state, doesn't change the top-level state
    console.log('RoomState: WAITING_SIDE (no state change)');
  }

  // ── 辅助 ──

  static List<RoomPlayer> _playersOf(RoomState s) => s.players;
  static int _obsOf(RoomState s) => s.observerCount;

  void _setPlayers(List<RoomPlayer> players) {
    _roomState = _withPlayers(players);
  }

  RoomState _withPlayers(List<RoomPlayer> players) {
    return switch (_roomState) {
      RoomNotJoined()       => RoomNotJoined(),
      RoomInLobby(:final selfType, :final isHost, :final options) =>
        RoomInLobby(players: players, observerCount: _obsOf(_roomState),
            selfType: selfType, isHost: isHost, options: options),
      RoomSelectingHand()   => RoomSelectingHand(players: players, observerCount: _obsOf(_roomState)),
      RoomSelectingTurn(:final myHand, :final opponentHand) =>
        RoomSelectingTurn(players: players, observerCount: _obsOf(_roomState),
            myHand: myHand, opponentHand: opponentHand),
      RoomPreDuel(:final isFirstTurn) =>
        RoomPreDuel(players: players, observerCount: _obsOf(_roomState), isFirstTurn: isFirstTurn),
      RoomInDuel()          => RoomInDuel(players: players, observerCount: _obsOf(_roomState)),
      RoomDuelEnded()       => RoomDuelEnded(players: players, observerCount: _obsOf(_roomState)),
      RoomSideDecking()     => RoomSideDecking(players: players, observerCount: _obsOf(_roomState)),
    };
  }

  RoomState _withObs(int count) {
    return switch (_roomState) {
      RoomNotJoined()       => RoomNotJoined(),
      RoomInLobby(:final selfType, :final isHost, :final options) =>
        RoomInLobby(players: _playersOf(_roomState), observerCount: count,
            selfType: selfType, isHost: isHost, options: options),
      RoomSelectingHand()   => RoomSelectingHand(players: _playersOf(_roomState), observerCount: count),
      RoomSelectingTurn(:final myHand, :final opponentHand) =>
        RoomSelectingTurn(players: _playersOf(_roomState), observerCount: count,
            myHand: myHand, opponentHand: opponentHand),
      RoomPreDuel(:final isFirstTurn) =>
        RoomPreDuel(players: _playersOf(_roomState), observerCount: count, isFirstTurn: isFirstTurn),
      RoomInDuel()          => RoomInDuel(players: _playersOf(_roomState), observerCount: count),
      RoomDuelEnded()       => RoomDuelEnded(players: _playersOf(_roomState), observerCount: count),
      RoomSideDecking()     => RoomSideDecking(players: _playersOf(_roomState), observerCount: count),
    };
  }

  // ── Send ──

  void _send(YgoCtosMsg msg) {
    console.log('Sending: $msg');
    final packet = adaptCtos(msg);
    _connection.send(packet.serialize());
  }

  @override
  void setPlayerName(String name) {
    _send(YgoCtosMsg.playerInfo(CtosPlayerInfo(name: name)));
  }

  @override
  void enterRoom(String password) {
    _send(YgoCtosMsg.joinGame(
      CtosJoinGame(version: 4962, gameId: 0, passwd: password),
    ));
  }

  @override
  void submitDeck(Uint8List mainDeck, Uint8List extraDeck) {
    final mainCards = _bytesToInts(mainDeck);
    final extraCards = _bytesToInts(extraDeck);
    _send(YgoCtosMsg.updateDeck(
      CtosUpdateDeck(mainDeck: mainCards, extraDeck: extraCards, sideDeck: []),
    ));
  }

  static List<int> _bytesToInts(Uint8List bytes) {
    final bd = ByteData.view(bytes.buffer, bytes.offsetInBytes);
    return List.generate(bytes.length ~/ 4, (i) => bd.getInt32(i * 4, Endian.little));
  }

  @override void ready()             => _send(YgoCtosMsg.hsReady());
  @override void unready()           => _send(YgoCtosMsg.hsNotReady());
  @override void startDuel()         => _send(YgoCtosMsg.hsStart());
  @override void kickPlayer(int pos) => _send(YgoCtosMsg.hsKick(pos));
  @override void becomeObserver()    => _send(YgoCtosMsg.hsToObserver());
  @override void becomeDuelist()     => _send(YgoCtosMsg.hsToDuelist());
  @override void confirmTime()       => _send(YgoCtosMsg.timeConfirm());
  @override void surrender()         => _send(YgoCtosMsg.surrender());

  @override
  void sendChat(String message) =>
      _send(YgoCtosMsg.chat(CtosChat(message: message)));

  @override
  void chooseHand(HandType hand) =>
      _send(YgoCtosMsg.handResult(CtosHandResult(hand: hand.value)));

  @override
  void chooseTurnOrder(bool goFirst) {
    _send(YgoCtosMsg.tpResult(CtosTpResult(first: goFirst)));
    // optimistic: 提前进入 PreDuel
    if (_roomState is RoomSelectingTurn) {
      _roomState = RoomPreDuel(
        players: _playersOf(_roomState),
        observerCount: _obsOf(_roomState),
        isFirstTurn: goFirst,
      );
      _stateController.add(_roomState);
    }
  }

  @override
  void playGameResponse(CtosGameMsgResponse response) =>
      _send(YgoCtosMsg.response(response));

  @override
  Stream<YgoStocMsg> get onServerMessage => _messageController.stream;

  @override
  Stream<RoomState> get onRoomStateChange => _stateController.stream;
}
