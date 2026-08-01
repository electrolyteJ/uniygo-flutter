import 'dart:typed_data';

import '../../constants.dart';

/// MSG_DAMAGE_STEP_START (0x71) — 进入伤害步骤。
class MsgDamageStepStart {
  const MsgDamageStepStart();

  int get funcId => MSG_DAMAGE_STEP_START;

  Uint8List encode() => Uint8List(0);

  static MsgDamageStepStart decode(Uint8List data) =>
      const MsgDamageStepStart();

  @override
  String toString() => 'MsgDamageStepStart()';
}
