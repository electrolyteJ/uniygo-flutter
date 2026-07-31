import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// CTOS_CHAT (22)
///
/// 发送聊天消息。
///
/// 协议格式:
/// - message: 变长 UTF-16 LE 编码字符串，以 null 结束
///
/// 参考 neos-ts 的 ctosChat.ts 定义。
class CtosChat {
  final String message;
  const CtosChat({required this.message});
  int get protoId => CTOS_CHAT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUtf16Var(message);
    return w.toBytes();
  }

  static CtosChat decode(Uint8List data) {
    final r = BufferReader(data);
    return CtosChat(message: r.readUtf16Var());
  }

  @override
  String toString() => 'CtosChat($message)';
}
