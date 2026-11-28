/// 等待室底栏操作（设计稿 05a：聊天 / 转为观战 / 开始决斗 / 准备）。
library;

import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart' hide CardInfo, ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_sheet.dart';
import '../../theme/duel_style.dart';

class RoomActions extends ConsumerWidget {
  const RoomActions({
    super.key,
    required this.room,
    required this.stage,
    this.isAiRoom = false,
  });

  final DuelRoomState room;
  final RoomStage stage;

  /// 人机房间：多一个「呼叫 AI」按钮，往聊天室发 /ai 让 AI 入座。
  final bool isAiRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = (MediaQuery.sizeOf(context).width / 844).clamp(0.85, 2.4);
    double s(double v) => v * k;

    final notifier = ref.read(duelRoomProvider.notifier);
    final inLobby = stage is RoomInLobby || stage is RoomJoined;
    final isDuelist = room.selfType.isDuelist;

    Widget squareIcon({
      required Key key,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(s(2)),
        child: Container(
          width: s(28),
          height: s(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s(2)),
            border: Border.all(color: duelLine),
          ),
          child: Icon(icon, size: s(14), color: duelSub),
        ),
      );
    }

    Widget gap() => SizedBox(width: s(8));

    return Container(
      decoration: const BoxDecoration(
        color: duelPanel,
        border: Border(top: BorderSide(color: duelLine)),
      ),
      padding: EdgeInsets.symmetric(horizontal: s(24), vertical: s(10)),
      child: Row(
        children: [
          squareIcon(
            key: const ValueKey('waiting-chat'),
            icon: Icons.chat_bubble_outline,
            onTap: () => showRoomChat(context),
          ),
          const Spacer(),
          if (inLobby && isAiRoom) ...[
            _BarButton(
              key: const ValueKey('waiting-call-ai'),
              label: '呼叫 AI',
              width: 96,
              k: k,
              onTap: () => ref.read(duelChatProvider.notifier).sendChat('/ai'),
            ),
            gap(),
          ],
          if (inLobby && isDuelist) ...[
            _BarButton(
              key: const ValueKey('waiting-become-observer'),
              label: '转为观战',
              width: 116,
              k: k,
              onTap: notifier.becomeObserver,
            ),
            gap(),
            _BarButton(
              key: const ValueKey('waiting-ready'),
              label: room.isSelfReady ? '取消准备' : '准备',
              width: 112,
              k: k,
              primary: true,
              onTap: () => notifier.toggleReady(),
            ),
          ] else if (inLobby) ...[
            _BarButton(
              key: const ValueKey('waiting-become-duelist'),
              label: '转为决斗者',
              width: 116,
              k: k,
              primary: true,
              onTap: notifier.becomeDuelist,
            ),
            gap(),
            // 保留这颗按钮是为了和决斗者底栏对齐，但观战者没有「准备」
            // 这个动作——灰按钮写「准备」会让人以为自己漏了什么，改成
            // 明确的状态说明。
            _BarButton(label: '无需准备', width: 112, k: k, enabled: false),
          ],
        ],
      ),
    );
  }
}

/// 底栏按钮：主按钮（青色实底）/ 描边按钮，尺寸按设计稿 116/112 × 32。
class _BarButton extends StatelessWidget {
  const _BarButton({
    super.key,
    required this.label,
    required this.width,
    required this.k,
    this.primary = false,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final double width;
  final double k;
  final bool primary;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    double s(double v) => v * k;
    final color = primary ? duelInk : duelTextColor;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(s(2)),
        child: Container(
          width: s(width),
          height: s(32),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? duelCyan : null,
            borderRadius: BorderRadius.circular(s(2)),
            border: Border.all(color: primary ? duelCyan : duelBtnLine),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: s(8.5), color: color),
          ),
        ),
      ),
    );
  }
}
