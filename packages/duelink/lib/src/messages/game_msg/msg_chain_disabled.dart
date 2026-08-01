import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_CHAIN_DISABLED (0x4C) — 连锁效果被无效通知。
class MsgChainDisabled {
  final int chainIndex;

  const MsgChainDisabled({required this.chainIndex});

  int get funcId => MSG_CHAIN_DISABLED;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(chainIndex);
    return w.toBytes();
  }

  static MsgChainDisabled decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgChainDisabled(chainIndex: r.readUint8());
  }

  @override
  String toString() => 'MsgChainDisabled(chainIndex:$chainIndex)';
}
