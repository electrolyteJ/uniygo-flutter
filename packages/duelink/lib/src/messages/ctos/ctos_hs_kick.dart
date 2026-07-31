import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// CTOS_HS_KICK (36)
///
/// 踢出指定位置的玩家（仅房主可用）。
///
/// 协议格式:
/// - pos: unsigned char — 要踢出的玩家位置（0-3 之间）
///
/// 参考 neos-ts 中对应的 HS 消息定义。
class CtosHsKick {
  final int pos;
  const CtosHsKick({required this.pos});
  int get protoId => CTOS_HS_KICK;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(pos & 0x3);
    return w.toBytes();
  }

  static CtosHsKick decode(Uint8List data) {
    return CtosHsKick(pos: data[0] & 0x3);
  }

  @override
  String toString() => 'CtosHsKick(pos:$pos)';
}
