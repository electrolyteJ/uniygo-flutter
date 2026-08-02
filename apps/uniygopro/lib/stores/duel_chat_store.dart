import 'package:flutter/foundation.dart';

import '../models/ChatMessage.dart';

/// 对局/房间聊天消息仓库。
///
/// 仅负责维护聊天消息列表，不处理网络连接与发送逻辑。
class DuelChatStore extends ChangeNotifier {
  List<ChatMessage> chatMessages = [];

  void markChanged() {
    notifyListeners();
  }

  void reset() {
    chatMessages = [];
    notifyListeners();
  }

  void addChat(int playerIndex, String name, String message) {
    chatMessages.add(
      ChatMessage(
        playerIndex: playerIndex,
        name: name,
        message: message,
        time: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
