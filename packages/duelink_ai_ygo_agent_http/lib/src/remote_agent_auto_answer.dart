/// 远端 ygo-agent 模型自动应答层 —— [AgentAutoAnswer] 的远端推理对应物：
/// 局面快照经 HTTP 发给 predict 服务（neos-ts `neos-ai-agent` 协议），
/// 循环状态（rstate / 历史动作）由服务端按 duelId + index 维护。
///
/// ## 与本地 [AgentAutoAnswer] 的差异
///  - 推理：本地 tflite（同步）→ 远端 HTTP（异步），[answer] 因此是
///    `Future<Uint8List?>`，依赖 [DuelEngine] 的异步应答链路；
///  - 动作选择：本地对 select_card/tribute 用完整响应空间 argmax
///    （绕开上游 zip 截断），远端只能拿到服务端下发的 action_preds
///    （与 neos-ts 同等受限：截断使高索引卡不可达、无法提前 finish）；
///  - 历史断裂处理：本地重置 PredictState 续命；远端一旦出错（HTTP
///    失败 / 码表外卡号 / 不支持的消息形状），服务端动作历史已与对局
///    脱节且无法修复，本局剩余时间打日志并返回 null（[broken]，引擎
///    停住等待），下一局 [resetDuel] 重建会话（neos-ts `setDisable`
///    语义）。
///
/// ## 复用
/// 场态簿记 / Input 构建 / 应答字节格式与本地完全一致：
/// [DuelFieldTracker]、[AgentInputBuilder]、agent_answer_utils。
library;

import 'dart:developer' as console;
import 'dart:typed_data';

import 'package:duelink/duelink.dart' show BufferWriter;
import 'package:ocgcore/ocgcore.dart';
import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:duelink_ai_ygo_agent_http/duelink_ai_ygo_agent_http.dart';


/// 远端模型驱动的自动应答器。生命周期与 [AgentAutoAnswer] 一致：
/// 每局开始前 await [resetDuel]；每条对局消息经 [observe] 簿记；
/// player 1 的待应答消息经 [answer] 推理。
class RemoteAgentAutoAnswer implements AgentAutoAnswerer {
  RemoteAgentAutoAnswer({
    required RemotePredictSession session,
    required AgentFieldQuery field,
    CardData? Function(int code)? cardData,
    int startLp = 8000,
  })  : _session = session,
        _field = field,
        _cardData = cardData,
        _startLp = startLp {
    _tracker = DuelFieldTracker(startLp: startLp);
    _builder = AgentInputBuilder(
      field: field,
      tracker: _tracker,
      cardData: cardData,
    );
  }

  final RemotePredictSession _session;
  final AgentFieldQuery _field;
  final CardData? Function(int code)? _cardData;
  int _startLp;

  late DuelFieldTracker _tracker;
  late AgentInputBuilder _builder;

  /// 远端链路已断裂（本局内不可恢复）：后续应答打日志并返回 null。
  bool _broken = false;

  bool get broken => _broken;

  /// 诊断计数：成功产生模型应答的次数（仅统计经远端 predict 成功的应答；
  /// 本地确定性短路如 sort_card/counter 不计入）。
  int _successCount = 0;
  int get successCount => _successCount;

  /// 诊断计数：远端 predict 请求总次数（含多选驱动的每步子请求）。
  int get predictCount => _sessionPredictCount;
  int _sessionPredictCount = 0;

  /// 场态簿记入口：引擎下发的每条对局消息（payload 不含 func 头）。
  @override
  void observe(int func, Uint8List payload) => _tracker.observe(func, payload);

  /// 新局开始：重建 tracker/builder，并在服务端创建新对局会话。
  @override
  Future<void> resetDuel({int? startLp}) async {
    if (startLp != null) _startLp = startLp;
    _tracker = DuelFieldTracker(startLp: _startLp);
    _builder = AgentInputBuilder(
      field: _field,
      tracker: _tracker,
      cardData: _cardData,
    );
    _broken = false;
    _successCount = 0;
    _sessionPredictCount = 0;
    await _session.start();
  }

  /// 自动应答入口（[DuelEngine.setAutoAnswer]）。返回 null = 无法应答。
  @override
  Future<Uint8List?> answer(int func, Uint8List payload) async {
    // ── env 不建模的消息：确定性应答（不经过远端/规则 AI）──
    // 与 AgentAutoAnswer 相同，且这些应答不进入远端会话历史。
    switch (func) {
      case MSG_SORT_CARD:
        // 引擎约定：首字节 0xff = 保持原序（与 SIMPLE_AI 应答一致）。
        return Uint8List.fromList([0xff]);
      case MSG_SELECT_COUNTER:
        return answerSelectCounter(payload);
      case MSG_ANNOUNCE_RACE:
        return answerAnnounceRace(payload);
      case MSG_ANNOUNCE_CARD:
        console.log('RemoteAgentAutoAnswer: announce_card unsupported, '
            'stall');
        return null;
    }

    if (_broken) {
      console.log('RemoteAgentAutoAnswer: broken, stall on func $func');
      return null;
    }

    try {
      final bytes = await _modelAnswer(func, payload);
      _successCount++;
      return bytes;
    } on NotSupportedException catch (e) {
      console.log('RemoteAgentAutoAnswer: func $func unsupported by model '
          '($e), stall for the rest of this duel');
      _broken = true;
      return null;
    } catch (e) {
      console.log('RemoteAgentAutoAnswer: remote error on func $func: $e '
          '— stall for the rest of this duel');
      _broken = true;
      return null;
    }
  }

  // ── 远端推理路径 ─────────────────────────────────────────────────────

  /// 会话 predict 包装：计数 + 委托（诊断用，不改变语义）。
  Future<MsgResponse> _predict(Input input) {
    _sessionPredictCount++;
    return _session.predict(input);
  }

  Future<Uint8List> _modelAnswer(int func, Uint8List payload) async {
    final msg = decodeAgentActionMsg(func, payload);
    final input =
        _builder.build(func: func, payload: payload, toPlay: msg.player);

    final data = msg.data;
    if (data is MsgSelectCard || data is MsgSelectTribute) {
      return _driveSelectCards(input, data);
    }
    if (data is MsgSelectSum) {
      return _driveSelectSum(input, data);
    }

    // 单步消息：一次 predict 直接出结果。
    final resp = await _predict(input);
    final chosen = argmaxPreds(resp.actionPreds);
    _session.recordChoice(chosen);
    return _serializeSingle(msg.player, input, resp.actionPreds[chosen],
        chosenPredIdx: chosen);
  }

  /// select_card / select_tribute 多选驱动（neos-ts `sendAIPredictAsResponse`
  /// 多选分支语义）：每选一张把已选下标写入 msg.selected 重跑 predict；
  /// response == -1（跳过位）或达到 max 结束。
  Future<Uint8List> _driveSelectCards(Input base, ActionMsgData first) async {
    final max = switch (first) {
      MsgSelectCard m => m.max,
      MsgSelectTribute m => m.max,
      _ => throw StateError('unreachable'),
    };

    final selected = <int>[]; // 已选下标（回写 msg.selected）
    final responses = <int>[]; // 引擎应答值
    var data = first;
    for (var step = 0; step < 64; step++) {
      final input = Input(
        global: base.global,
        cards: base.cards,
        actionMsg: ActionMsg(data: data),
      );
      final resp = await _predict(input);
      final chosen = argmaxPreds(resp.actionPreds);
      _session.recordChoice(chosen);
      final pred = resp.actionPreds[chosen];

      if (pred.response == -1) return multiSelectBytes(responses);
      selected.add(chosen);
      responses.add(pred.response);
      if (selected.length >= max) return multiSelectBytes(responses);

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

  /// select_sum 多选驱动（neos-ts 语义）：must 卡自动计入；
  /// 所选卡使任一组合耗尽（canFinish）即结束。
  Future<Uint8List> _driveSelectSum(Input base, MsgSelectSum first) async {
    final must = first.mustCards.length;
    final selected = <int>[];
    var data = first;
    for (var step = 0; step < 64; step++) {
      final input = Input(
        global: base.global,
        cards: base.cards,
        actionMsg: ActionMsg(data: data),
      );
      final resp = await _predict(input);
      final chosen = argmaxPreds(resp.actionPreds);
      _session.recordChoice(chosen);
      final pred = resp.actionPreds[chosen];
      selected.add(pred.response);
      if (pred.canFinish) return sumSelectBytes(must, selected);
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

  /// 单步消息应答序列化（neos-ts 各消息分支语义）。
  ///
  /// [chosenPredIdx] 是 [pred] 在 action_preds 中的下标；place/disfield
  /// 消息以下标回查 places（单步消息 preds 与 places 一一对应）。
  Uint8List _serializeSingle(int player, Input input, ActionPredict pred,
      {required int chosenPredIdx}) {
    final w = BufferWriter();
    switch (input.actionMsg.data) {
      case MsgSelectPlace m:
        final (plr, loc, seq) = _placeBytes(m.places[chosenPredIdx], player);
        w
          ..writeUint8(plr)
          ..writeUint8(loc)
          ..writeUint8(seq);
      case MsgSelectDisfield m:
        final (plr, loc, seq) = _placeBytes(m.places[chosenPredIdx], player);
        w
          ..writeUint8(plr)
          ..writeUint8(loc)
          ..writeUint8(seq);
      case MsgSelectUnselectCard _:
        if (pred.response == -1) {
          w.writeInt32(-1); // finish/cancel
        } else {
          w
            ..writeUint8(1)
            ..writeUint8(pred.response);
        }
      default:
        // idlecmd/battlecmd/chain/effectyn/yesno/option/position/
        // announce_attrib/announce_number：引擎读 returns.ivalue[0]，
        // response 即应答值（与本地 LegalAction.response 同一语义空间）。
        w.writeInt32(pred.response);
    }
    return w.toBytes();
  }

  /// agent schema 的 Place（controller 为相对视角）→ 应答字节
  /// （neos-ts select_place 分支）：我方区域 plr = player，
  /// 对方区域 plr = 1 - player。
  (int, int, int) _placeBytes(Place place, int player) {
    final plr = place.controller == Controller.me ? player : 1 - player;
    final loc = switch (place.location) {
      Location.mzone => LOCATION_MZONE,
      Location.szone => LOCATION_SZONE,
      _ => throw StateError('invalid place location: ${place.location}'),
    };
    return (plr, loc, place.sequence);
  }
}
