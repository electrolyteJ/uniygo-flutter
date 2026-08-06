import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../pages/duel_room/duel/duel_field_store.dart';
import '../../pages/duel_room/waiting/duel_chat_store.dart';
import '../../pages/duel_room/duel_room_store.dart';
import '../../pages/create_room/match_store.dart';

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
  final duelRoomState = context.read<DuelRoomStore>();
  final duelStore = context.read<DuelFieldStore>();
  final duelChatStore = context.read<DuelChatStore>();
  final matchRoomStore = context.read<MatchStore>();
  duelRoomState.reset();
  duelStore.reset();
  duelChatStore.reset();
  matchRoomStore.reset();
  context.go('/');
}
