import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// STOC_CHAT (25)
///
/// 聊天消息。
///
/// 协议格式:
/// - player:  uint16 — 发送方玩家标识
/// - message: 变长 UTF-16 LE 字符串 — 消息内容
///
/// 参考 neos-ts 的 stocChat.ts 定义。
class StocChat {
  final int player;
  final String message;
  const StocChat({required this.player, required this.message});
  int get protoId => STOC_CHAT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint16(player);
    w.writeUtf16Var(message);
    return w.toBytes();
  }

  static StocChat decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint16();
    final message = r.readUtf16Var();
    return StocChat(player: player, message: message);
  }

  @override
  String toString() => 'StocChat(player:$player "$message")';
}
