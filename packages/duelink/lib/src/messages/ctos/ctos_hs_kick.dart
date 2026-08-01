import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// CTOS_HS_KICK (36)
///
/// 踢出指定位置的玩家（仅房主可用）。
///
/// 该消息存在于原始 ygopro 二进制协议，但不在当前 `ocgcore.proto` 的
/// CTOS protobuf 抽象中，因此 `duelink` 这里保留原始协议支持。
///
/// 协议格式:
/// - pos: unsigned char — 要踢出的玩家位置（0-3 之间）
///
/// 参考 neos-ts 中对应的 HS 消息定义。
class CtosHsKick {
  final int pos;
  const CtosHsKick({required this.pos});
  int get protoId => CTOS_HS_KICK;

  /// 语义化别名，便于和其他消息上的 `*Value` helper 保持一致。
  int get positionValue => pos;

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
