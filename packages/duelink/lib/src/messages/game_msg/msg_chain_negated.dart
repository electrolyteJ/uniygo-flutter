import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_CHAIN_NEGATED (0x4B) — 连锁被无效化通知。
class MsgChainNegated {
  final int chainIndex;

  const MsgChainNegated({required this.chainIndex});

  int get funcId => MSG_CHAIN_NEGATED;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(chainIndex);
    return w.toBytes();
  }

  static MsgChainNegated decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgChainNegated(chainIndex: r.readUint8());
  }

  @override
  String toString() => 'MsgChainNegated(chainIndex:$chainIndex)';
}
