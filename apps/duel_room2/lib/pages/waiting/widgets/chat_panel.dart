import 'package:flutter/material.dart';

import 'package:flutter/widget_previews.dart';

import '../models/chat_message.dart';

/// 聊天面板：纯 UI，消息列表与发送动作均由业务侧注入。
class ChatPanel extends StatefulWidget {
  final List<ChatMessage> messages;
  final ValueChanged<String> onSend;

  const ChatPanel({super.key, required this.messages, required this.onSend});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  late final TextEditingController chatCtrl;
  late final ScrollController chatScrollCtrl;

  @override
  void initState() {
    super.initState();
    chatCtrl = TextEditingController();
    chatScrollCtrl = ScrollController();
  }

  @override
  void didUpdateWidget(covariant ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
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
  }

  @override
  void dispose() {
    chatCtrl.dispose();
    chatScrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    widget.onSend(chatCtrl.text);
    chatCtrl.clear();
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
    final messages = widget.messages;
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
              itemCount: messages.length,
              itemBuilder: (ctx, i) {
                final msg = messages[i];
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
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.send, size: 20),
                  color: Colors.amber,
                  onPressed: _send,
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
@Preview(name: 'ChatPanel', size: Size(360, 400), brightness: Brightness.dark)
Widget _previewChatPanel() => ChatPanel(messages: const [], onSend: (_) {});

