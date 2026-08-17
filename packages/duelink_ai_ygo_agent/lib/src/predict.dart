/// Prediction glue, ported 1:1 from ygo-agent `ygoinf/features.py`
/// (`predict`, `PredictState`, `add_skipped_back`, `transform_select_idx`,
/// `revert_pad_truncate`).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'code_list.dart';
import 'constants.dart';
import 'enums.dart';
import 'features.dart';
import 'legal_actions.dart';
import 'models.dart';

/// Recurrent state: two float32 vectors of [nRnnChannels] (h and c).
typedef RState = (Float32List, Float32List);

RState initRstate() =>
    (Float32List(nRnnChannels), Float32List(nRnnChannels));

/// Observation tensors for one decision step (upstream `model_input`).
class ModelInput {
  ModelInput({
    required this.cards,
    required this.global,
    required this.actions,
    required this.hActions,
  });

  /// (2*MAX_CARDS * N_CARD_FEATURES) uint8.
  final Uint8List cards;

  /// (N_GLOBAL_FEATURES) uint8.
  final Uint8List global;

  /// (MAX_ACTIONS * N_ACTION_FEATURES) uint8.
  final Uint8List actions;

  /// (N_HISTORY_ACTIONS * H_ACTIONS_FEATS) uint8.
  final Uint8List hActions;
}

/// Result of one model call (upstream `model_fn` return value).
class ModelOutput {
  ModelOutput({
    required this.rstate,
    required this.probs,
    required this.value,
  });

  final RState rstate;

  /// Raw model probabilities, length MAX_ACTIONS.
  final List<double> probs;

  /// Raw value-head output; win rate = (value + 1) / 2.
  final double value;
}

/// (rstate, model_input) -> model output. Backed by tflite on device, or by
/// golden replay in tests.
typedef ModelFn = ModelOutput Function(RState rstate, ModelInput input);

/// One returned action prediction (upstream `ActionPredict`).
class ActionPredict {
  ActionPredict({
    required this.prob,
    required this.response,
    required this.canFinish,
  });

  /// -1 marks actions the model skipped (already-selected cards, ...).
  final double prob;
  final int response;
  final bool canFinish;
}

/// Prediction result for one step (upstream `MsgResponse`).
class MsgResponse {
  MsgResponse({required this.actionPreds, required this.winRate});

  final List<ActionPredict> actionPreds;

  /// -1 when the single-action shortcut was taken.
  final double winRate;
}

/// Mutable per-duel state (upstream `PredictState`).
class PredictState {
  PredictState({required this.codeList});

  final CodeList codeList;
  RState rstate = initRstate();
  int index = 0;
  final HistoryActions historyActions = HistoryActions();

  /// Last built observation, retained for tests/integration tooling.
  ModelInput? lastModelInput;

  /// 最近一次 [predict] 记录的完整响应空间概率（`add_skipped_back` 之后，
  /// 含 -1 跳过位）。select_card/tribute 的 `actionPreds` 因上游 zip 截断
  /// 只覆盖前若干个槽位，集成层做完整空间 argmax 时需要这份数据。
  List<double>? get recordedProbs => _probs;

  List<double>? _probs;
  Uint8List? _actions;
  ActionMsg? _actionMsg;
  int? _turn;
  Phase? _phase;

  void reset() {
    _probs = null;
    _actions = null;
    _actionMsg = null;
    _turn = null;
    _phase = null;
  }

  /// Applies the previous step's chosen action to the history ring buffer.
  /// [idx] is in response space (index into the previous `MsgResponse`).
  void updateHistoryActions(int idx) {
    final idx1 = transformSelectIdx(_probs!, idx, _actionMsg!);
    final action = Uint8List.sublistView(
        _actions!, idx1 * nActionFeatures, (idx1 + 1) * nActionFeatures);
    historyActions.update(action, _turn!, _phase!);
    reset();
  }

  void record(Input input, Uint8List actions, List<double> probs) {
    _probs = probs;
    _actions = actions;
    _actionMsg = input.actionMsg;
    _turn = input.global.turn;
    _phase = input.global.phase;
  }
}

/// Python `transform_select_idx`: maps a response-space index back to the
/// model action index (skipping prob == -1 entries) for the select_card /
/// select_tribute / select_sum messages.
int transformSelectIdx(List<double> probs, int idx, ActionMsg actionMsg) {
  if (probs[idx] == -1) {
    throw ArgumentError('Invalid action selected (prob == -1)');
  }
  var k = idx;
  final msgType = actionMsg.data.msgType;
  if (msgType == MsgName.selectCard ||
      msgType == MsgName.selectTribute ||
      msgType == MsgName.selectSum) {
    k = 0;
    for (var i = 0; i < probs.length; i++) {
      if (probs[i] != -1) {
        if (i == idx) {
          break;
        }
        k += 1;
      }
    }
  }
  return k;
}

/// Python `add_skipped_back`: re-inserts prob -1 entries for actions the
/// model skipped, returning (probs, responses, can_finish).
(List<double>, List<int>, List<bool>) addSkippedBack(
    List<double> probsIn, List<LegalAction> legalActions, ActionMsg actionMsg) {
  final probs = List<double>.of(probsIn);
  final msgType = actionMsg.data.msgType;
  final responses = [for (final a in legalActions) a.response];
  var canFinish = List<bool>.filled(responses.length, false);
  if (msgType == MsgName.selectCard ||
      msgType == MsgName.selectTribute ||
      msgType == MsgName.selectSum) {
    canFinish = [for (final a in legalActions) a.canFinish];
    if (msgType == MsgName.selectSum) {
      final msg = actionMsg.data as MsgSelectSum;
      final skipped = [
        for (var i = 0; i < msg.cards.length; i++)
          if (!responses.contains(msg.cards[i].response)) i,
      ];
      for (final i in skipped) {
        probs.insert(i, -1);
        responses.insert(i, msg.cards[i].response);
        canFinish.insert(i, false);
      }
    } else {
      final data = actionMsg.data;
      final selected = switch (data) {
        MsgSelectCard m => m.selected,
        MsgSelectTribute m => m.selected,
        _ => throw StateError('unreachable'),
      };
      final cardResponses = switch (data) {
        MsgSelectCard m => [for (final c in m.cards) c.response],
        MsgSelectTribute m => [for (final c in m.cards) c.response],
        _ => throw StateError('unreachable'),
      };
      for (final i in selected) {
        probs.insert(i, -1);
        responses.insert(i, cardResponses[i]);
      }
      if (probs.length == cardResponses.length) {
        // finish
        probs.add(-1);
        responses.add(-1);
      }
    }
  }
  return (probs, responses, canFinish);
}

/// Python `revert_pad_truncate`.
List<double> revertPadTruncate(List<double> probs, int nActions) {
  if (probs.length < nActions) {
    return [
      ...probs,
      ...List<double>.filled(nActions - probs.length, -1),
    ];
  } else if (probs.length > nActions) {
    return probs.sublist(0, nActions);
  }
  return probs;
}

/// Python `predict`.
///
/// [prevActionIdx] is the response-space index chosen at the previous step
/// (ignored on the first step). Returns the [MsgResponse]; [state] is
/// advanced (rstate, history ring buffer, index).
MsgResponse predict(
    ModelFn modelFn, Input input, int? prevActionIdx, PredictState state) {
  if (state.index != 0) {
    state.updateHistoryActions(prevActionIdx!);
  }

  final legalActions = getLegalActions(input.actionMsg, state.codeList);
  final nActions = legalActions.length;

  final cardsEncoding = encodeCards(input.cards, state.codeList);
  final globalTensor = encodeGlobal(input.global, input.cards);
  final actionsTensor =
      encodeLegalActions(legalActions, cardsEncoding.specInfos);
  final hActionsTensor = state.historyActions.encode(input.global.turn);
  final modelInput = ModelInput(
    cards: cardsEncoding.tensor,
    global: globalTensor,
    actions: actionsTensor,
    hActions: hActionsTensor,
  );
  state.lastModelInput = modelInput;

  List<double> probs;
  List<int> responses;
  List<bool> canFinish;
  double winRate;
  if (nActions == 1) {
    probs = [1.0];
    responses = [legalActions[0].response];
    winRate = -1;
    canFinish = [legalActions[0].canFinish];
  } else {
    final out = modelFn(state.rstate, modelInput);
    state.rstate = out.rstate;
    probs = revertPadTruncate(out.probs, nActions);
    assert(probs.length == nActions);
    (probs, responses, canFinish) =
        addSkippedBack(probs, legalActions, input.actionMsg);
    winRate = (out.value + 1) / 2;
  }
  assert(probs.length == responses.length);
  // Upstream builds preds via zip(probs, responses, can_finish), which
  // truncates to the shortest list (can_finish can be shorter after
  // select_card/tribute finish entries were appended).
  final n = math.min(probs.length, math.min(responses.length, canFinish.length));
  final preds = [
    for (var i = 0; i < n; i++)
      ActionPredict(
        prob: probs[i],
        response: responses[i],
        canFinish: canFinish[i],
      ),
  ];
  final result = MsgResponse(actionPreds: preds, winRate: winRate);
  state.record(input, actionsTensor, probs);
  state.index += 1;
  return result;
}
