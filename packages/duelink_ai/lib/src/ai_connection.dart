import 'dart:async';
import 'dart:developer' as console;
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:ygo_data/ygo_data.dart';

import 'ai_duel_engine.dart';
import 'card_data_loader.dart';

/// AI 本地对局连接 — 实现 DuelConnection，模拟 ygopro 服务端。
///
/// ## 架构
/// ```
/// 玩家 CTOS → send() → switch(protoId) ─┬─ 房间态: 直接生成 STOC 回复（本类）
///                                        └─ 对局态: AiDuelEngine(ocgcore) → STOC
/// AI 回合:  ocgcore PROCESSOR_WAITING 且待应答消息属于 player 1
///           → AiDuelEngine 自动应答（策略见 ai_strategy.dart）→ 继续 process()
/// ```
///
/// ## DUEL_SIMPLE_AI 的覆盖范围（重要）
/// ocgcore 的 `DUEL_SIMPLE_AI` 只对 player 1 的**细粒度选择**自动应答
/// （select_card / select_chain / select_place / select_position /
/// select_option / select_yes_no / sort_card 等，见 playerop.cpp），
/// 而 **回合级指令不自动处理**：
/// `MSG_SELECT_IDLECMD` / `MSG_SELECT_BATTLECMD` / `MSG_SELECT_TRIBUTE`
/// 对 player 1 同样会发出消息并进入 PROCESSOR_WAITING（processor.cpp 的
/// 分发不含 SIMPLE_AI 分支）。因此 AI 的"回合策略"由 [AiDuelEngine]
/// 实现：WAITING 时若待应答消息属于 player 1，自动应答后继续。
///
/// 同理，SIMPLE_AI 只为 playerid==1 服务，因此 **AI 固定为 player 1（后攻方）**，
/// 人类固定 player 0（先攻方）；先后攻选择见 [_onTpResult] 的说明。
///
/// ## 房间生命周期
/// ```
/// connect → (人类 join) → (AI 自动 join+ready) → Hand → TurnOrder → Duel → End
/// ```
///
/// ## 卡牌数据来源
/// 对局所需的卡数据由 [CardDataLoader] 提供：优先取已注册的 [ICardService]
/// （App 中为 ygo_card_mycard / ygo_card_baige 实现），无服务时回退到
/// 内置测试卡表（test_card_data.dart）。也可通过 [cardService] 显式注入。
class AiConnection implements DuelConnection {
  final _messageController = StreamController<YgoStocMsg>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();

  /// 显式指定的 ocgcore 动态库（测试环境传入，运行时默认为平台自带查找）。
  final ffi.DynamicLibrary? lib;

  late final AiDuelEngine _engine;

  AiConnection({this.lib, ICardService? cardService}) {
    _engine = AiDuelEngine(
      emit: _emit,
      cardLoader: CardDataLoader(cardService: cardService),
    );
  }

  // ── 对局状态 ──
  final List<int> _deck = [];

  // ── 房间模拟 ──
  final String _aiName = 'AI_Bob';
  String _name = '';
  bool _humanReady = false;
  bool _roomJoined = false;
  bool _handPhaseStarted = false;
  int _humanHandChoice = 0;
  int _aiHandChoice = 0;
  bool _humanGoFirst = true;

  // ── 延迟消息队列 ──
  final _pending = <YgoStocMsg>[];
  Timer? _pendingTimer;

  ConnectionState _state = ConnectionState.disconnected;

  // ──────────── DuelConnection 接口 ────────────

  @override
  Future<void> connect(Uri address) async {
    _resetRoomState();
    _state = ConnectionState.connecting;
    _stateController.add(_state);

    final ok = await _engine.init(lib);
    _state = ok ? ConnectionState.connected : ConnectionState.error;
    _stateController.add(_state);
  }

  @override
  void send(YgoCtosMsg msg) {
    switch (msg.protoId) {
      case CTOS_PLAYER_INFO:
        _name = msg.playerInfo?.name ?? _name;
        break;
      case CTOS_JOIN_GAME:
        _onJoinGame();
        break;
      case CTOS_UPDATE_DECK:
        _deck.clear();
        _parseDeck(msg.updateDeck!.encode());
        break;
      case CTOS_HS_READY:
        _humanReady = true;
        _checkReady();
        break;
      case CTOS_HS_START:
        _startHandPhase();
        break;
      case CTOS_HAND_RESULT:
        _humanHandChoice = msg.handResult!.hand;
        _onHandResult();
        break;
      case CTOS_TP_RESULT:
        _humanGoFirst = msg.tpResult?.first ?? true;
        _onTpResult();
        break;
      case CTOS_RESPONSE:
        _engine.onResponse(msg.response!.encode());
        break;
      case CTOS_SURRENDER:
        _engine.endDuel();
        break;
    }
    _flushPending();
  }

  @override
  Stream<YgoStocMsg> get messages => _messageController.stream;

  @override
  Stream<ConnectionState> get state => _stateController.stream;

  @override
  Future<void> disconnect() async {
    _pendingTimer?.cancel();
    _pending.clear();
    _engine.dispose();
    _resetRoomState();
    _state = ConnectionState.disconnected;
    _stateController.add(_state);
  }

  /// 重置房间/对局状态，保证断线重连后可以重新进房。
  void _resetRoomState() {
    _roomJoined = false;
    _humanReady = false;
    _handPhaseStarted = false;
    _deck.clear();
    _humanHandChoice = 0;
    _aiHandChoice = 0;
    _humanGoFirst = true;
  }

  // ──────────── 房间模拟 ────────────

  /// AI 在人类玩家进房之后加入（若提前发送，BaseDuelService 在
  /// RoomNotJoined 阶段会丢弃 playerEnter，大厅里看不到 AI）。
  void _scheduleAIJoin() {
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (_state != ConnectionState.connected || !_roomJoined) return;
      _emit(YgoStocMsg.hsPlayerEnter(
        StocHsPlayerEnter(name: _aiName, pos: 1),
      ));
      _emit(YgoStocMsg.hsPlayerChange(
        StocHsPlayerChange(pos: 1, state: HS_PLAYER_STATE_READY),
      ));
    });
  }

  void _onJoinGame() {
    if (_roomJoined) return;
    _roomJoined = true;

    final options = RoomOptions(
      mode: RoomMode.single, noCheckDeck: true, noShuffleDeck: true,
    );
    _emit(YgoStocMsg.joinGame(StocJoinGame(
      lflist: options.lfTableHash, rule: options.rule,
      mode: options.mode, duelRule: options.duelRule,
      noCheckDeck: options.noCheckDeck, noShuffleDeck: options.noShuffleDeck,
      startLp: options.startLp, startHand: options.startHand,
      drawCount: options.drawCount, timeLimit: options.timeLimit,
    )));
    _emit(YgoStocMsg.typeChange(StocTypeChange(isHost: true, selfType: SELF_TYPE_PLAYER1)));
    _emit(YgoStocMsg.hsPlayerEnter(
      StocHsPlayerEnter(name: _name.isNotEmpty ? _name : 'Human', pos: 0),
    ));
    _scheduleAIJoin();
  }

  void _checkReady() {
    if (_humanReady && _deck.isNotEmpty) {
      // AI 在进房时已自动 ready（见 _scheduleAIJoin）
      _startHandPhase();
    }
  }

  void _startHandPhase() {
    // HS_READY 与 HS_START 都可能触发，幂等保护避免重复发 SELECT_HAND
    if (_handPhaseStarted) return;
    _handPhaseStarted = true;
    _emit(YgoStocMsg.selectHand());
  }

  void _onHandResult() {
    // AI 固定出剪刀（1）：人类出石头必胜，流程确定；平局按协议重新猜拳
    _aiHandChoice = 1;
    _emit(YgoStocMsg.handResult(StocHandResult(
      meResult: _humanHandChoice, opResult: _aiHandChoice,
    )));

    final h = _humanHandChoice, a = _aiHandChoice;
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (!_handPhaseStarted || _engine.duelStarted) return;
      if (h == a) {
        // 平局 — 重新猜拳
        _emit(YgoStocMsg.selectHand());
        return;
      }
      // 1=剪刀 2=石头 3=布
      final humanWins =
          (h == 2 && a == 1) || (h == 3 && a == 2) || (h == 1 && a == 3);
      if (humanWins) {
        _emit(YgoStocMsg.selectTp());
      } else {
        // AI 赢 → 由 AI 决定先后攻。受 DUEL_SIMPLE_AI 限制（只自动应答
        // playerid==1），AI 必须是 player 1 即后攻方，因此固定人类先攻，
        // 不再发 SELECT_TP，直接开始决斗。
        _beginDuel();
      }
    });
  }

  void _onTpResult() {
    // 引擎约束：DUEL_SIMPLE_AI 只服务 player 1，人类固定为 player 0（先攻方）。
    // 人类选择后攻时无法让 AI 成为 player 0，这里仍按人类先攻开局，
    // MSG_START 的 playerType 与引擎保持一致（0 = 先攻）。
    if (!_humanGoFirst) {
      console.log('AiConnection: SIMPLE_AI 模式不支持人类后攻，按人类先攻开局');
    }
    _beginDuel();
  }

  void _beginDuel() {
    _emit(YgoStocMsg.duelStart());
    unawaited(_engine.startDuel(List<int>.of(_deck)));
  }

  // ──────────── 消息发射 ────────────

  void _emit(YgoStocMsg msg) {
    _pending.add(msg);
    _flushPending();
  }

  void _flushPending() {
    if (_pending.isEmpty) return;
    _pendingTimer?.cancel();
    _pendingTimer = Timer(const Duration(milliseconds: 10), () {
      final items = List<YgoStocMsg>.from(_pending);
      _pending.clear();
      for (final item in items) {
        _messageController.add(item);
      }
    });
  }

  // ──────────── 卡组解析 ────────────

  void _parseDeck(Uint8List data) {
    final r = BufferReader(data);
    if (r.remaining < 4) return;
    final mainLen = r.readInt32();
    r.readInt32(); // skip sideLen
    _deck.clear();
    for (int i = 0; i < mainLen && r.remaining >= 4; i++) {
      _deck.add(r.readInt32());
    }
  }
}
