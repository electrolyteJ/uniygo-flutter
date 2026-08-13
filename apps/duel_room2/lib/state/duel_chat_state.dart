import 'dart:async';

import 'package:duelink/duelink.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_message.dart';
import '../../providers/service_providers.dart';
import 'duel_room_state.dart';

/// 聊天状态：消息列表（不可变替换）。
@immutable
class DuelChatState {
  const DuelChatState({this.messages = const []});

  final List<ChatMessage> messages;
}

final duelChatProvider =
    NotifierProvider<DuelChatNotifier, DuelChatState>(DuelChatNotifier.new);

/// 对局/房间聊天控制器（Riverpod 版 DuelChatStore）。
///
/// 发送者名字解析从页面闭包改为控制器内 `ref.read(duelRoomProvider)`，
/// 不再依赖页面把 players 传进来。
// @riverpod
class DuelChatNotifier extends Notifier<DuelChatState> {
  StreamSubscription<YgoStocMsg>? _chatMsgSub;

  IDuelService get _duelService => ref.read(duelServiceProvider);

  @override
  DuelChatState build() {
    ref.onDispose(() => _chatMsgSub?.cancel());
    return const DuelChatState();
  }

  /// 开始订阅服务器聊天消息。必须在 connect 完成后由页面调用。
  void start() {
    _chatMsgSub = _duelService.onChatServerMessage.listen((msg) {
      final chat = msg.chat;
      if (chat == null) return;
      // 发送者名字按房间玩家列表解析。
      final players = ref.read(duelRoomProvider).players;
      final player = players.where((p) => p.pos == chat.player).toList();
      final name = chat.player < 0
          ? 'System'
          : (player.isNotEmpty ? player.first.name : '[${chat.player}]');
      _addChat(chat.player, name, chat.message);
    });
  }

  void _addChat(int playerIndex, String name, String message) {
    ref.read(ygoSoundServiceProvider).playChatMessage();
    state = DuelChatState(
      messages: [
        ...state.messages,
        ChatMessage(
          playerIndex: playerIndex,
          name: name,
          message: message,
          time: DateTime.now(),
        ),
      ],
    );
  }

  void sendChat(String text) {
    if (text.isEmpty) return;
    _duelService.sendChat(text);
  }
}
