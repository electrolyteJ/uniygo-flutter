import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Hand result notification.
/// Packed byte: result1 = byte & 0x3, result2 = (byte >> 2) & 0x3.
class MsgHandRes {
  final int result1;
  final int result2;

  const MsgHandRes({required this.result1, required this.result2});

  int get funcId => MSG_HAND_RES;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8((result1 & 0x3) | ((result2 & 0x3) << 2));
    return w.toBytes();
  }

  static MsgHandRes decode(Uint8List data) {
    final b = data[0];
    return MsgHandRes(result1: b & 0x3, result2: (b >> 2) & 0x3);
  }

  @override
  String toString() => 'MsgHandRes(result1:$result1 result2:$result2)';
}
