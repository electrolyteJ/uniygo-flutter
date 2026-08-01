import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_MATCH_KILL (0xAA) — Match Kill 标记。
class MsgMatchKill {
  final int value;

  const MsgMatchKill({required this.value});

  int get funcId => MSG_MATCH_KILL;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeInt32(value);
    return w.toBytes();
  }

  static MsgMatchKill decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgMatchKill(value: r.readInt32());
  }

  @override
  String toString() => 'MsgMatchKill(value:$value)';
}
