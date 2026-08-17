import 'dart:async';
import 'dart:convert';
import 'dart:developer' as console;
import 'dart:typed_data';

import '../ocgcore.dart';
import 'script_loader.dart';

/// 引擎消息发射回调：单条对局消息的原始字节（含 func 头）。
typedef DuelMessageEmitter = void Function(Uint8List message);

/// 缓冲区拆包器：把 process() 缓冲区切分为单条消息。
///
/// 拆包需要逐消息线长知识（协议层 duelink 提供 `splitGameMessages`），
/// 引擎本身不内置协议格式。
typedef DuelMessageSplitter = List<Uint8List> Function(Uint8List buffer);

/// AI 自动应答器：输入待应答消息的 func 与载荷（不含 func 头字节），
/// 输出响应字节；返回 null 表示无法自动应答（引擎停住等待）。
///
/// 允许异步实现（如远端 HTTP 推理服务）：引擎的 pump 循环会 await
/// 应答结果。同步实现直接返回字节即可（FutureOr 兼容）。
typedef DuelAutoAnswer = FutureOr<Uint8List?> Function(
    int func, Uint8List payload);

/// 对局开局信息 —— startDuel / startPuzzle 的返回值，
/// 供上层（Connection）合成 MSG_START 等协议消息。
class DuelSetupInfo {
  final int lp0;
  final int lp1;
  final int deck0;
  final int extra0;
  final int deck1;
  final int extra1;

  const DuelSetupInfo({
    required this.lp0,
    required this.lp1,
    required this.deck0,
    required this.extra0,
    required this.deck1,
    required this.extra1,
  });
}

/// 本地对局引擎 —— 封装 ocgcore 的对局生命周期。
///
/// 职责：初始化 ocgcore、预加载脚本/卡数据、创建并推进对局
/// （process 循环）、按 [splitMessages] 拆包并跟踪待应答的选择类消息归属，
/// 待应答消息属于 AI 玩家时通过 [autoAnswer] 自动应答。
///
/// 引擎工作在纯字节层：消息以原始字节（含 func 头）经 [emit] 上交，
/// 协议解码/编码由上层（duelink）负责 —— ocgcore 与 duelink 互不依赖。
///
/// 数据注入：
/// - [scriptLoader]：lua 脚本读取（默认 [ScriptLoader]，资产/文件系统）
/// - [cardReader]：卡数据读取（ocgcore [CardReader] 签名）
/// - [autoAnswer]：AI 自动应答策略（duelink 提供 `aiAutoAnswer` 工厂）
/// - [onDuelEnd]：对局结束通知（投降 / PROCESSOR_END）
class DuelEngine {
  DuelEngine({
    required DuelMessageEmitter emit,
    required DuelMessageSplitter splitMessages,
    DuelAutoAnswer? autoAnswer,
    ScriptLoader? scriptLoader,
    CardReader? cardReader,
    void Function()? onDuelEnd,
  }) : _emit = emit,
       _splitMessages = splitMessages,
       scriptLoader = scriptLoader ?? ScriptLoader(),
       _onDuelEnd = onDuelEnd;

  final DuelMessageEmitter _emit;
  final DuelMessageSplitter _splitMessages;
  final ScriptLoader scriptLoader;
  DuelAutoAnswer? _autoAnswer;
  CardReader? _cardReader;
  final void Function()? _onDuelEnd;

  OcgCore? _core;
  int? _duel;
  bool _duelStarted = false;

  static const int _aiPlayer = 1;

  /// 对局是否已开始（用于房间流程的幂等保护）。
  bool get duelStarted => _duelStarted;

  // ── 待应答的选择类消息（用于识别 WAITING 属于哪一方）──
  int? _pendingSelectFunc;
  int? _pendingSelectPlayer;
  Uint8List? _pendingSelectPayload;
  bool _sawRetryInPump = false;

  void setCardReader(CardReader reader) {
    _cardReader = reader;
  }
  void setAutoAnswer(DuelAutoAnswer autoAnswer) {
    _autoAnswer = autoAnswer;
  }
  /// 初始化 ocgcore 并注册脚本/卡数据读取回调。成功返回 true。
  Future<bool> init(Object? lib) async {
    try {
      _core = await createOcgCore(lib);
    } catch (e) {
      console.log('DuelEngine: init error $e');
      _core = null;
    }
    if (_core == null) return false;
    _core!.setScriptReader(scriptLoader.load);
    if (_cardReader != null) _core!.setCardReader(_cardReader);
    // 重连后旧对局句柄对新 core 无意义，全部重置
    _duel = null;
    _duelStarted = false;
    _clearPendingSelect();
    return true;
  }

  /// 释放引擎（不断发任何消息），对应断线场景。
  void dispose() {
    if (_duel != null && _core != null) {
      try {
        _core!.endDuel(_duel!);
      } catch (_) {}
    }
    _duel = null;
    _core = null;
    _duelStarted = false;
    _clearPendingSelect();
  }

  /// 结束当前对局并通知上层（对应投降 / 引擎 PROCESSOR_END）。
  void endDuel() {
    _duelStarted = false;
    if (_duel != null && _core != null) {
      try {
        _core!.endDuel(_duel!);
      } catch (_) {}
    }
    _duel = null;
    _clearPendingSelect();
    _onDuelEnd?.call();
  }

  /// 创建对局：预加载脚本/卡数据 → createDuel → 装载双方卡组 →
  /// 以 DUEL_SIMPLE_AI 启动。成功返回开局信息，失败返回 null。
  ///
  /// [startLp]/[startHand]/[drawCount] 控制双方玩家的初始 LP、起手手牌数
  /// 与每回合抽牌数（缺省 8000/5/1）。
  ///
  /// [simpleAi] 控制是否启用 ocgcore 内置 SIMPLE_AI（缺省启用）。接入
  /// 模型自动应答时应传 false：SIMPLE_AI 会替 AI 挡掉 select_effect_yes_no
  /// 等细粒度消息，模型永远看不到这些决策，历史动作序列会偏离训练分布。
  ///
  /// 注意：本方法不推进 process 循环，调用方应在合成/下发 MSG_START
  /// 之后再调用 [pump] 推进第一轮。
  Future<DuelSetupInfo?> startDuel(
    List<int> deck, {
    int startLp = 8000,
    int startHand = 5,
    int drawCount = 1,
    bool simpleAi = true,
  }) async {
    final core = _core;
    if (core == null) {
      console.log('DuelEngine: startDuel failed — _core is null');
      return null;
    }
    if (deck.isEmpty) {
      console.log('DuelEngine: startDuel failed — deck is empty');
      return null;
    }
    console.log('DuelEngine: preloading ${deck.toSet().length} unique cards...');

    // 基础脚本必须在 createDuel 之前写入 Dart 侧缓存 —— interpreter 构造时
    // 就会通过同步回调自动加载 ./script/constant.lua、utility.lua、
    // procedure.lua（interpreter.cpp），错过时缓存为空会加载失败，
    // 导致卡牌脚本依赖的常量（REASON_* 等）全部为 nil。
    for (final s in scriptLoader.bootstrapScriptNames) {
      await core.preloadScriptAsync(s);
    }
    console.log('DuelEngine: bootstrap scripts preloaded');

    // 预加载卡牌数据与效果脚本（需在 newCard 之前完成，否则回调缓存为空，
    // 导致怪兽无法召唤 / 魔法陷阱无法发动）
    //
    // 注意：只通过 preloadScriptAsync 将脚本字节缓存到 Dart 侧，
    // 不调用 preloadScript（那会直接执行 .lua 文件，但卡牌脚本依赖
    // load_card_script 提前创建好的 cXXXX 全局表，直接执行会报 nil 错误）。
    // 引擎会在 newCard 时通过 load_card_script → read_script 回调读缓存。
    for (final code in deck.toSet()) {
      await core.preloadCardAsync(code);
      await core.preloadScriptAsync('c$code.lua');
    }
    console.log('DuelEngine: card data and scripts preloaded');

    // 预加载是异步的，期间连接可能已断开（dispose 会清空 _core）
    if (!identical(_core, core)) {
      console.log('DuelEngine: startDuel failed — _core changed during preloading');
      return null;
    }

    _duel = core.createDuel(DateTime.now().millisecondsSinceEpoch & 0xffffffff);
    if (_duel == 0) {
      console.log('DuelEngine: startDuel failed — createDuel returned 0');
      return null;
    }
    console.log('DuelEngine: createDuel succeeded, pduel=$_duel');

    // 设置双方玩家：人类固定 player 0（先攻方），AI 固定 player 1
    core.setPlayerInfo(_duel!, 0, startLp, startHand, drawCount);
    core.setPlayerInfo(_duel!, 1, startLp, startHand, drawCount);

    // 加载卡组到 ocgcore（双方使用同一副卡组）
    for (int i = 0; i < deck.length; i++) {
      core.newCard(_duel!, deck[i], 0, 0, LOCATION_DECK, i, 0);
      core.newCard(_duel!, deck[i], 1, 1, LOCATION_DECK, i, 0);
    }
    console.log('DuelEngine: cards loaded, starting duel '
        '(simpleAi=$simpleAi)');

    // SIMPLE_AI 为可选模式（ocgcore 内置，覆盖范围见上层 Connection 注释）
    try {
      core.startDuel(_duel!, simpleAi ? DUEL_SIMPLE_AI : 0);
    } catch (e) {
      console.log('DuelEngine: startDuel failed — core.startDuel threw: $e');
      core.endDuel(_duel!);
      _duel = null;
      return null;
    }
    _duelStarted = true;
    console.log('DuelEngine: duel started successfully');
    return DuelSetupInfo(
      lp0: startLp,
      lp1: startLp,
      deck0: deck.length,
      extra0: 0,
      deck1: deck.length,
      extra1: 0,
    );
  }

  /// 创建残局对局：预加载脚本/卡数据 → createDuel → 执行残局脚本
  /// 摆场（Debug.* API）→ startDuel。成功返回开局信息，失败返回 null。
  ///
  /// [scriptName] 残局脚本名（传给 [ScriptLoader] 的 key，如
  /// `puzzle/World Championship/xxx.lua`）。残局脚本使用 ocgcore `Debug.*`
  /// API 布置场面（见 vendor ocgcore libdebug.cpp），并以
  /// `aux.BeginPuzzle()` 注册"回合结束未获胜则判负"效果。
  ///
  /// 与普通对局的差异：
  /// - 卡组/场面由残局脚本定义，不经过 newCard 装载；
  /// - [OcgCore.preloadScript] 会立即执行脚本（区别于只缓存字节的
  ///   preloadScriptAsync），必须在 createDuel 之后、startDuel 之前调用；
  /// - startDuel 的 options 传 0 —— 决斗选项（DUEL_SIMPLE_AI 等）由脚本的
  ///   `Debug.ReloadFieldBegin(flag)` 注入（C++ start_duel 为 OR 合并语义）。
  ///
  /// 同样不推进 process 循环，调用方下发 MSG_START 后调用 [pump]。
  Future<DuelSetupInfo?> startPuzzle(String scriptName) async {
    final core = _core;
    if (core == null) return null;

    // 基础脚本必须在 createDuel 之前写入 Dart 侧缓存（同 startDuel 注释）
    final preloadScripts = await scriptLoader.listPreloadScriptNames();
    final preloadTargets = preloadScripts.isNotEmpty
        ? preloadScripts
        : scriptLoader.bootstrapScriptNames;
    for (final s in preloadTargets) {
      await core.preloadScriptAsync(s);
    }

    // 读取并解析残局脚本，提取其中引用的全部卡号
    final bytes = await scriptLoader.load(scriptName);
    if (bytes == null) {
      console.log('DuelEngine: puzzle script not found: $scriptName');
      return null;
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    final codes = RegExp(
      r'Debug\.AddCard\(\s*(\d+)',
    ).allMatches(text).map((m) => int.parse(m.group(1)!)).toSet();

    // 预加载卡牌数据与效果脚本（Debug.AddCard 执行时通过同步回调读缓存）
    for (final code in codes) {
      await core.preloadCardAsync(code);
      await core.preloadScriptAsync('c$code.lua');
    }
    // 残局脚本本身写入引擎缓存（preloadScript 的同步回调从这里读）
    await core.preloadScriptAsync(scriptName);

    // 预加载是异步的，期间连接可能已断开（dispose 会清空 _core）
    if (!identical(_core, core)) return null;

    _duel = core.createDuel(DateTime.now().millisecondsSinceEpoch & 0xffffffff);
    if (_duel == 0) return null;

    // 对 CardScripts 方案，bootstrap 由 preloadScriptAsync 预热后再显式执行。
    for (final s in scriptLoader.bootstrapScriptNames) {
      final result = core.preloadScript(_duel!, s);
      if (result != OPERATION_SUCCESS) {
        console.log('DuelEngine: bootstrap script exec failed: $s');
        core.endDuel(_duel!);
        _duel = null;
        return null;
      }
    }

    // 占位默认值，实际 LP/起手/抽牌数由脚本的 Debug.SetPlayerInfo 覆盖
    core.setPlayerInfo(_duel!, 0, 8000, 0, 0);
    core.setPlayerInfo(_duel!, 1, 8000, 0, 0);

    // 执行残局脚本摆场；MSG_AI_NAME / MSG_SHOW_HINT / MSG_RELOAD_FIELD
    // 写入引擎缓冲，随第一次 [pump] 下发
    final execResult = core.preloadScript(_duel!, scriptName);
    if (execResult != OPERATION_SUCCESS) {
      console.log('DuelEngine: puzzle script exec failed: $scriptName');
      core.endDuel(_duel!);
      _duel = null;
      return null;
    }
    try {
      core.startDuel(_duel!, 0);
    } catch (_) {
      core.endDuel(_duel!);
      _duel = null;
      return null;
    }
    _duelStarted = true;

    // 开局信息（LP/卡组统计）取自脚本内容，供上层合成 MSG_START；
    // 真实场面由随后的 MSG_RELOAD_FIELD 全量刷新。
    final deckCounts = _puzzleDeckCounts(text);
    return DuelSetupInfo(
      lp0: _puzzleLp(text, 0),
      lp1: _puzzleLp(text, 1),
      deck0: deckCounts[0].$1,
      extra0: deckCounts[0].$2,
      deck1: deckCounts[1].$1,
      extra1: deckCounts[1].$2,
    );
  }

  /// 推进 process 循环：发射缓冲消息、自动应答 AI 待应答消息，
  /// 直到等待人类输入或对局结束。开局首轮与人类应答后均需调用。
  ///
  /// 异步化说明：AI 自动应答可能是异步的（远端 HTTP 推理），pump
  /// 返回的 Future 在循环真正停下（等待人类 / 对局结束 / 保护性
  /// 中止）时才完成。
  ///
  /// 并发保护：若上一次 pump 仍在执行（含异步等待期间），直接忽略。
  Future<void> pump() async {
    if (_pumping || !_duelStarted || _duel == null || _core == null) return;
    _pumping = true;
    try {
      await _pumpLoop();
    } finally {
      _pumping = false;
    }
  }

  bool _pumping = false;

  // ── 场态查询（供上层 AI 构建模型输入）──

  /// 场态查询缓冲区上限（256KB，足够容纳双方全部区域的查询记录）。
  static const int _fieldQueryBufferSize = 256 * 1024;
  Uint8List? _fieldQueryBuffer;

  /// 查询指定玩家区域中的卡牌数量（ocgcore `query_field_count`）。
  ///
  /// 对局未开始 / 引擎未就绪 / 查询异常时返回 0。
  int queryFieldCount(int player, int location) {
    final core = _core;
    final duel = _duel;
    if (core == null || duel == null) return 0;
    try {
      return core.queryFieldCount(duel, player, location);
    } catch (e) {
      console.log('DuelEngine: queryFieldCount error $e');
      return 0;
    }
  }

  /// 查询指定玩家区域中全部卡牌的数据（ocgcore `query_field_card`）。
  ///
  /// 返回按 [queryFlag] 填充的记录字节流（记录格式与 ocgcore
  /// `card::get_infos` 一致：逐卡 `u32 len + u32 flag + 各字段`，
  /// 空槽为 `len == LEN_EMPTY`）；由上层按标志位解析。
  /// 对局未开始 / 引擎未就绪 / 查询异常时返回空字节。
  Uint8List queryFieldCard(int player, int location, int queryFlag) {
    final core = _core;
    final duel = _duel;
    if (core == null || duel == null) return Uint8List(0);
    final out = _fieldQueryBuffer ??= Uint8List(_fieldQueryBufferSize);
    try {
      final len = core.queryFieldCard(
        duel,
        player,
        location,
        queryFlag,
        out,
        0, // useCache=0：场态查询必须拿到当前时刻的最新值
      );
      if (len <= 0) return Uint8List(0);
      return Uint8List.sublistView(out, 0, len);
    } catch (e) {
      console.log('DuelEngine: queryFieldCard error $e');
      return Uint8List(0);
    }
  }

  Future<void> _pumpLoop() async {
    // 自动应答保护：连续应答上限，防止无效应答导致 MSG_RETRY 死循环
    var autoAnswers = 0;
    var emptyWaitRetries = 0;
    _sawRetryInPump = false;
    while (true) {
      final result = _core!.process(_duel!);
      final status = result & PROCESSOR_FLAG;
      final msgLen = result & PROCESSOR_BUFFER_LEN;
      var emitResult = const _EmitGameMsgResult();

      if (msgLen > 0) {
        final buf = Uint8List(msgLen);
        _core!.getMessage(_duel!, buf);
        emitResult = _emitGameMsg(buf);
      }

      if (status == PROCESSOR_WAITING) {
        if (_pendingSelectPlayer == _aiPlayer && await _tryAutoAnswer()) {
          emptyWaitRetries = 0;
          if (++autoAnswers > 512) {
            console.log('DuelEngine: AI auto-answer limit reached, bail');
            break;
          }
          continue;
        }

        if (emitResult.emittedRetry) {
          // MSG_RETRY 表示上一条响应非法；保持 WAITING，等客户端重新应答。
          emptyWaitRetries = 0;
          break;
        }

        if (_pendingSelectPlayer == null &&
            emitResult.emittedNonBlockingWaitMessage) {
          // PROCESSOR_WAIT 会返回 WAITING | buffer_size，用于把展示类消息
          // （如 MSG_CONFIRM_CARDS / CONFIRM_DECKTOP / CONFIRM_EXTRATOP）
          // 先吐给客户端，再在下一轮继续推进；这类消息不需要 CTOS_RESPONSE。
          emptyWaitRetries = 0;
          continue;
        }

        if (_pendingSelectPlayer == null && msgLen == 0) {
          // 对照 ygopro / YGOProUnity_V2：有些脚本会先经过一拍空的
          // PROCESSOR_WAITING，再在后续 process() 中吐出真正的下一条消息。
          // MSG_CONFIRM_CARDS 就会命中这条路径，不能立刻当成“等待客户端应答”。
          if (++emptyWaitRetries <= 5) {
            console.log(
              'DuelEngine: WAITING with no pending select and empty message, retry process()',
            );
            continue;
          }
          console.log(
            'DuelEngine: WAITING with no pending select persists, bail',
          );
          break;
        }

        if (_pendingSelectPlayer == null) {
          emptyWaitRetries = 0;
          console.log(
            'DuelEngine: WAITING with non-select message, stop for caller',
          );
          break;
        }

        emptyWaitRetries = 0;
        // 等待人类玩家输入（或无法自动应答的未知消息）
        break;
      }

      if (status == PROCESSOR_END) {
        endDuel();
        break;
      }
    }
  }

  /// 人类玩家应答（CTOS_RESPONSE 原始字节）。
  ///
  /// 返回的 Future 在应答后的 pump 循环结束时完成；调用方需要确认
  /// MSG_RETRY 恢复逻辑生效时应 await。
  Future<void> onResponse(Uint8List data) async {
    if (!_duelStarted || _duel == null || _core == null) return;
    // 引擎等待的必须是人类玩家的应答；AI 的应答已由 _tryAutoAnswer 处理，
    // 其余情况（如非等待状态）直接忽略，避免污染 returns 缓冲。
    if (_pendingSelectPlayer != 0) return;
    final previousFunc = _pendingSelectFunc;
    final previousPlayer = _pendingSelectPlayer;
    final previousPayload = _pendingSelectPayload == null
        ? null
        : Uint8List.fromList(_pendingSelectPayload!);
    _clearPendingSelect();
    _core!.setResponseb(_duel!, data);
    await pump();
    if (_sawRetryInPump) {
      _pendingSelectFunc = previousFunc;
      _pendingSelectPlayer = previousPlayer;
      _pendingSelectPayload = previousPayload;
    }
  }

  /// 残局脚本中 location 参数的符号名映射（脚本用常量名而非数值）。
  static const _puzzleLocations = {
    'LOCATION_DECK': LOCATION_DECK,
    'LOCATION_EXTRA': LOCATION_EXTRA,
  };

  /// 从残局脚本文本统计双方卡组/额外卡组数量。
  /// 返回 [(deck0, extra0), (deck1, extra1)]。
  static List<(int, int)> _puzzleDeckCounts(String text) {
    var d0 = 0, e0 = 0, d1 = 0, e1 = 0;
    final re = RegExp(
      r'Debug\.AddCard\(\s*\d+\s*,\s*(\d+)\s*,\s*\d+\s*,\s*(\w+)',
    );
    for (final m in re.allMatches(text)) {
      final owner = m.group(1)!;
      final loc = _puzzleLocations[m.group(2)];
      if (loc == LOCATION_DECK) {
        owner == '0' ? d0++ : d1++;
      } else if (loc == LOCATION_EXTRA) {
        owner == '0' ? e0++ : e1++;
      }
    }
    return [(d0, e0), (d1, e1)];
  }

  /// 从残局脚本文本解析 Debug.SetPlayerInfo 设置的初始 LP（缺省 8000）。
  static int _puzzleLp(String text, int player) {
    final m = RegExp(
      'Debug\\.SetPlayerInfo\\(\\s*$player\\s*,\\s*(\\d+)',
    ).firstMatch(text);
    return m != null ? int.parse(m.group(1)!) : 8000;
  }

  /// AI 回合自动应答：把待应答消息交给注入的 [DuelAutoAnswer] 策略。
  Future<bool> _tryAutoAnswer() async {
    final answer = _autoAnswer;
    final func = _pendingSelectFunc;
    final payload = _pendingSelectPayload;
    if (answer == null || func == null || payload == null) {
      console.log('DuelEngine: no auto-answer for func $func, stall');
      return false;
    }
    final resp = await answer(func, payload);
    if (resp == null) {
      console.log('DuelEngine: no auto-answer for func $func, stall');
      return false;
    }
    _clearPendingSelect();
    _core!.setResponseb(_duel!, resp);
    return true;
  }

  void _clearPendingSelect() {
    _pendingSelectFunc = null;
    _pendingSelectPlayer = null;
    _pendingSelectPayload = null;
  }

  /// 需要客户端/AI 应答的选择类消息 func 集合。
  static const _selectFuncs = {
    MSG_SELECT_IDLECMD,
    MSG_SELECT_BATTLECMD,
    MSG_SELECT_CARD,
    MSG_SELECT_TRIBUTE,
    MSG_SELECT_UNSELECT_CARD,
    MSG_SELECT_CHAIN,
    MSG_SELECT_EFFECTYN,
    MSG_SELECT_YESNO,
    MSG_SELECT_OPTION,
    MSG_SELECT_PLACE,
    MSG_SELECT_DISFIELD,
    MSG_SELECT_POSITION,
    MSG_SELECT_SUM,
    MSG_SELECT_COUNTER,
    MSG_SORT_CARD,
    MSG_ANNOUNCE_ATTRIB,
    MSG_ANNOUNCE_NUMBER,
    MSG_ANNOUNCE_RACE,
    MSG_ANNOUNCE_CARD,
  };

  /// 不需要客户端应答、但会通过 PROCESSOR_WAIT 暂停一拍的展示类消息。
  static const _nonBlockingWaitFuncs = {
    MSG_CONFIRM_CARDS,
    MSG_CONFIRM_DECKTOP,
    MSG_CONFIRM_EXTRATOP,
  };

  _EmitGameMsgResult _emitGameMsg(Uint8List msg) {
    // 引擎缓冲区可能首尾相接多条消息（如残局 preloadScript 摆场时
    // MSG_AI_NAME/MSG_RELOAD_FIELD/MSG_SHOW_HINT 连写），逐条拆开派发。
    final List<Uint8List> messages;
    try {
      messages = _splitMessages(msg);
    } catch (e) {
      console.log('DuelEngine: split gameMsg failed: $e');
      return const _EmitGameMsgResult();
    }
    var emittedNonBlockingWaitMessage = false;
    var emittedRetry = false;
    for (final m in messages) {
      // 记录待应答消息归属，供 pump 判断 WAITING 是人类还是 AI。
      // 线格式约定（playerop.cpp）：选择类消息载荷首字节即 player。
      console.log(
        'DuelEngine: emit gameMsg func=${m.isNotEmpty ? m[0] : -1} len=${m.length}',
      );
      if (m.isNotEmpty && m[0] == MSG_RETRY) {
        emittedRetry = true;
        _sawRetryInPump = true;
      }
      if (m.isNotEmpty && _nonBlockingWaitFuncs.contains(m[0])) {
        emittedNonBlockingWaitMessage = true;
      }
      if (m.isNotEmpty && _selectFuncs.contains(m[0])) {
        _pendingSelectFunc = m[0];
        _pendingSelectPayload = m.length > 1
            ? Uint8List.sublistView(m, 1)
            : Uint8List(0);
        // 线格式约定（playerop.cpp）：选择类消息载荷首字节即 player；
        // 唯独 MSG_SELECT_SUM 首字节是 mode，player 在第二字节。
        final p = _pendingSelectPayload!;
        _pendingSelectPlayer = m[0] == MSG_SELECT_SUM
            ? (p.length > 1 ? p[1] : null)
            : (p.isNotEmpty ? p[0] : null);
      }
      _emit(m);
    }
    return _EmitGameMsgResult(
      emittedNonBlockingWaitMessage: emittedNonBlockingWaitMessage,
      emittedRetry: emittedRetry,
    );
  }
}

class _EmitGameMsgResult {
  final bool emittedNonBlockingWaitMessage;
  final bool emittedRetry;

  const _EmitGameMsgResult({
    this.emittedNonBlockingWaitMessage = false,
    this.emittedRetry = false,
  });
}
