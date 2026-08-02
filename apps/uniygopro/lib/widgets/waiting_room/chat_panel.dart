import 'package:flutter/material.dart';
import '../../stores/duel_room_state.dart';

class ChatPanel extends StatelessWidget {
  final DuelRoomState state;
  final TextEditingController chatCtrl;
  final ScrollController chatScrollCtrl;
  final VoidCallback onSend;

  const ChatPanel({
    super.key,
    required this.state,
    required this.chatCtrl,
    required this.chatScrollCtrl,
    required this.onSend,
  });

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
                Text('聊天', style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: chatScrollCtrl,
              padding: const EdgeInsets.all(8),
              itemCount: state.chatMessages.length,
              itemBuilder: (ctx, i) {
                final msg = state.chatMessages[i];
                final color = _chatColor(msg.playerIndex);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 13),
                      children: [
                        TextSpan(
                          text: '${msg.name}: ',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: Colors.blueGrey.shade700,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.send, size: 20),
                  color: Colors.amber,
                  onPressed: onSend,
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
