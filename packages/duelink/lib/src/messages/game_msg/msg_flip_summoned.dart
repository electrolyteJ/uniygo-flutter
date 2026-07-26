import 'dart:typed_data';
import '../../constants.dart';

/// Empty payload — a monster has been flip summoned.
class MsgFlipSummoned {
  const MsgFlipSummoned();

  int get funcId => MSG_FLIP_SUMMONED;

  Uint8List encode() => Uint8List(0);

  static MsgFlipSummoned decode(Uint8List data) => const MsgFlipSummoned();

  @override
  String toString() => 'MsgFlipSummoned()';
}
