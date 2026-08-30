import 'dart:ui';

import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:biz/duel/field/duel_field_derived.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/models/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 决斗日志 + 聊天合并抽屉（右侧滑入面板）。
///
/// 交互对齐 room3 的 _LogDrawer：单列表分段——上半决斗日志、中间
/// 「—— 聊天 ——」分隔、下半聊天消息，底部聊天输入框；视觉保持 room1
/// 赛博风（Orbitron 金标题 + 青色描边 + 背景模糊）。
///
/// 本组件只是面板本体：非模态常驻在 DuelRoomPage 的 Stack 右侧
///（AnimatedSlide 开合），无遮罩、面板外点击穿透、点外部不关闭；
/// onClose 收起面板（抽屉内 ✕ 与右下角开关按钮同一条路径）。
class DuelLogDrawer extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const DuelLogDrawer({super.key, required this.onClose});

  /// 面板宽度（沿用旧聊天停靠宽）。
  static const double panelWidth = 320.0;

  @override
  ConsumerState<DuelLogDrawer> createState() => _DuelLogDrawerState();
}

class _DuelLogDrawerState extends ConsumerState<DuelLogDrawer> {
  static const goldGlow = Color(0xFFFFD700);
  static const cyanGlow = Color(0xFF00F0FF);
  static const panelDark = Color(0xE6080E18); // rgba(8, 14, 24, 0.9)
  static const logGrey = Color(0xFF8B9BB4);

  late final TextEditingController _chatCtrl;

  @override
  void initState() {
    super.initState();
    _chatCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
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

  void _send() {
    ref.read(duelChatProvider.notifier).sendChat(_chatCtrl.text);
    _chatCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(duelFieldProvider.select(selectLogSlice));
    final messages = ref.watch(duelChatProvider).messages;

    // 抽屉经 showGeneralDialog 挂在根 Navigator 的 Overlay 上，
    // 路由内容没有 Material 祖先：TextField/IconButton 等 Material
    // 组件必须有，这里用透明 Material 补上（不改变视觉）。
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: DuelLogDrawer.panelWidth,
            decoration: const BoxDecoration(
              color: panelDark,
              border: Border(left: BorderSide(color: Color(0x4D00F0FF))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
                    child: Row(
                      children: [
                        const Text(
                          '❖ DUEL LOG',
                          style: TextStyle(
                            color: goldGlow,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: logGrey,
                          ),
                          tooltip: '关闭',
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0x3300F0FF), height: 1),
                  // reverse:true + 逆序数据源：新日志/新聊天自动钉在列表底部，
                  // 无需滚动控制器。日志与聊天两条流都向中间分隔线汇聚。
                  Expanded(
                    child: ListView(
                      reverse: true,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      children: [
                        for (final msg in messages.reversed)
                          _buildChatLine(msg),
                        if (messages.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Center(
                              child: Text(
                                '—— 聊天 ——',
                                style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        if (logs.isEmpty)
                          const Text(
                            '等待决斗开始...',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 13,
                            ),
                          )
                        else
                          for (final log in logs.reversed) _buildLogLine(log),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x3300F0FF))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatCtrl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: '发送聊天…',
                              hintStyle: const TextStyle(
                                color: Color(0xFF5A6B82),
                              ),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogLine(String log) {
    final isHighlight = log.contains('发动') || log.contains('攻击力');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        log,
        style: TextStyle(
          color: isHighlight ? cyanGlow : logGrey,
          fontSize: 14,
          height: 1.5,
          fontFamily: 'Noto Sans SC',
        ),
      ),
    );
  }

  Widget _buildChatLine(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFFCFD8E3), fontSize: 13),
          children: [
            TextSpan(
              text: '${msg.name}: ',
              style: TextStyle(
                color: _chatColor(msg.playerIndex),
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(text: msg.message),
          ],
        ),
      ),
    );
  }
}
