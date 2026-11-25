/// 等待室聊天抽屉。
library;

import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../hud/hud_theme.dart';
import 'duel_style.dart';

class ChatSheet extends ConsumerStatefulWidget {
  const ChatSheet({super.key});

  @override
  ConsumerState<ChatSheet> createState() => ChatSheetState();
}

class ChatSheetState extends ConsumerState<ChatSheet> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(duelChatProvider).messages;
    return Container(
      height: 360,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: duelPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: duelLine),
      ),
      child: Column(
        children: [
          const Text('聊天', style: HudTheme.title),
          const Divider(color: duelLine),
          Expanded(
            child: ListView(
              reverse: true,
              children: [
                for (final msg in messages.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${msg.name}: ${msg.message}',
                      style: HudTheme.body,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  style: HudTheme.body,
                  decoration: const InputDecoration(
                    hintText: '发送消息…',
                    hintStyle: HudTheme.caption,
                    isDense: true,
                  ),
                  onSubmitted: _send,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, size: 18),
                color: duelCyan,
                onPressed: () => _send(_input.text),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    ref.read(duelChatProvider.notifier).sendChat(trimmed);
    _input.clear();
  }
}

// ────────────────────────────────────────────────────────────
// 05 对战-等候：顶部状态栏 / 选手卡 / 等待舞台 / 规则条
// ────────────────────────────────────────────────────────────

/// 打开房间聊天（把房间级 ProviderScope 桥接给弹层）。
void showRoomChat(BuildContext context) {
  final container = ProviderScope.containerOf(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => UncontrolledProviderScope(
      container: container,
      child: const ChatSheet(),
    ),
  );
}
