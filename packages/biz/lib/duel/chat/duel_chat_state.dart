import 'dart:async';

import 'package:biz/service_providers.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../room/duel_room_state.dart';
import '../models/chat_message.dart';

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
  ///
  /// 幂等：重复调用会先取消上一次的订阅，避免同一消息被重复处理。
  void start() {
    _chatMsgSub?.cancel();
    _chatMsgSub = _duelService.onChatServerMessage.listen((msg) {
      final chat = msg.chat;
      if (chat == null) return;
      // 发送者名字按房间玩家列表解析。
      final players = ref.read(duelRoomProvider).players;
      final rawPlayer = chat.player;
      // STOC_CHAT.player 为 uint16（永不为负）：系统广播固定为 0xFFFF，
      // 普通消息为座位号。旧实现按 `player < 0` 判系统、把 65535 显示成
      // `[65535]` 是错的；这里统一映射成「系统」。
      final matched = players.where((p) => p.pos == rawPlayer).toList();
      final isSystem =
          rawPlayer == kSystemChatPlayer || rawPlayer >= players.length;
      final name = isSystem
          ? '系统'
          : (matched.isNotEmpty ? matched.first.name : '[$rawPlayer]');
      _addChat(isSystem ? kSystemChatPlayer : rawPlayer, name, chat.message);
    });
  }

  /// 聊天消息上限：超过则丢弃最旧的消息，避免长对局内存无限增长。
  static const int _maxMessages = 500;

  void _addChat(int playerIndex, String name, String message) {
    ref.read(ygoSoundServiceProvider).playChatMessage();
    final next = [
      ...state.messages,
      ChatMessage(
        playerIndex: playerIndex,
        name: name,
        message: message,
        time: DateTime.now(),
      ),
    ];
    state = DuelChatState(
      messages: next.length > _maxMessages
          ? next.sublist(next.length - _maxMessages)
          : next,
    );
  }

  void sendChat(String text) {
    if (text.isEmpty) return;
    _duelService.sendChat(text);
  }
}
