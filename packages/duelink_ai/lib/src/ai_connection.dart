import 'dart:async';
import 'dart:developer' as console;
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:flutter/services.dart';
import 'package:ocgcore/ocgcore.dart';

/// AI 本地对局连接 — 实现 DuelConnection，模拟 ygopro 服务端。
///
/// ## 架构
/// ```
/// 玩家 CTOS → send() → switch(protoId) ─┬─ 房间态: 直接生成 STOC 回复
///                                         └─ 对局态: ocgcore.process() → STOC
/// AI 回合:     ocgcore PROCESSOR_WAITING → _autoAnswer() → 继续 process()
/// ```
///
/// ## 房间生命周期
/// ```
/// connect → (auto AI join) → Lobby → Hand → TurnOrder → Duel → End
/// ```
///
/// ## 对局流程
/// ```
/// startDuel → ocgcore.startDuel()
/// 玩家操作 → setResponse() → process()
/// AI 轮次 → _autoAnswer() → setResponse() → process()
/// ```
class AiConnection implements DuelConnection {
  final _messageController = StreamController<YgoStocMsg>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();

  /// 显式指定的 ocgcore 动态库（测试环境传入，运行时默认为平台自带查找）。
  final ffi.DynamicLibrary? lib;

  AiConnection({this.lib});

  // ── ocgcore ──
  OcgCore? _core;
  int? _duel;
  final _scriptCache = <String, Uint8List>{};

  // ── 对局状态 ──
  final List<int> _deck = [];
  final int _aiPlayer = 1;
  bool _duelStarted = false;

  // ── 房间模拟 ──
  final String _aiName = 'AI_Bob';
  String _name = '';
  bool _humanReady = false;
  bool _roomJoined = false;
  int _humanHandChoice = 0;
  int _aiHandChoice = 0;
  bool _humanGoFirst = true;

  // ── 延迟消息队列 ──
  final _pending = <YgoStocMsg>[];
  Timer? _pendingTimer;

  ConnectionState _state = ConnectionState.disconnected;

  // ──────────── DuelConnection 接口 ────────────

  @override
  Future<void> connect(String address, int port) async {
    _state = ConnectionState.connecting;
    _stateController.add(_state);

    try {
      _core = await createOcgCore(lib);
      if (_core == null) {
        _state = ConnectionState.error;
        _stateController.add(_state);
        return;
      }
      _core!.setScriptReader(_loadScript);
      _core!.setCardReader(_loadCard);

      _state = ConnectionState.connected;
      _stateController.add(_state);

      // AI 自动加入房间
      _scheduleAIJoin();
    } catch (e) {
      console.log('AiConnection: init error $e');
      _state = ConnectionState.error;
      _stateController.add(_state);
    }
  }

  @override
  void send(YgoCtosMsg msg) {
    switch (msg.protoId) {
      case CTOS_PLAYER_INFO:  _name = msg.playerInfo?.name ?? _name; break;
      case CTOS_JOIN_GAME:    _onJoinGame(); break;
      case CTOS_UPDATE_DECK:  _deck.clear(); _parseDeck(msg.updateDeck!.encode()); break;
      case CTOS_HS_READY:     _humanReady = true; _checkReady(); break;
      case CTOS_HS_START:     _startHandPhase(); break;
      case CTOS_HAND_RESULT:  _humanHandChoice = msg.handResult!.hand; _onHandResult(); break;
      case CTOS_TP_RESULT:    _humanGoFirst = msg.tpResult?.first ?? true; _onTpResult(); break;
      case CTOS_RESPONSE:     _onResponse(msg.response!.encode()); break;
      case CTOS_SURRENDER:    _endDuel(); break;
    }
    _flushPending();
  }

  @override
  Stream<YgoStocMsg> get messages => _messageController.stream;

  // ──────────── CTOS 路由 ────────────

  @override
  Stream<ConnectionState> get state => _stateController.stream;
  @override
  Future<void> disconnect() async {
    _pendingTimer?.cancel();
    if (_duel != null && _core != null) {
      try { _core!.endDuel(_duel!); } catch (_) {}
    }
    _duel = null;
    _core = null;
    _state = ConnectionState.disconnected;
    _stateController.add(_state);
  }

  // ──────────── 房间模拟 ────────────

  void _scheduleAIJoin() {
    // 延迟一小段时间后 AI 自动加入房间
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (_state != ConnectionState.connected) return;
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
  }

  void _checkReady() {
    if (_humanReady && _deck.isNotEmpty) {
      // AI is auto-ready (set in _scheduleAIJoin via PLAYER_CHANGE)
      _startHandPhase();
    }
  }

  void _startHandPhase() {
    // AI 自动猜拳
    _aiHandChoice = 2; // ROCK (2=ROCK in ygopro)
    _emit(YgoStocMsg.selectHand());
  }

  void _onHandResult() {
    // 发送猜拳结果
    _emit(YgoStocMsg.handResult(StocHandResult(
      meResult: _humanHandChoice, opResult: _aiHandChoice,
    )));
    // 猜拳阶段结束，进入先后攻选择
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      _emit(YgoStocMsg.selectTp());
    });
  }

  void _onTpResult() {
    // 先后攻已选 → 开始对局
    _emit(YgoStocMsg.duelStart());
    _startOcgDuel();
  }

  // ──────────── 对局引擎 ────────────

  Future<void> _startOcgDuel() async {
    if (_core == null || _deck.isEmpty) return;

    _duel = _core!.createDuel(DateTime.now().millisecondsSinceEpoch & 0xffffffff);
    if (_duel == 0) return;

    // 设置双方玩家
    _core!.setPlayerInfo(_duel!, 0, 8000, 5, 1);
    _core!.setPlayerInfo(_duel!, 1, 8000, 5, 1);

    // 预加载基础脚本
    for (final s in ['constant.lua', 'utility.lua', 'procedure.lua', 'event.lua']) {
      _core!.preloadScript(_duel!, s);
    }

    // 预加载卡牌数据与效果脚本（需在 newCard 之前完成，否则回调缓存为空，
    // 导致怪兽无法召唤 / 魔法陷阱无法发动）
    //
    // 注意：只通过 preloadScriptAsync 将脚本字节缓存到 Dart 侧，
    // 不调用 preloadScript（那会直接执行 .lua 文件，但卡牌脚本依赖
    // load_card_script 提前创建好的 cXXXX 全局表，直接执行会报 nil 错误）。
    // 引擎会在 newCard 时通过 load_card_script → read_script 回调读缓存。
    for (final code in _deck.toSet()) {
      await _core!.preloadCardAsync(code);
      await _core!.preloadScriptAsync('c$code.lua');
    }

    // 加载卡组到 ocgcore
    _loadDeckToCore();

    // 使用简单 AI 模式（ocgcore 内置）
    _core!.startDuel(_duel!, DUEL_SIMPLE_AI);
    _duelStarted = true;

    // ocgcore 不直接发出 MSG_START（由服务端合成），这里补发
    _emit(YgoStocMsg.gameMsg(StocGameMessage(
      func: MSG_START,
      innerMsg: MsgStart(
        playerType: _humanGoFirst ? 0 : 1,
        masterRule: 1,
        life1: 8000,
        life2: 8000,
        deckSize1: _deck.length,
        extraSize1: 0,
        deckSize2: _deck.length,
        extraSize2: 0,
      ),
    )));

    // 同步执行第一轮 process
    _duelLoop();
  }

  void _loadDeckToCore() {
    if (_duel == null || _core == null) return;

    // 将卡组放入双方的主卡组
    for (int i = 0; i < _deck.length; i++) {
      // 人类玩家 (player 0) 的主卡组
      _core!.newCard(_duel!, _deck[i], 0, 0, LOCATION_DECK, i, 0);
      // AI 玩家 (player 1) 的主卡组（同样的卡组）
      _core!.newCard(_duel!, _deck[i], 1, 1, LOCATION_DECK, i, 0);
    }
  }

  void _duelLoop() {
    while (true) {
      final result = _core!.process(_duel!);
      final status = result & PROCESSOR_FLAG;
      final msgLen = result & PROCESSOR_BUFFER_LEN;

      if (msgLen > 0) {
        final buf = Uint8List(msgLen);
        _core!.getMessage(_duel!, buf);
        _emitGameMsg(buf);
      }

      if (status == PROCESSOR_WAITING) {
        // DUEL_SIMPLE_AI 下 ocgcore 自动处理 AI 回合，
        // WAITING 必然是人类玩家的回合 — 停止等待输入
        break;
      }

      if (status == PROCESSOR_END) {
        _endDuel();
        break;
      }
    }
  }

  void _onResponse(Uint8List data) {
    if (!_duelStarted || _duel == null || _core == null) return;
    // 人类玩家发送了游戏内响应 — 传给 ocgcore
    _core!.setResponseb(_duel!, data);
    _duelLoop();
  }

  void _endDuel() {
    _duelStarted = false;
    if (_duel != null && _core != null) {
      try { _core!.endDuel(_duel!); } catch (_) {}
    }
    _duel = null;
    _emit(YgoStocMsg.duelEnd());
  }

  // ──────────── 消息发射 ────────────

  void _emit(YgoStocMsg msg) {
    _pending.add(msg);
    _flushPending();
  }

  void _emitGameMsg(Uint8List msg) {
    _emit(YgoStocMsg.gameMsg(StocGameMessage.decode(msg)));
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

  // ──────────── 工具 ────────────

  // ──────────── 脚本与卡片加载 ────────────

  Future<Uint8List?> _loadScript(String name) async {
    if (_scriptCache.containsKey(name)) return _scriptCache[name];
    try {
      final data = await rootBundle.load('assets/scripts/$name');
      final bytes = data.buffer.asUint8List();
      _scriptCache[name] = bytes;
      return bytes;
    } catch (_) {
      try {
        final file = File('assets/scripts/$name');
        final bytes = await file.readAsBytes();
        _scriptCache[name] = bytes;
        return bytes;
      } catch (_) {
        return null;
      }
    }
  }

  Future<CardData?> _loadCard(int code) async {
    // 返回已知卡片的基础数据（通常怪兽级别）
    return _knownCards[code];
  }

  /// 测试用卡组的 CardData。
  /// ocgcore 需要知道卡片的基本信息（ATK/DEF/种族等）才能正确处理战斗。
  static final Map<int, CardData> _knownCards = {
    89631139: CardData(code: 89631139, alias: 0, setcode: [], type: 0x11,
        level: 8, attribute: 0x10, race: 0x2000,
        attack: 3000, defense: 2500, lscale: 0, rscale: 0,
        linkMarker: 0, ruleCode: 0, name: 'Blue-Eyes White Dragon', desc: ''),
    46986414: CardData(code: 46986414, alias: 0, setcode: [], type: 0x11,
        level: 7, attribute: 0x20, race: 0x2,
        attack: 2500, defense: 2100, lscale: 0, rscale: 0,
        linkMarker: 0, ruleCode: 0, name: 'Dark Magician', desc: ''),
    15025844: CardData(code: 15025844, alias: 0, setcode: [], type: 0x11,
        level: 4, attribute: 0x10, race: 0x2,
        attack: 800, defense: 2000, lscale: 0, rscale: 0,
        linkMarker: 0, ruleCode: 0, name: 'Mystical Elf', desc: ''),
    91152256: CardData(code: 91152256, alias: 0, setcode: [], type: 0x11,
        level: 4, attribute: 0x01, race: 0x1,
        attack: 1400, defense: 1200, lscale: 0, rscale: 0,
        linkMarker: 0, ruleCode: 0, name: 'Celtic Guardian', desc: ''),
    13039848: CardData(code: 13039848, alias: 0, setcode: [], type: 0x11,
        level: 3, attribute: 0x01, race: 0x100,
        attack: 1300, defense: 2000, lscale: 0, rscale: 0,
        linkMarker: 0, ruleCode: 0, name: 'Giant Soldier of Stone', desc: ''),
    6368038: CardData(code: 6368038, alias: 0, setcode: [], type: 0x11,
        level: 7, attribute: 0x01, race: 0x1,
        attack: 2300, defense: 2100, lscale: 0, rscale: 0,
        linkMarker: 0, ruleCode: 0, name: 'Gaia The Fierce Knight', desc: ''),
    28279543: CardData(code: 28279543, alias: 0, setcode: [], type: 0x11,
        level: 5, attribute: 0x20, race: 0x2000,
        attack: 2000, defense: 1500, lscale: 0, rscale: 0,
        linkMarker: 0, ruleCode: 0, name: 'Curse of Dragon', desc: ''),
    74677422: CardData(code: 74677422, alias: 0, setcode: [], type: 0x11,
        level: 7, attribute: 0x20, race: 0x2000,
        attack: 2400, defense: 2000, lscale: 0, rscale: 0,
        linkMarker: 0, ruleCode: 0, name: 'Red-Eyes Black Dragon', desc: ''),
    88819587: CardData(code: 88819587, alias: 0, setcode: [], type: 0x11,
        level: 4, attribute: 0x04, race: 0x2000,
        attack: 1200, defense: 700, lscale: 0, rscale: 0,
        linkMarker: 0, ruleCode: 0, name: 'Baby Dragon', desc: ''),
    76184692: CardData(code: 76184692, alias: 0, setcode: [], type: 0x11,
        level: 4, attribute: 0x01, race: 0x8000,
        attack: 1200, defense: 1000, lscale: 0, rscale: 0,
        linkMarker: 0, ruleCode: 0, name: 'Hitotsu-Me Giant', desc: ''),
    55144522: CardData(code: 55144522, alias: 0, setcode: [], type: 0x2,
        level: 0, attribute: 0, race: 0,
        attack: 0, defense: 0, lscale: 0, rscale: 0,
        linkMarker: 0, ruleCode: 0, name: 'Pot of Greed', desc: 'Draw 2 cards.'),
    4206964: CardData(code: 4206964, alias: 0, setcode: [], type: 0x4,
        level: 0, attribute: 0, race: 0,
        attack: 0, defense: 0, lscale: 0, rscale: 0,
        linkMarker: 0, ruleCode: 0, name: 'Trap Hole',
        desc: 'When your opponent Normal Summons a monster with 1000 or more ATK: Target that monster; destroy it.'),
  };
}
