/// 等待室底栏操作（观战 / 转为观战 / 开始决斗 / 准备 / 复制房间号 / 聊天）。
library;

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart' hide CardInfo, ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_sheet.dart';
import 'duel_style.dart';

class RoomActions extends ConsumerWidget {
  const RoomActions({super.key, required this.room, required this.stage});

  final DuelRoomState room;
  final RoomStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(duelRoomProvider.notifier);
    final inLobby = stage is RoomInLobby || stage is RoomJoined;
    final isDuelist = room.selfType.isDuelist;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: duelPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: duelLine),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 聊天
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: duelSub),
                onPressed: () => showRoomChat(context),
              ),
              const Spacer(),
              if (room.roomId != null) ...[
                OutlinedButton.icon(
                  key: const ValueKey('waiting-copy-room'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: duelSub,
                    side: const BorderSide(color: duelLine),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: room.roomId!));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('房间号已复制')));
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('复制房间号'),
                ),
                const SizedBox(width: 8),
              ],
              if (inLobby && isDuelist) ...[
                if (MediaQuery.sizeOf(context).height > 520) ...[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: duelSub,
                      side: const BorderSide(color: duelLine),
                    ),
                    onPressed: null,
                    child: Text('观战 ${room.observerCount} / 2'),
                  ),
                  const SizedBox(width: 12),
                ],
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: duelTextColor,
                    side: const BorderSide(color: duelLine),
                  ),
                  onPressed: notifier.becomeObserver,
                  child: const Text('转为观战'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: duelCyan,
                    foregroundColor: const Color(0xFF041017),
                  ),
                  onPressed: () => notifier.toggleReady(),
                  child: Text(room.isSelfReady ? '取消准备' : '准备'),
                ),
                if (room.isHost) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: duelTextColor,
                      side: const BorderSide(color: duelCyan),
                    ),
                    onPressed: room.isAllReady ? notifier.startDuel : null,
                    child: const Text('开始决斗'),
                  ),
                ],
              ] else if (inLobby) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: duelTextColor,
                    side: const BorderSide(color: duelLine),
                  ),
                  onPressed: notifier.becomeDuelist,
                  child: const Text('转为决斗者'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
