/// ygo-agent 模型自动应答层 —— 把 [DuelEngine] 的 `DuelAutoAnswer` 钩子
/// 接到端侧模型推理。
///
/// ## 数据流
/// ```
/// 引擎 WAITING(player 1) → answer(func, payload)
///   → decodeAgentActionMsg（env 语义解码）
///   → AgentInputBuilder（场态查询 → cards/global 观测）
///   → predict（legal actions + 模型推理 + 历史动作推进）
///   → argmax 选动作 → 序列化为引擎应答字节
/// ```
///
/// ## 与上游推理链的对应关系
/// 上游 = ygoinf server（predict）+ 客户端（选动作 + 组字节）。
/// 客户端代码未随仓库发布，本层按 env（ygopro.h）的应答回调逐条复刻：
///  - 多选（select_card/tribute）：env `init_multi_select` 状态机 ——
///    每选一张重跑一次 predict（更新 selected），`ms_idx_ == ms_max_-1`
///    时本步之后强制结束；应答 `[n][idx...]`；
///  - select_sum：env `_callback_multi_select_2` —— 所选卡使任一组合
///    耗尽（canFinish）即结束；应答 `[must+n][must 个 0][idx...]`
///    （引擎忽略前 must 个字节，must 卡自动计入）;
///  - unselect：单步，选卡 `[1][idx]`、结束/取消 int32 -1；
///  - place/disfield：`[plr][loc][seq]`，对方区域 plr = 1 - player；
///  - 其余单步消息：int32 = LegalAction.response（与 env 各回调一致）。
///
/// ## 动作选择空间（多选卡）
/// select_card/tribute 的 `MsgResponse.actionPreds` 因上游 `zip(probs,
/// responses, can_finish)` 截断只覆盖响应空间前几个槽位（can_finish 未随
/// -1 插入补齐）——按它 argmax 会令高索引卡永远不可达、且永远无法提前
/// finish。这里改为对 [PredictState.recordedProbs]（完整响应空间，含 -1
/// 跳过位）做 argmax：与训练时 env 全部合法动作可达的语义一致。
/// select_sum 的 preds 无截断（can_finish 随跳过位补齐），直接使用。
///
/// ## 回退策略
/// 模型不支持的形状（env 抛 NotImplementedError 的分支）、码表外的卡号、
/// 以及 env 本身不建模的消息（sort_card / select_counter /
/// announce_race）走显式回退：前三类交给注入的 [fallback]（规则 AI），
/// 后三类用与引擎校验兼容的确定性应答（sort 保持原序、counter 贪心
/// 分配、race 取前 N 个可用种族）。
library;

import 'dart:developer' as console;
import 'dart:typed_data';

import 'package:duelink/duelink.dart' show BufferReader, BufferWriter;
import 'package:ocgcore/ocgcore.dart';
import 'package:ygo_agent/ygo_agent.dart';

import 'action_msg_decoder.dart';
import 'agent_input_builder.dart';
import 'duel_field_tracker.dart';
import 'field_query.dart';

/// 模型运行时捆绑：推理函数 + 训练码表（+ 可选资源释放回调）。
class AgentRuntime {
  AgentRuntime({required this.modelFn, required this.codeList, this.dispose});

  final ModelFn modelFn;
  final CodeList codeList;

  /// 释放底层资源（如 tflite interpreter）；连接断开时调用。
  final void Function()? dispose;
}

/// 模型驱动的自动应答器。
///
/// 每局开始前调用 [resetDuel]；引擎下发的每条对局消息经 [observe] 记账
/// （LP/回合/阶段/revealed）；player 1 的待应答消息经 [answer] 推理。
class AgentAutoAnswer {
  AgentAutoAnswer({
    required AgentRuntime runtime,
    required AgentFieldQuery field,
    required DuelAutoAnswer fallback,
    CardData? Function(int code)? cardData,
    int startLp = 8000,
  })  : _runtime = runtime,
        _field = field,
        _fallback = fallback,
        _cardData = cardData,
        _startLp = startLp {
    _tracker = DuelFieldTracker(startLp: startLp);
    _builder = AgentInputBuilder(
      field: field,
      tracker: _tracker,
      cardData: cardData,
    );
    _state = PredictState(codeList: runtime.codeList);
  }

  final AgentRuntime _runtime;
  final AgentFieldQuery _field;
  final DuelAutoAnswer _fallback;
  final CardData? Function(int code)? _cardData;
  int _startLp;

  late DuelFieldTracker _tracker;
  late AgentInputBuilder _builder;
  late PredictState _state;

  /// 上一条由模型应答的消息所选动作（响应空间索引），供下一次 predict
  /// 写入历史动作。null 表示尚无可消费的历史（首条消息 / 状态重置后）。
  int? _prevActionIdx;

  /// 场态簿记入口：引擎下发的每条对局消息（payload 不含 func 头）。
  void observe(int func, Uint8List payload) => _tracker.observe(func, payload);

  /// 新局开始：重建 tracker / builder / 模型状态。
  void resetDuel({int? startLp}) {
    if (startLp != null) _startLp = startLp;
    _tracker = DuelFieldTracker(startLp: _startLp);
    _builder = AgentInputBuilder(
      field: _field,
      tracker: _tracker,
      cardData: _cardData,
    );
    _resetModelState();
  }

  /// 自动应答入口（[DuelEngine.setAutoAnswer]）。返回 null = 无法应答。
  Uint8List? answer(int func, Uint8List payload) {
    // ── env 不建模的消息：确定性应答（不经过模型/规则 AI）──
    switch (func) {
      case MSG_SORT_CARD:
        // 引擎约定：首字节 0xff = 保持原序（与 SIMPLE_AI 应答一致）。
        return Uint8List.fromList([0xff]);
      case MSG_SELECT_COUNTER:
        return _answerSelectCounter(payload);
      case MSG_ANNOUNCE_RACE:
        return _answerAnnounceRace(payload);
      case MSG_ANNOUNCE_CARD:
        // 卡名宣告：需要解析 opcode 候选表，env 之外的额外工作，
        // 实战极罕见 —— 交给规则 AI（通常也无解，引擎停住并打日志）。
        console.log('AgentAutoAnswer: announce_card unsupported, fallback');
        return _fallbackAnswer(func, payload);
    }

    try {
      return _modelAnswer(func, payload);
    } on NotSupportedException catch (e) {
      console.log('AgentAutoAnswer: func $func unsupported by model '
          '($e), fallback to rule AI');
      return _fallbackAnswer(func, payload);
    } catch (e) {
      console.log('AgentAutoAnswer: model error on func $func: $e '
          '— reset model state, fallback to rule AI');
      return _fallbackAnswer(func, payload);
    }
  }

  // ── 模型路径 ─────────────────────────────────────────────────────────

  Uint8List _modelAnswer(int func, Uint8List payload) {
    final msg = decodeAgentActionMsg(func, payload);
    final input =
        _builder.build(func: func, payload: payload, toPlay: msg.player);

    // 码表外的卡号会在 encodeCards 抛错；提前检查，避免污染模型状态。
    for (final c in input.cards) {
      if (c.code != 0 && !_runtime.codeList.contains(c.code)) {
        throw NotSupportedException('card ${c.code} not in code_list');
      }
    }

    final data = msg.data;
    if (data is MsgSelectCard || data is MsgSelectTribute) {
      return _driveSelectCards(input, data);
    }
    if (data is MsgSelectSum) {
      return _driveSelectSum(input, data);
    }

    // 单步消息：一次 predict 直接出结果。
    final resp = predict(_runtime.modelFn, input, _prevActionIdx, _state);
    final chosen = _argmaxPreds(resp.actionPreds);
    _prevActionIdx = chosen;
    return _serializeSingle(func, msg.player, input, chosen);
  }

  /// select_card / select_tribute 多选驱动（env `init_multi_select`
  /// mode 0 语义）：每选一张重跑 predict；到达 max 强制结束。
  Uint8List _driveSelectCards(Input base, ActionMsgData first) {
    final max = switch (first) {
      MsgSelectCard m => m.max,
      MsgSelectTribute m => m.max,
      _ => throw StateError('unreachable'),
    };
    final nCards = switch (first) {
      MsgSelectCard m => m.cards.length,
      MsgSelectTribute m => m.cards.length,
      _ => throw StateError('unreachable'),
    };

    final selected = <int>[];
    var data = first;
    for (var step = 0; step < 64; step++) {
      final input = Input(
        global: base.global,
        cards: base.cards,
        actionMsg: ActionMsg(data: data),
      );
      final resp = predict(_runtime.modelFn, input, _prevActionIdx, _state);

      final int slot; // 响应空间槽位：卡索引，或 finish
      if (resp.winRate == -1) {
        // nActions==1 捷径：唯一动作直接选中。
        _prevActionIdx = 0;
        final only = resp.actionPreds[0];
        if (only.response == -1) return _multiBytes(selected);
        selected.add(only.response);
        if (selected.length >= max) return _multiBytes(selected);
        slot = -1; // 已处理，跳过 full-probs 分支
      } else {
        final probs = _state.recordedProbs!;
        slot = _argmaxFullProbs(probs);
        _prevActionIdx = slot;
        if (slot >= nCards) return _multiBytes(selected); // finish 槽
        selected.add(slot);
        if (selected.length >= max) return _multiBytes(selected);
      }

      data = switch (data) {
        MsgSelectCard m => MsgSelectCard(
            cancelable: m.cancelable,
            min: m.min,
            max: m.max,
            cards: m.cards,
            selected: List<int>.of(selected),
          ),
        MsgSelectTribute m => MsgSelectTribute(
            cancelable: m.cancelable,
            min: m.min,
            max: m.max,
            cards: m.cards,
            selected: List<int>.of(selected),
          ),
        _ => throw StateError('unreachable'),
      };
    }
    throw StateError('select_card/tribute loop did not converge');
  }

  /// select_sum 多选驱动（env `_callback_multi_select_2` 语义）：
  /// 所选卡使任一组合耗尽（canFinish）即结束。
  Uint8List _driveSelectSum(Input base, MsgSelectSum first) {
    final must = first.mustCards.length;
    final selected = <int>[];
    var data = first;
    for (var step = 0; step < 64; step++) {
      final input = Input(
        global: base.global,
        cards: base.cards,
        actionMsg: ActionMsg(data: data),
      );
      final MsgResponse resp;
      try {
        resp = predict(_runtime.modelFn, input, _prevActionIdx, _state);
      } on NotSupportedException catch (e) {
        // 'empty select in select_sum' = 当前选择恰好完成一个组合。
        if (e.message.contains('empty select')) {
          return _sumBytes(must, selected);
        }
        rethrow;
      }
      final chosen = _argmaxPreds(resp.actionPreds);
      _prevActionIdx = chosen;
      final pred = resp.actionPreds[chosen];
      selected.add(pred.response);
      if (pred.canFinish) return _sumBytes(must, selected);
      data = MsgSelectSum(
        overflow: data.overflow,
        levelSum: data.levelSum,
        min: data.min,
        max: data.max,
        cards: data.cards,
        mustCards: data.mustCards,
        selected: List<int>.of(selected),
      );
    }
    throw StateError('select_sum loop did not converge');
  }

  /// 单步消息应答序列化（env 各消息回调的字节格式）。
  Uint8List _serializeSingle(
      int func, int player, Input input, int chosenPredIdx) {
    // preds 与 legalActions 一一对应（非多选消息无 zip 截断）。
    final legalActions = getLegalActions(input.actionMsg, _runtime.codeList);
    final action = legalActions[chosenPredIdx];
    final w = BufferWriter();
    switch (func) {
      case MSG_SELECT_PLACE || MSG_SELECT_DISFIELD:
        final (plr, loc, seq) = _placeBytes(action.place, player);
        w.writeUint8(plr);
        w.writeUint8(loc);
        w.writeUint8(seq);
      case MSG_SELECT_UNSELECT_CARD:
        if (action.response == -1) {
          w.writeInt32(-1); // finish/cancel
        } else {
          w.writeUint8(1);
          w.writeUint8(action.response);
        }
      default:
        // idlecmd/battlecmd/chain/effectyn/yesno/option/position/
        // announce_attrib/announce_number：引擎读 returns.ivalue[0]。
        w.writeInt32(action.response);
    }
    return w.toBytes();
  }

  /// ActionPlace → 应答字节（env select_place/disfield 回调语义）：
  /// 我方区域 plr = player，对方区域 plr = 1 - player。
  (int, int, int) _placeBytes(ActionPlace place, int player) {
    final id = placeToId[place];
    if (id == null || place == ActionPlace.none) {
      throw StateError('invalid place action: $place');
    }
    if (id <= 7) return (player, LOCATION_MZONE, id - 1); // m1..m7
    if (id <= 15) return (player, LOCATION_SZONE, id - 8); // s1..s8
    if (id <= 22) return (1 - player, LOCATION_MZONE, id - 16); // om1..om7
    return (1 - player, LOCATION_SZONE, id - 23); // os1..os8
  }

  // ── argmax ───────────────────────────────────────────────────────────

  /// preds 上的 argmax（跳过 prob == -1；平局取最小索引，同 np.argmax）。
  int _argmaxPreds(List<ActionPredict> preds) {
    var best = -1;
    var bestProb = double.negativeInfinity;
    for (var i = 0; i < preds.length; i++) {
      final p = preds[i].prob;
      if (p == -1) continue;
      if (p > bestProb) {
        bestProb = p;
        best = i;
      }
    }
    if (best < 0) {
      throw StateError('no selectable action (all probs == -1)');
    }
    return best;
  }

  /// 完整响应空间 probs 上的 argmax（-1 = 已选/占位，跳过）。
  int _argmaxFullProbs(List<double> probs) {
    var best = -1;
    var bestProb = double.negativeInfinity;
    for (var i = 0; i < probs.length; i++) {
      final p = probs[i];
      if (p == -1) continue;
      if (p > bestProb) {
        bestProb = p;
        best = i;
      }
    }
    if (best < 0) {
      throw StateError('no selectable action (all probs == -1)');
    }
    return best;
  }

  // ── 字节组装 ─────────────────────────────────────────────────────────

  /// select_card/tribute 应答：[count][idx...]。
  Uint8List _multiBytes(List<int> selected) {
    final w = BufferWriter()..writeUint8(selected.length);
    for (final i in selected) {
      w.writeUint8(i);
    }
    return w.toBytes();
  }

  /// select_sum 应答：[must+n][must 个占位 0][idx...]
  /// （引擎跳过前 must 项，must 卡自动计入）。
  Uint8List _sumBytes(int must, List<int> selected) {
    final w = BufferWriter()..writeUint8(must + selected.length);
    for (var i = 0; i < must; i++) {
      w.writeUint8(0);
    }
    for (final i in selected) {
      w.writeUint8(i);
    }
    return w.toBytes();
  }

  // ── 非模型消息的确定性应答 ────────────────────────────────────────────

  /// select_counter：env 不建模（无动作分支）。按引擎校验贪心分配：
  /// 逐卡尽量多放，保证 sum == total 且每卡 ≤ 当前计数器数。
  /// （应答字节不进入观测，不影响模型状态。）
  Uint8List _answerSelectCounter(Uint8List payload) {
    final r = BufferReader(payload);
    r.skip(1); // player
    r.skip(2); // counter type
    final total = r.readUint16();
    final count = r.readUint8();
    final w = BufferWriter();
    var remaining = total;
    for (var i = 0; i < count; i++) {
      r.skip(7); // code u32 + c,l,s
      final cap = r.readUint16();
      final take = remaining > cap ? cap : remaining;
      remaining -= take;
      w.writeInt16(take);
    }
    if (remaining > 0) {
      console.log('AgentAutoAnswer: counter total $total exceeds caps, '
          'response will be rejected (remaining=$remaining)');
    }
    return w.toBytes();
  }

  /// announce_race：env 不建模。取 available 中前 count 个种族位
  /// （引擎校验：所选位必须都在 available 中且数量 == count）。
  Uint8List _answerAnnounceRace(Uint8List payload) {
    final r = BufferReader(payload);
    r.skip(1); // player
    final count = r.readUint8();
    final available = r.readUint32();
    var picked = 0;
    var need = count;
    for (var bit = 0; bit < 32 && need > 0; bit++) {
      if (available & (1 << bit) != 0) {
        picked |= 1 << bit;
        need--;
      }
    }
    return (BufferWriter()..writeInt32(picked)).toBytes();
  }

  // ── 回退 ─────────────────────────────────────────────────────────────

  /// 规则 AI 回退：模型没有应答该消息 → 历史动作链断裂，重置模型状态，
  /// 下一条消息从全新 PredictState 开始（安全降级，避免历史错位）。
  Uint8List? _fallbackAnswer(int func, Uint8List payload) {
    _resetModelState();
    return _fallback(func, payload);
  }

  void _resetModelState() {
    _state = PredictState(codeList: _runtime.codeList);
    _prevActionIdx = null;
  }
}
