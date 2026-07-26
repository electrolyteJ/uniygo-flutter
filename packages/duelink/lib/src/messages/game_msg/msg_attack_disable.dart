import 'dart:typed_data';
import '../../constants.dart';

/// Empty payload — an attack was disabled.
class MsgAttackDisable {
  const MsgAttackDisable();

  int get funcId => MSG_ATTACK_DISABLE;

  Uint8List encode() => Uint8List(0);

  static MsgAttackDisable decode(Uint8List data) => const MsgAttackDisable();

  @override
  String toString() => 'MsgAttackDisable()';
}
