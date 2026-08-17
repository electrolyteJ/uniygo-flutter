/// 模型自动应答的共享工具：应答字节组装、argmax、确定性应答。
///
/// 本地推理（[AgentAutoAnswer]）与远端 HTTP 推理（RemoteAgentAutoAnswer）
/// 走同一套引擎应答字节格式（env 各消息回调语义）与动作选择辅助，
/// 集中在此避免两处漂移。
library;

import 'dart:developer' as console;
import 'dart:typed_data';

import 'package:duelink/duelink.dart' show BufferReader, BufferWriter;
import '../predict.dart' show ActionPredict;

// ── 字节组装 ─────────────────────────────────────────────────────────

/// select_card/tribute 应答：[count][idx...]。
Uint8List multiSelectBytes(List<int> selected) {
  final w = BufferWriter()..writeUint8(selected.length);
  for (final i in selected) {
    w.writeUint8(i);
  }
  return w.toBytes();
}

/// select_sum 应答：[must+n][must 个占位 0][idx...]
/// （引擎跳过前 must 项，must 卡自动计入）。
Uint8List sumSelectBytes(int must, List<int> selected) {
  final w = BufferWriter()..writeUint8(must + selected.length);
  for (var i = 0; i < must; i++) {
    w.writeUint8(0);
  }
  for (final i in selected) {
    w.writeUint8(i);
  }
  return w.toBytes();
}

// ── argmax ───────────────────────────────────────────────────────────

/// preds 上的 argmax（跳过 prob == -1；平局取最小索引，同 np.argmax）。
int argmaxPreds(List<ActionPredict> preds) {
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
int argmaxFullProbs(List<double> probs) {
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

// ── env 不建模消息的确定性应答 ────────────────────────────────────────

/// select_counter：env 不建模（无动作分支）。按引擎校验贪心分配：
/// 逐卡尽量多放，保证 sum == total 且每卡 ≤ 当前计数器数。
/// （应答字节不进入观测，不影响模型状态。）
Uint8List answerSelectCounter(Uint8List payload) {
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
    console.log('agentAnswerUtils: counter total $total exceeds caps, '
        'response will be rejected (remaining=$remaining)');
  }
  return w.toBytes();
}

/// announce_race：env 不建模。取 available 中前 count 个种族位
/// （引擎校验：所选位必须都在 available 中且数量 == count）。
Uint8List answerAnnounceRace(Uint8List payload) {
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
