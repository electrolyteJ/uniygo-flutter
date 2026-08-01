// ── ChatMessage (from room_store.dart) ──

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
