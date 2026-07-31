import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_HAND_RES (0x85) — 猜拳结果通知
///
/// 通知客户端双方猜拳（石头剪刀布）的结果。
/// 两个结果打包在一个字节中。
///
/// 有线格式 (1 字节):
/// | 偏移 | 大小 | 类型  | 说明                                    |
/// |------|------|-------|-----------------------------------------|
/// | 0x00 | 1    | uint8 | 打包字节: result1 = byte & 0x3, result2 = (byte >> 2) & 0x3 |
///
/// 参考 neos-ts 的 handRes.ts 定义。
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
