import 'dart:async';

import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';

import '../../../models/ChatMessage.dart';

/// 对局/房间聊天消息仓库。
///
/// 仅负责维护聊天消息列表，不处理网络连接与发送逻辑。
class DuelChatStore extends ChangeNotifier {
  List<ChatMessage> chatMessages = [];
  IDuelService? _duelService;
  StreamSubscription<YgoStocMsg>? _chatMsgSub;

  void markChanged() {
    notifyListeners();
  }

  void cancelChat() {
    _chatMsgSub?.cancel();
  }

  void reset() {

    chatMessages = [];
    notifyListeners();
  }

  void bind(IDuelService service) {
    _duelService = service;
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

  void sendChat(String text) {
    if (text.isEmpty) return;
    _duelService?.sendChat(text);
  }

  void bindChatServerMessages(
      void Function(YgoStocMsg event)? onData, {
        Function? onError,
        void Function()? onDone,
        bool? cancelOnError,
      }) {
    _chatMsgSub = _duelService?.onChatServerMessage.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  void dispose() {
    _chatMsgSub?.cancel();
    super.dispose();
  }
}
