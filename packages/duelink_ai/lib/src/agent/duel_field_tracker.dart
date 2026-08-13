/// 对局场态跟踪器 —— 以 ygo-agent env（ygopro.h）为基准移植的
/// LP / 回合 / 阶段 / 已公开卡牌簿记。
///
/// 构建器（[AgentInputBuilder]）需要的全局特征与"隐藏卡"判定依赖这里
/// 的状态；上层（AiConnection）在每条引擎消息下发时调用 [observe]。
library;

import 'dart:typed_data';

import 'package:duelink/duelink.dart' show BufferReader;
import 'package:ocgcore/ocgcore.dart';

class DuelFieldTracker {
  DuelFieldTracker({int startLp = 8000}) {
    reset(startLp);
  }

  /// 双方当前 LP（下标 = 玩家 id）。env 不做钳制，这里同样不钳制。
  final List<int> lp = [0, 0];

  /// MSG_NEW_TURN 累计次数（encode_global 侧 clamp 到 16）。
  int turn = 0;

  /// 当前回合玩家 id（最近一条 MSG_NEW_TURN 的载荷）。
  int turnPlayer = 0;

  /// 最近一条 MSG_NEW_PHASE 的原始值（PHASE_* 位）。
  int rawPhase = PHASE_DRAW;

  /// 已对 [player] 公开过的卡牌 spec 集合（env `revealed_`）。
  ///
  /// spec 由 [lsToSpec] 生成（与 env `ls_to_spec` 一致），
  /// CONFIRM_CARDS 时按 `(loc, seq, 0, opponent)` 插入。
  final Set<String> revealed = {};

  /// 新一局开始时调用（[startLp] 双方初始 LP）。
  void reset(int startLp) {
    lp[0] = startLp;
    lp[1] = startLp;
    turn = 0;
    turnPlayer = 0;
    rawPhase = PHASE_DRAW;
    revealed.clear();
  }

  /// 喂入一条引擎消息（func + 不含 func 头的载荷）。
  /// 只处理影响模型输入的几类消息，其余忽略。
  void observe(int func, Uint8List payload) {
    switch (func) {
      case MSG_NEW_TURN:
        if (payload.isEmpty) return;
        turn++;
        turnPlayer = payload[0];
      case MSG_NEW_PHASE:
        if (payload.length < 2) return;
        rawPhase = payload[0] | (payload[1] << 8);
      case MSG_DAMAGE:
        _applyLpDelta(payload, sign: -1);
      case MSG_RECOVER:
        _applyLpDelta(payload, sign: 1);
      case MSG_PAY_LPCOST:
        _applyLpDelta(payload, sign: -1);
      case MSG_LPUPDATE:
        // 线格式 [player u8][newLp u32]：绝对值覆写（env 转成差值记账，
        // 这里直接覆写等价）。
        if (payload.length < 5) return;
        final r = BufferReader(payload);
        final player = r.readUint8();
        final newLp = r.readUint32();
        if (player < 2) lp[player] = newLp;
      case MSG_CONFIRM_CARDS:
        _observeConfirmCards(payload);
    }
  }

  void _applyLpDelta(Uint8List payload, {required int sign}) {
    // 线格式 [player u8][value u32]（duelink 按 int8/int32 解读，字节一致）。
    if (payload.length < 5) return;
    final r = BufferReader(payload);
    var player = r.readInt8();
    final value = r.readUint32();
    if (player != 0 && player != 1) player &= 1;
    lp[player] += sign * value;
  }

  void _observeConfirmCards(Uint8List payload) {
    // 本 fork 线格式：[player u8][skipPanel u8][count u8]
    //                 + count × [code u32][c u8][l u8][s u8]
    if (payload.length < 3) return;
    final r = BufferReader(payload);
    final player = r.readUint8();
    r.skip(1); // skipPanel
    final count = r.readUint8();
    for (var i = 0; i < count; i++) {
      if (r.remaining < 7) return;
      r.skip(4); // code —— revealed 只记位置，不记卡号
      final c = r.readUint8();
      final l = r.readUint8();
      final s = r.readUint8();
      revealed.add(lsToSpec(l, s, 0, opponent: c == player));
    }
  }

  /// env `ls_to_spec(loc, seq, pos, opponent)` 的 1:1 移植。
  ///
  /// 注意与 ygo_agent `toSpec` 的差异：overlay 后缀在这里是单个字符
  /// `'a' + pos`（env 语义）；`toSpec` 写 `a${n+1}`。本函数只用于
  /// revealed 簿记（插入与查找都经过它），不进入特征编码。
  static String lsToSpec(int loc, int seq, int pos,
      {required bool opponent}) {
    final buf = StringBuffer();
    if (loc & LOCATION_HAND != 0) {
      buf.write('h');
    } else if (loc & LOCATION_MZONE != 0) {
      buf.write('m');
    } else if (loc & LOCATION_SZONE != 0) {
      buf.write('s');
    } else if (loc & LOCATION_GRAVE != 0) {
      buf.write('g');
    } else if (loc & LOCATION_REMOVED != 0) {
      buf.write('r');
    } else if (loc & LOCATION_EXTRA != 0) {
      buf.write('x');
    }
    buf.write(seq + 1);
    if (loc & LOCATION_OVERLAY != 0) {
      buf.writeCharCode(0x61 + pos); // 'a' + pos（单字符）
    }
    var spec = buf.toString();
    if (opponent) spec = 'o$spec';
    return spec;
  }
}
