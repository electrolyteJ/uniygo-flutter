import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_CHAINED (0x47) — 连锁入链完成通知。
class MsgChained {
  final int chainIndex;

  const MsgChained({required this.chainIndex});

  int get funcId => MSG_CHAINED;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(chainIndex);
    return w.toBytes();
  }

  static MsgChained decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgChained(chainIndex: r.readUint8());
  }

  @override
  String toString() => 'MsgChained(chainIndex:$chainIndex)';
}
