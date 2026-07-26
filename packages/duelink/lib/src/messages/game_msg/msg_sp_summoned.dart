import 'dart:typed_data';
import '../../constants.dart';

/// Empty payload — a monster has been special summoned.
class MsgSpSummoned {
  const MsgSpSummoned();

  int get funcId => MSG_SP_SUMMONED;

  Uint8List encode() => Uint8List(0);

  static MsgSpSummoned decode(Uint8List data) => const MsgSpSummoned();

  @override
  String toString() => 'MsgSpSummoned()';
}
