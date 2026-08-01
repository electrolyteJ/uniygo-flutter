import 'dart:typed_data';

import '../../constants.dart';

/// MSG_DAMAGE_STEP_END (0x72) — 离开伤害步骤。
class MsgDamageStepEnd {
  const MsgDamageStepEnd();

  int get funcId => MSG_DAMAGE_STEP_END;

  Uint8List encode() => Uint8List(0);

  static MsgDamageStepEnd decode(Uint8List data) => const MsgDamageStepEnd();

  @override
  String toString() => 'MsgDamageStepEnd()';
}
