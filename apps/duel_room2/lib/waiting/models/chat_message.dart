// ── ChatMessage (from room_store.dart) ──

/// 系统聊天消息的发送者标识。
///
/// STOC_CHAT 的 `player` 字段是 uint16（永不为负）：普通消息为座位号，
/// 服务器/系统广播固定为 0xFFFF。旧代码按 `player < 0`/`case -1` 判断系统
/// 消息是错的，统一用该常量识别。
const int kSystemChatPlayer = 0xFFFF;

class ChatMessage {
  final int playerIndex;
  final String name;
  final String message;
  final DateTime time;

  const ChatMessage({
    required this.playerIndex,
    required this.name,
    required this.message,
    required this.time,
  });
}
