import 'dart:typed_data';
import '../../constants.dart';

/// Empty payload — two cards swapped positions.
class MsgSwap {
  const MsgSwap();

  int get funcId => MSG_SWAP;

  Uint8List encode() => Uint8List(0);

  static MsgSwap decode(Uint8List data) => const MsgSwap();

  @override
  String toString() => 'MsgSwap()';
}
