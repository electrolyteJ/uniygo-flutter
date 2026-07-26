import 'dart:typed_data';
import '../../constants.dart';

/// Empty payload — a chain has ended.
class MsgChainEnd {
  const MsgChainEnd();

  int get funcId => MSG_CHAIN_END;

  Uint8List encode() => Uint8List(0);

  static MsgChainEnd decode(Uint8List data) => const MsgChainEnd();

  @override
  String toString() => 'MsgChainEnd()';
}
