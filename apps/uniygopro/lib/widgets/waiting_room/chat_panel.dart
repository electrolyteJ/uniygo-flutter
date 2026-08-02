import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniygopro/stores/waiting_room_store.dart';
import '../../stores/duel_chat_store.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  late final TextEditingController chatCtrl;
  late final ScrollController chatScrollCtrl;
  late final DuelChatStore duelChatStore;

  @override
  void initState() {
    super.initState();
    chatCtrl = TextEditingController();
    chatScrollCtrl = ScrollController();
    duelChatStore = context.read<DuelChatStore>();
    final waitingRoomStore = context.read<WaitingRoomStore>();
    duelChatStore.bindChatServerMessages((msg) {
      if (msg.chat != null) {
        final chat = msg.chat!;
        final player = waitingRoomStore.players
            .where((p) => p.pos == chat.player)
            .toList();
        final name = chat.player < 0
            ? 'System'
            : (player.isNotEmpty ? player.first.name : '[${chat.player}]');
        duelChatStore.addChat(chat.player, name, chat.message);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (chatScrollCtrl.hasClients) {
            chatScrollCtrl.animateTo(
              chatScrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
      duelChatStore.markChanged();
    });
  }

  @override
  void dispose() {
    chatCtrl.dispose();
    chatScrollCtrl.dispose();
    duelChatStore?.cancelChat();
    super.dispose();
  }

  Color _chatColor(int playerIndex) {
    switch (playerIndex) {
      case 0:
        return Colors.redAccent;
      case 1:
        return Colors.lightBlueAccent;
      case -1:
        return Colors.greenAccent;
      default:
        return Colors.blueGrey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duelChatStore = context.watch<DuelChatStore>();
    return Container(
      color: Colors.blueGrey.shade900,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.blueGrey.shade800,
            child: Row(
              children: [
                Icon(Icons.chat, size: 14, color: Colors.blueGrey.shade400),
                const SizedBox(width: 6),
                Text(
                  '聊天',
                  style: TextStyle(
                    color: Colors.blueGrey.shade300,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: chatScrollCtrl,
              padding: const EdgeInsets.all(8),
              itemCount: duelChatStore.chatMessages.length,
              itemBuilder: (ctx, i) {
                final msg = duelChatStore.chatMessages[i];
                final color = _chatColor(msg.playerIndex);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.blueGrey.shade200,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: '${msg.name}: ',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: msg.message),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.blueGrey.shade800,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: chatCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      hintStyle: TextStyle(color: Colors.blueGrey.shade500),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: Colors.blueGrey.shade700,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) {
                      duelChatStore.sendChat(chatCtrl.text);
                      chatCtrl.clear();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.send, size: 20),
                  color: Colors.amber,
                  onPressed: () {
                    duelChatStore.sendChat(chatCtrl.text);
                    chatCtrl.clear();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
