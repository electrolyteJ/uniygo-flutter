import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../stores/duel_board_store.dart';
import '../../stores/duel_chat_store.dart';
import '../../stores/duel_room_state.dart';
import '../../stores/duel_selection_store.dart';
import '../../stores/duel_ui_store.dart';
import '../../stores/match_store.dart';
import '../../stores/waiting_room_store.dart';

Widget buildBackButton(BuildContext context) {
  return Material(
    color: Colors.black54,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => {
        backHomeDialog(context: context, title: '退出决斗', content: '是否确认退出当前决斗？'),
      },
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
      ),
    ),
  );
}

void backHomeDialog({
  required BuildContext context,
  required String title,
  required String content,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            backHome(context);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('退出'),
        ),
      ],
    ),
  );
}

void backHome(BuildContext context) {
  final duelRoomState = context.read<DuelRoomState>();
  final waitingRoomStore = context.read<WaitingRoomStore>();
  final duelBoardStore = context.read<DuelBoardStore>();
  final selectionStore = context.read<DuelSelectionStore>();
  final duelChatStore = context.read<DuelChatStore>();
  final uiStore = context.read<DuelUiStore>();
  final matchRoomStore = context.read<MatchStore>();
  duelRoomState.reset();
  waitingRoomStore.reset();
  duelBoardStore.reset();
  selectionStore.reset();
  duelChatStore.reset();
  uiStore.reset();
  matchRoomStore.reset();
  context.go('/');
}
