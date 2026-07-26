import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Field disabled notification (flag: int32).
class MsgFieldDisabled {
  final int flag;

  const MsgFieldDisabled({required this.flag});

  int get funcId => MSG_FIELD_DISABLED;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeInt32(flag);
    return w.toBytes();
  }

  static MsgFieldDisabled decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgFieldDisabled(flag: r.readInt32());
  }

  @override
  String toString() => 'MsgFieldDisabled(flag:$flag)';
}
