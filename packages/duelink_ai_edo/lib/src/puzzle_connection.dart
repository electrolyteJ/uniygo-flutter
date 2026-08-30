import 'dart:async';
import 'package:applog/console.dart' as console;
import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:duelink_ai/ai_strategy.dart';
import 'package:ocgcore/ocgcore.dart' show DuelEngine;
import 'package:ocgcore_edo/puzzle_script_loader.dart';
import 'package:resource_data/ygo_data.dart';

import 'puzzle_card_data_loader.dart';

/// 残局本地对局连接 — 实现 DuelConnection，复用 ocgcore 包的 [DuelEngine]。
///
/// ## 与 AiConnection 的差异
/// 残局不需要卡组/猜拳/先后攻：卡组和场面由残局脚本（Debug.* API）定义，
/// 人类固定 player 0 先攻（`aux.BeginPuzzle` 跳过抽卡阶段，回合结束未获胜
/// 则 LP 清零判负）。房间流程在 HS_READY / HS_START 时直接开局。
///
/// ## 残局选择
/// [connect] 的 URI 指定残局脚本：
/// `puzzle://local/World%20Championship/%5BWCS2006%5D01_Warriors%20of%20Darkness.lua`
/// → 引擎脚本名 `puzzle/World Championship/[WCS2006]01_Warriors of Darkness.lua`
/// （[PuzzleScriptLoader] 将其映射到 ygo_puzzles 资产包，即根 vendor/Puzzles）。
///
/// ## 卡牌/脚本数据来源
/// 卡数据：[PuzzleCardDataLoader]（ICardService → 残局卡表）。
/// lua 脚本：[PuzzleScriptLoader]（残局走 ygo_puzzles 资产包，
/// 基础/卡牌脚本走 ygo_scripts 资产包，均为根 vendor 下的 submodule）。
class PuzzleConnection implements DuelConnection {
  final _messageController = StreamController<YgoStocMsg>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();

  /// 显式指定的 ocgcore 动态库（测试环境传入，运行时默认为平台自带查找）。
  final Object? lib;

  late final DuelEngine _engine;

  PuzzleConnection({this.lib, ICardService? cardService}) {
    final cardLoader = PuzzleCardDataLoader(cardService: cardService);
    _engine = DuelEngine(
      emit: _emitEngineMessage,
      splitMessages: splitGameMessages,
      autoAnswer: aiAutoAnswer(cardLoader.levelOf),
      scriptLoader: PuzzleScriptLoader(),
      cardReader: cardLoader.load,
      onDuelEnd: () => _emit(YgoStocMsg.duelEnd()),
    );
  }

  /// 引擎消息入口：原始字节解码为协议消息后入队派发。
  void _emitEngineMessage(Uint8List data) {
    try {
      _emit(YgoStocMsg.gameMsg(StocGameMessage.decode(data)));
    } catch (e) {
      console.log('PuzzleConnection: decode gameMsg failed: $e');
    }
  }

  // ── 对局状态 ──
  String _puzzleScript = '';
  bool _puzzleStarted = false;

  // ── 房间模拟 ──
  final String _aiName = 'Puzzle';
  String _name = '';
  bool _roomJoined = false;

  // ── 延迟消息队列 ──
  final _pending = <YgoStocMsg>[];
  Timer? _pendingTimer;

  ConnectionState _state = ConnectionDisconnected();

  // ──────────── DuelConnection 接口 ────────────

  @override
  Future<void> connect(Uri address) async {
    _resetRoomState();
    _puzzleScript = scriptNameOf(address);
    _state = ConnectionConnecting();
    _stateController.add(_state);

    final ok = await _engine.init(lib);
    _state = ok ? ConnectionConnected() : ConnectionError(message: 'Failed to connect');
    _stateController.add(_state);
  }

  /// `puzzle://local/<category>/<file>.lua` → `puzzle/<category>/<file>.lua`。
  /// 空路径返回空串（连接保持可用，开局时拒绝）。
  ///
  /// 注意用 [Uri.pathSegments]（自动百分号解码）而非 [Uri.path]（保留编码）。
  static String scriptNameOf(Uri address) {
    final segments = address.pathSegments;
    if (segments.isEmpty) return '';
    return 'puzzle/${segments.join('/')}';
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
        // 残局无需卡组：卡组/场面由残局脚本定义
        break;
      case CTOS_HS_READY:
        _emit(YgoStocMsg.hsPlayerChange(
          StocHsPlayerChange(pos: 0, state: HS_PLAYER_STATE_READY),
        ));
        _startPuzzle();
        break;
      case CTOS_HS_START:
        _startPuzzle();
        break;
      case CTOS_RESPONSE:
        // onResponse 已异步化（AI 应答可能走远端 HTTP）；send 是同步接口，
        // 这里 fire-and-forget，引擎内部以 _pumping 防护重入。
        unawaited(_engine.onResponse(msg.response!.encode()));
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
    _resetRoomState();
    _engine.dispose();
    _state = ConnectionDisconnected();
    _stateController.add(_state);
  }

  /// 重置房间/对局状态，保证断线重连后可以重新进房。
  void _resetRoomState() {
    _roomJoined = false;
    _puzzleScript = '';
    _puzzleStarted = false;
  }

  // ──────────── 房间模拟 ────────────

  /// AI 在人类玩家进房之后加入（同 AiConnection 的时序约束）。
  void _scheduleAIJoin() {
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (_state is! ConnectionConnected || !_roomJoined) return;
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

  // ──────────── 残局开局 ────────────

  void _startPuzzle() {
    // HS_READY 与 HS_START 都可能触发，幂等保护避免重复开局
    if (_puzzleStarted || _puzzleScript.isEmpty) return;
    _puzzleStarted = true;
    _emit(YgoStocMsg.duelStart());
    unawaited(() async {
      final info = await _engine.startPuzzle(_puzzleScript);
      if (info == null) {
        console.log('PuzzleConnection: startPuzzle failed for $_puzzleScript');
        _puzzleStarted = false;
        _emit(YgoStocMsg.duelEnd());
        return;
      }
      // ocgcore 不直接发出 MSG_START（由服务端合成），这里补发；
      // LP/卡组统计取自残局脚本，真实场面由随后的 MSG_RELOAD_FIELD 刷新。
      _emit(YgoStocMsg.gameMsg(StocGameMessage(
        func: MSG_START,
        innerMsg: MsgStart(
          playerType: 0,
          masterRule: DuelRule.mr2020.value,
          life1: info.lp0,
          life2: info.lp1,
          deckSize1: info.deck0,
          extraSize1: info.extra0,
          deckSize2: info.deck1,
          extraSize2: info.extra1,
        ),
      )));
      await _engine.pump();
    }());
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
}
