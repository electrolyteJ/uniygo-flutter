import 'dart:developer' as console;
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:duelink/duelink.dart';
// ocgcore 与 duelink 都导出部分同名 MSG_* 常量，这里统一以 duelink 为准
import 'package:ocgcore/ocgcore.dart'
    hide
        MSG_SELECT_CARD,
        MSG_SELECT_CHAIN,
        MSG_SELECT_COUNTER,
        MSG_SELECT_DISFIELD,
        MSG_SELECT_EFFECTYN,
        MSG_SELECT_OPTION,
        MSG_SELECT_PLACE,
        MSG_SELECT_POSITION,
        MSG_SELECT_SUM,
        MSG_SELECT_TRIBUTE,
        MSG_SELECT_UNSELECT_CARD,
        MSG_SORT_CARD;

import 'ai_strategy.dart';
import 'card_data_loader.dart';
import 'script_loader.dart';

/// AI 对局引擎 —— 封装 ocgcore 的对局生命周期。
///
/// 职责：初始化 ocgcore、预加载脚本/卡数据、创建并推进对局
/// （process 循环）、解码对局消息、跟踪待应答的选择类消息归属，
/// 并在待应答消息属于 AI 玩家时自动应答（策略见 ai_strategy.dart）。
///
/// 通过 [emit] 回调把 STOC 消息交给外层（AiConnection）派发。
class AiDuelEngine {
  AiDuelEngine({
    required void Function(YgoStocMsg) emit,
    CardDataLoader? cardLoader,
    ScriptLoader? scriptLoader,
  })  : _emit = emit,
        cardLoader = cardLoader ?? CardDataLoader(),
        scriptLoader = scriptLoader ?? ScriptLoader();

  final void Function(YgoStocMsg) _emit;
  final CardDataLoader cardLoader;
  final ScriptLoader scriptLoader;

  OcgCore? _core;
  int? _duel;
  bool _duelStarted = false;

  static const int _aiPlayer = 1;

  /// 对局是否已开始（用于房间流程的幂等保护）。
  bool get duelStarted => _duelStarted;

  // ── 待应答的选择类消息（用于识别 WAITING 属于哪一方）──
  int? _pendingSelectFunc;
  int? _pendingSelectPlayer;
  MsgSelectIdleCmd? _pendingIdleCmd;
  MsgSelectBattleCmd? _pendingBattleCmd;
  MsgSelectTribute? _pendingTribute;

  /// 初始化 ocgcore 并注册脚本/卡数据读取回调。成功返回 true。
  Future<bool> init(ffi.DynamicLibrary? lib) async {
    try {
      _core = await createOcgCore(lib);
    } catch (e) {
      console.log('AiDuelEngine: init error $e');
      _core = null;
    }
    if (_core == null) return false;
    _core!.setScriptReader(scriptLoader.load);
    _core!.setCardReader(cardLoader.load);
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

  /// 结束当前对局并通知客户端（对应投降 / 引擎 PROCESSOR_END）。
  void endDuel() {
    _duelStarted = false;
    if (_duel != null && _core != null) {
      try {
        _core!.endDuel(_duel!);
      } catch (_) {}
    }
    _duel = null;
    _clearPendingSelect();
    _emit(YgoStocMsg.duelEnd());
  }

  /// 创建并启动对局：预加载脚本/卡数据 → createDuel → 装载双方卡组 →
  /// 以 DUEL_SIMPLE_AI 开局 → 补发 MSG_START → 推进第一轮 process。
  Future<void> startDuel(List<int> deck) async {
    final core = _core;
    if (core == null || deck.isEmpty) return;

    // 基础脚本必须在 createDuel 之前写入 Dart 侧缓存 —— interpreter 构造时
    // 就会通过同步回调自动加载 ./script/constant.lua、utility.lua、
    // procedure.lua（interpreter.cpp），错过时缓存为空会加载失败，
    // 导致卡牌脚本依赖的常量（REASON_* 等）全部为 nil。
    for (final s in ['constant.lua', 'utility.lua', 'procedure.lua']) {
      await core.preloadScriptAsync(s);
    }

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

    // 预加载是异步的，期间连接可能已断开（dispose 会清空 _core）
    if (!identical(_core, core)) return;

    _duel = core.createDuel(DateTime.now().millisecondsSinceEpoch & 0xffffffff);
    if (_duel == 0) return;

    // 设置双方玩家：人类固定 player 0（先攻方），AI 固定 player 1
    core.setPlayerInfo(_duel!, 0, 8000, 5, 1);
    core.setPlayerInfo(_duel!, 1, 8000, 5, 1);

    // 加载卡组到 ocgcore（双方使用同一副卡组）
    for (int i = 0; i < deck.length; i++) {
      core.newCard(_duel!, deck[i], 0, 0, LOCATION_DECK, i, 0);
      core.newCard(_duel!, deck[i], 1, 1, LOCATION_DECK, i, 0);
    }

    // 使用简单 AI 模式（ocgcore 内置，覆盖范围见 ai_connection.dart 文件头注释）
    core.startDuel(_duel!, DUEL_SIMPLE_AI);
    _duelStarted = true;

    // ocgcore 不直接发出 MSG_START（由服务端合成），这里补发。
    // playerType 与引擎保持一致：0 = 当前视角为先攻方（人类固定先攻）。
    _emit(YgoStocMsg.gameMsg(StocGameMessage(
      func: MSG_START,
      innerMsg: MsgStart(
        playerType: 0,
        masterRule: DuelRule.mr2020.value,
        life1: 8000,
        life2: 8000,
        deckSize1: deck.length,
        extraSize1: 0,
        deckSize2: deck.length,
        extraSize2: 0,
      ),
    )));

    // 同步执行第一轮 process
    _duelLoop();
  }

  /// 人类玩家应答（CTOS_RESPONSE）。
  void onResponse(Uint8List data) {
    if (!_duelStarted || _duel == null || _core == null) return;
    // 引擎等待的必须是人类玩家的应答；AI 的应答已由 _autoAnswer 处理，
    // 其余情况（如非等待状态）直接忽略，避免污染 returns 缓冲。
    if (_pendingSelectPlayer != 0) return;
    _clearPendingSelect();
    _core!.setResponseb(_duel!, data);
    _duelLoop();
  }

  void _duelLoop() {
    // 自动应答保护：连续应答上限，防止无效应答导致 MSG_RETRY 死循环
    var autoAnswers = 0;
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
        if (_pendingSelectPlayer == _aiPlayer && _autoAnswer()) {
          if (++autoAnswers > 512) {
            console.log('AiDuelEngine: AI auto-answer limit reached, bail');
            break;
          }
          continue;
        }
        // 等待人类玩家输入（或无法自动应答的未知消息）
        break;
      }

      if (status == PROCESSOR_END) {
        endDuel();
        break;
      }
    }
  }

  /// AI 回合自动应答：根据待应答消息构造响应并喂给引擎（策略为纯函数，
  /// 见 ai_strategy.dart）。
  bool _autoAnswer() {
    final func = _pendingSelectFunc;
    Uint8List? resp;
    if (func == MSG_SELECT_IDLE_CMD && _pendingIdleCmd != null) {
      resp = aiIdleResponse(_pendingIdleCmd!, cardLoader.levelOf);
    } else if (func == MSG_SELECT_BATTLE_CMD && _pendingBattleCmd != null) {
      resp = aiBattleResponse(_pendingBattleCmd!);
    } else if (func == MSG_SELECT_TRIBUTE && _pendingTribute != null) {
      resp = aiTributeResponse(_pendingTribute!);
    }
    if (resp == null) {
      console.log('AiDuelEngine: no auto-answer for func $func, stall');
      return false;
    }
    _clearPendingSelect();
    _core!.setResponseb(_duel!, resp);
    return true;
  }

  void _clearPendingSelect() {
    _pendingSelectFunc = null;
    _pendingSelectPlayer = null;
    _pendingIdleCmd = null;
    _pendingBattleCmd = null;
    _pendingTribute = null;
  }

  /// 需要客户端/AI 应答的选择类消息 func 集合。
  static const _selectFuncs = {
    MSG_SELECT_IDLE_CMD,
    MSG_SELECT_BATTLE_CMD,
    MSG_SELECT_CARD,
    MSG_SELECT_TRIBUTE,
    MSG_SELECT_UNSELECT_CARD,
    MSG_SELECT_CHAIN,
    MSG_SELECT_EFFECTYN,
    MSG_SELECT_YES_NO,
    MSG_SELECT_OPTION,
    MSG_SELECT_PLACE,
    MSG_SELECT_DISFIELD,
    MSG_SELECT_POSITION,
    MSG_SELECT_SUM,
    MSG_SELECT_COUNTER,
    MSG_SORT_CARD,
  };

  void _emitGameMsg(Uint8List msg) {
    final StocGameMessage gm;
    try {
      gm = StocGameMessage.decode(msg);
    } catch (e) {
      console.log('AiDuelEngine: decode gameMsg failed: $e');
      return;
    }
    // 记录待应答消息归属，供 _duelLoop 判断 WAITING 是人类还是 AI
    if (_selectFuncs.contains(gm.func)) {
      _pendingSelectFunc = gm.func;
      int? player;
      try {
        player = (gm.innerMsg as dynamic).player as int?;
      } catch (_) {}
      _pendingSelectPlayer = player;
      if (gm.func == MSG_SELECT_IDLE_CMD && gm.innerMsg is MsgSelectIdleCmd) {
        _pendingIdleCmd = gm.innerMsg as MsgSelectIdleCmd;
      } else if (gm.func == MSG_SELECT_BATTLE_CMD &&
          gm.innerMsg is MsgSelectBattleCmd) {
        _pendingBattleCmd = gm.innerMsg as MsgSelectBattleCmd;
      } else if (gm.func == MSG_SELECT_TRIBUTE &&
          gm.innerMsg is MsgSelectTribute) {
        _pendingTribute = gm.innerMsg as MsgSelectTribute;
      }
    }
    _emit(YgoStocMsg.gameMsg(gm));
  }
}
