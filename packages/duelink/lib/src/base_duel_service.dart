import 'dart:async';
import 'dart:developer' as console;
import 'dart:typed_data';

import '../duelink.dart';
import 'constants.dart';
import 'iduel_service.dart';
import 'messages/ctos/ctos_chat.dart';
import 'messages/ctos/ctos_game_msg_response.dart';
import 'messages/ctos/ctos_hand_result.dart';
import 'messages/ctos/ctos_join_game.dart';
import 'messages/ctos/ctos_player_info.dart';
import 'messages/ctos/ctos_tp_result.dart';
import 'messages/ctos/ctos_update_deck.dart';
import 'messages/ygo_ctos_msg.dart';
import 'messages/ygo_stoc_msg.dart';
import 'messages/stoc/stoc_hand_result.dart';
import 'messages/stoc/stoc_hs_player_change.dart';
import 'messages/stoc/stoc_hs_player_enter.dart';
import 'messages/stoc/stoc_hs_watch_change.dart';
import 'messages/stoc/stoc_join_game.dart';
import 'messages/stoc/stoc_type_change.dart';
import 'model/room_options.dart';
import 'model/room_player.dart';
import 'model/room_stage.dart';
import 'types.dart';

/// 决斗服务共享实现 — 房间状态机 + 所有 send 方法。
///
/// 子类只需提供 [connection]，其余（连接生命周期、消息解码、
/// [RoomStage] 状态机、发送语义）均在此收敛。
abstract class BaseDuelService implements IDuelService {
  final DuelConnection connection;
  final _messageController = StreamController<YgoStocMsg>.broadcast();
  final _stateController = StreamController<RoomStage>.broadcast();
  RoomStage _roomStage = const RoomNotJoined();
  StreamSubscription? _connectionSub;
  ConnectionState _connState = ConnectionState.disconnected;
  RoomOptions? _pendingOptions;

  BaseDuelService(this.connection) {
    connection.state.listen((state) {
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
    await connection.connect(address, port);
    _connectionSub = connection.messages.listen(_onServerMessage);
  }

  @override
  Future<void> disconnect() async {
    await _connectionSub?.cancel();
    await connection.disconnect();
    _roomStage = const RoomNotJoined();
    _stateController.add(_roomStage);
  }

  // ── 消息处理 ──

  void _onServerMessage(YgoStocMsg stoc) {
    _messageController.add(stoc);
    _applyStoc(stoc);
  }

  void _applyStoc(YgoStocMsg stoc) {
    switch (stoc.protoId) {
      case STOC_JOIN_GAME:      _onJoinGame(stoc.joinGame!); break;
      case STOC_TYPE_CHANGE:    _onTypeChange(stoc.typeChange!); break;
      case STOC_HS_PLAYER_ENTER: _onPlayerEnter(stoc.hsPlayerEnter!); break;
      case STOC_HS_PLAYER_CHANGE: _onPlayerChange(stoc.hsPlayerChange!); break;
      case STOC_HS_WATCH_CHANGE: _onWatchChange(stoc.hsWatchChange!); break;
      case STOC_DUEL_START:     _onDuelStart(); break;
      case STOC_SELECT_HAND:    _onSelectHand(); break;
      case STOC_HAND_RESULT:    _onHandResult(stoc.handResult!); break;
      case STOC_SELECT_TP:      _onSelectTp(); break;
      case STOC_GAME_MSG:
        if (stoc.gameMsg?.func == MSG_START) _onTpSelected(stoc.gameMsg?.innerMsg! as MsgStart);
        break;
      case STOC_DUEL_END:       _onDuelEnd(); break;
      case STOC_CHANGE_SIDE:    _onChangeSide(); break;
      case STOC_WAITING_SIDE:   _onWaitingSide(); break;
    }

    _stateController.add(_roomStage);
  }

  // ── 状态转换 handler ──

  void _onJoinGame(StocJoinGame m) {
    console.log('RoomStage: JOIN_GAME → accumulating options');
    // 累积 options，等待 TypeChange 合并后生成 InLobby
    _pendingOptions = m.toRoomOptions();
  }

  void _onTypeChange(StocTypeChange m) {
    final selfType = m.selfType == 7
        ? SelfType.observer
        : m.selfType == 0
            ? SelfType.player1
            : SelfType.player2;
    console.log('RoomStage: TYPE_CHANGE → RoomInLobby self:$selfType host:${m.isHost}');
    _roomStage = RoomInLobby(
      players: _playersOf(_roomStage),
      observerCount: _obsOf(_roomStage),
      selfType: selfType,
      isHost: m.isHost,
      options: _pendingOptions ?? const RoomOptions(),
    );
    _pendingOptions = null;
  }

  void _onPlayerEnter(StocHsPlayerEnter m) {
    console.log('RoomStage: PLAYER_ENTER ${m.name} pos:${m.pos}');
    final updated = List<RoomPlayer>.from(_playersOf(_roomStage));
    updated.add(RoomPlayer(name: m.name, pos: m.pos));
    _setPlayers(updated);
  }

  void _onPlayerChange(StocHsPlayerChange m) {
    console.log('RoomStage: PLAYER_CHANGE pos:${m.pos} state:${m.state}');
    final updated = List<RoomPlayer>.from(_playersOf(_roomStage));
    final isToObserver =
        m.state == HS_PLAYER_STATE_TO_OBSERVER || m.state == 8;
    final isLeave = m.state == HS_PLAYER_STATE_LEAVE || m.state == 11;
    final isReady = m.state == HS_PLAYER_STATE_READY || m.state == 9;
    final isNotReady = m.state == HS_PLAYER_STATE_NO_READY || m.state == 10;

    // Support both the low-code constants used by local tests (1/2/3/4)
    // and the high-code values emitted by the real online server (8/9/10/11).
    if (isLeave || isToObserver) {
      updated.removeWhere((p) => p.pos == m.pos);
      _roomStage = _withPlayers(updated);
      if (isToObserver) _roomStage = _withObs(_obsOf(_roomStage) + 1);
    } else if (isReady || isNotReady) {
      final idx = updated.indexWhere((p) => p.pos == m.pos);
      if (idx >= 0) updated[idx] = updated[idx].copyWith(ready: isReady);
      _setPlayers(updated);
    } else if (m.state < 4) {
      final idx = updated.indexWhere((p) => p.pos == m.pos);
      if (idx >= 0) updated[idx] = updated[idx].copyWith(pos: m.pos);
      _setPlayers(updated);
    }
  }

  void _onWatchChange(StocHsWatchChange m) {
    console.log('RoomStage: WATCH_CHANGE → ${m.count}');
    _roomStage = _withObs(m.count);
  }

  void _onSelectHand() {
    console.log('RoomStage: SELECT_HAND → RoomSelectingHand');
    _roomStage = RoomSelectingHand(
      players: _playersOf(_roomStage),
      observerCount: _obsOf(_roomStage),
    );
  }

  void _onHandResult(StocHandResult m) {
    console.log('RoomStage: HAND_RESULT → RoomHandResult');
    _roomStage = RoomHandResult(
      players: _playersOf(_roomStage),
      observerCount: _obsOf(_roomStage),
      myHand: m.meResult,
      opponentHand: m.opResult,
    );
  }

  void _onSelectTp() {
    console.log('RoomStage: SELECT_TP → RoomSelectingTurn');
    // 如果还没进入 SelectingTurn（直接收到 SELECT_TP 的情况）
    if (_roomStage is! RoomSelectingTurn) {
      _roomStage = RoomSelectingTurn(players: _playersOf(_roomStage), observerCount: _obsOf(_roomStage));
    }
  }

  void _onTpSelected(MsgStart gameMsg) {
    console.log('RoomStage: tp selected → RoomPreDuel ${gameMsg}');
    _roomStage = RoomInDuel(
      players: _playersOf(_roomStage),
      observerCount: _obsOf(_roomStage),
      isFirstTurn: gameMsg.isFirst,
    );
  }

  void _onDuelStart() {
    console.log('RoomStage: DUEL_START → RoomStartDuel');
    _roomStage = RoomStartDuel(
      players: _playersOf(_roomStage),
      observerCount: _obsOf(_roomStage),
    );
  }

  void _onDuelEnd() {
    console.log('RoomStage: DUEL_END → RoomDuelEnded');
    _roomStage = RoomDuelEnded(
      players: _playersOf(_roomStage),
      observerCount: _obsOf(_roomStage),
    );
  }

  void _onChangeSide() {
    console.log('RoomStage: CHANGE_SIDE → RoomSideDecking');
    _roomStage = RoomSideDecking(
      players: _playersOf(_roomStage),
      observerCount: _obsOf(_roomStage),
    );
  }

  void _onWaitingSide() {
    // companion state, doesn't change the top-level state
    console.log('RoomStage: WAITING_SIDE (no state change)');
  }

  // ── 辅助 ──

  static List<RoomPlayer> _playersOf(RoomStage s) => s.players;
  static int _obsOf(RoomStage s) => s.observerCount;

  void _setPlayers(List<RoomPlayer> players) {
    _roomStage = _withPlayers(players);
  }

  RoomStage _withPlayers(List<RoomPlayer> players) {
    return switch (_roomStage) {
      RoomNotJoined()       => RoomNotJoined(),
      RoomInLobby(:final selfType, :final isHost, :final options) =>
        RoomInLobby(players: players, observerCount: _obsOf(_roomStage),
            selfType: selfType, isHost: isHost, options: options),
      RoomStartDuel()          => RoomStartDuel(players: players, observerCount: _obsOf(_roomStage)),
      RoomSelectingHand()   => RoomSelectingHand(players: players, observerCount: _obsOf(_roomStage)),
      RoomHandResult(:final myHand, :final opponentHand) => RoomHandResult(players: players, observerCount: _obsOf(_roomStage), myHand: myHand, opponentHand: opponentHand),
      RoomSelectingTurn() => RoomSelectingTurn(players: players, observerCount: _obsOf(_roomStage)),
      RoomInDuel(:final isFirstTurn) =>
        RoomInDuel(players: players, observerCount: _obsOf(_roomStage), isFirstTurn: isFirstTurn),
      RoomDuelEnded()       => RoomDuelEnded(players: players, observerCount: _obsOf(_roomStage)),
      RoomSideDecking()     => RoomSideDecking(players: players, observerCount: _obsOf(_roomStage)),
    };
  }

  RoomStage _withObs(int count) {
    return switch (_roomStage) {
      RoomNotJoined()       => RoomNotJoined(),
      RoomInLobby(:final selfType, :final isHost, :final options) =>
        RoomInLobby(players: _playersOf(_roomStage), observerCount: count,
            selfType: selfType, isHost: isHost, options: options),
      RoomStartDuel()          => RoomStartDuel(players: _playersOf(_roomStage), observerCount: count),
      RoomSelectingHand()   => RoomSelectingHand(players: _playersOf(_roomStage), observerCount: count),
      RoomHandResult(:final myHand, :final opponentHand) =>
          RoomHandResult(players: _playersOf(_roomStage), observerCount: count,
              myHand: myHand, opponentHand: opponentHand),
      RoomSelectingTurn() => RoomSelectingTurn(players: _playersOf(_roomStage), observerCount: count),
      RoomInDuel(:final isFirstTurn) =>
        RoomInDuel(players: _playersOf(_roomStage), observerCount: count, isFirstTurn: isFirstTurn),
      RoomDuelEnded()       => RoomDuelEnded(players: _playersOf(_roomStage), observerCount: count),
      RoomSideDecking()     => RoomSideDecking(players: _playersOf(_roomStage), observerCount: count),
    };
  }

  // ── Send ──

  void _send(YgoCtosMsg msg) {
    console.log('Sending: $msg');
    connection.send(msg);
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
    if (_roomStage is RoomSelectingTurn) {
      _roomStage = RoomInDuel(
        players: _playersOf(_roomStage),
        observerCount: _obsOf(_roomStage),
        isFirstTurn: goFirst,
      );
      _stateController.add(_roomStage);
    }
  }

  @override
  void playGameResponse(CtosGameMsgResponse response) =>
      _send(YgoCtosMsg.response(response));

  @override
  Stream<YgoStocMsg> get onServerMessage => _messageController.stream;

  @override
  Stream<RoomStage> get onRoomStageChange => _stateController.stream;
}
