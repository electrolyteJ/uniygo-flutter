import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_CHAIN_SOLVING (0x48) — 当前正在处理的连锁索引。
class MsgChainSolving {
  final int chainIndex;

  const MsgChainSolving({required this.chainIndex});

  int get funcId => MSG_CHAIN_SOLVING;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(chainIndex);
    return w.toBytes();
  }

  static MsgChainSolving decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgChainSolving(chainIndex: r.readUint8());
  }

  @override
  String toString() => 'MsgChainSolving(chainIndex:$chainIndex)';
}
