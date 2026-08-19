import 'dart:ui';

import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:flutter/material.dart';

import 'package:biz/duel/models/chat_message.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 聊天浮窗停靠几何：与场地页 DuelLogDrawer（debuglog UI）同位
/// （top:126, right:16）。由 DuelRoomPage 负责停靠定位；
/// 等待室弹窗据此预留右侧空间避免重叠。
const double kChatDockTop = 126.0;
const double kChatDockRight = 16.0;
const double kChatDockBottom = 16.0;
const double kChatDockWidth = 320.0;

/// 聊天面板：房间页右侧的独立浮窗，直连房间 scope 的 duelChatProvider
///（消息列表/发送）。需在房间 ProviderScope 内使用。
///
/// 视觉与场地页 DuelLogDrawer（debuglog UI）一致：半透明深色底 +
/// 青色描边 + 圆角 + 背景模糊，透出背后的决斗场地。
class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel({super.key});

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  late final TextEditingController chatCtrl;
  late final ScrollController chatScrollCtrl;

  @override
  void initState() {
    super.initState();
    chatCtrl = TextEditingController();
    chatScrollCtrl = ScrollController();
  }

  /// 新消息到达后自动滚到底部（原 didUpdateWidget 参数对比，
  /// 迁移为监听 provider 的消息数变化）。
  void _scrollToBottom() {
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

  @override
  void dispose() {
    chatCtrl.dispose();
    chatScrollCtrl.dispose();
    super.dispose();
  }

  Color _chatColor(int playerIndex) {
    switch (playerIndex) {
      case 0:
        return Colors.redAccent;
      case 1:
        return Colors.lightBlueAccent;
      case kSystemChatPlayer:
        return Colors.greenAccent;
      default:
        return Colors.blueGrey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(duelChatProvider.select((s) => s.messages.length), (prev, next) {
      if (next != prev) _scrollToBottom();
    });
    final chatCtl = ref.read(duelChatProvider.notifier);
    final chat = ref.watch(duelChatProvider);
    final messages = chat.messages;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xE6080E18),
            border: Border.all(color: const Color(0x4D00F0FF)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x3300F0FF))),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.chat, size: 14, color: Color(0xFF00F0FF)),
                    SizedBox(width: 6),
                    Text(
                      '聊天',
                      style: TextStyle(
                        color: Color(0xFF00F0FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
                          style: const TextStyle(
                            color: Color(0xFFCFD8E3),
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
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x3300F0FF))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: chatCtrl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: '输入消息...',
                          hintStyle: const TextStyle(color: Color(0xFF5A6B82)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) {
                          chatCtl.sendChat(chatCtrl.text);
                          chatCtrl.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.send, size: 20),
                      color: Colors.amber,
                      onPressed: () {
                        chatCtl.sendChat(chatCtrl.text);
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
        ),
      ),
    );
  }
}

@Preview(name: 'ChatPanel', size: Size(360, 400), brightness: Brightness.dark)
Widget _previewChatPanel() => const ChatPanel();
