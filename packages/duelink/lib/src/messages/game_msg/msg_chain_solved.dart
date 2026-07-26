import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// A chain link has been solved.
class MsgChainSolved {
  final int solvedIndex;

  const MsgChainSolved({required this.solvedIndex});

  int get funcId => MSG_CHAIN_SOLVED;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(solvedIndex);
    return w.toBytes();
  }

  static MsgChainSolved decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgChainSolved(solvedIndex: r.readUint8());
  }

  @override
  String toString() => 'MsgChainSolved(solvedIndex:$solvedIndex)';
}
