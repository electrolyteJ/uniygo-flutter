import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_NEW_PHASE (0x29) — 阶段切换通知。
class MsgNewPhase {
  final int phase;

  const MsgNewPhase({required this.phase});

  int get rawPhase => phase;
  bool get isDraw => phase == PHASE_DRAW;
  bool get isStandby => phase == PHASE_STANDBY;
  bool get isMain1 => phase == PHASE_MAIN1;
  bool get isBattleStart => phase == PHASE_BATTLE_START;
  bool get isBattleStep => phase == PHASE_BATTLE_STEP;
  bool get isDamage => phase == PHASE_DAMAGE;
  bool get isDamageCal => phase == PHASE_DAMAGE_CAL;
  bool get isBattle => phase == PHASE_BATTLE;
  bool get isMain2 => phase == PHASE_MAIN2;
  bool get isEnd => phase == PHASE_END;

  int get funcId => MSG_NEW_PHASE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint16(phase);
    return w.toBytes();
  }

  static MsgNewPhase decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgNewPhase(phase: r.readUint16());
  }

  @override
  String toString() => 'MsgNewPhase(phase:$phase)';
}
