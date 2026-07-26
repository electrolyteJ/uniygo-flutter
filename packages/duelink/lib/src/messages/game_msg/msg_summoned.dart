import 'dart:typed_data';
import '../../constants.dart';

/// Empty payload — a monster has been normal summoned.
class MsgSummoned {
  const MsgSummoned();

  int get funcId => MSG_SUMMONED;

  Uint8List encode() => Uint8List(0);

  static MsgSummoned decode(Uint8List data) => const MsgSummoned();

  @override
  String toString() => 'MsgSummoned()';
}
