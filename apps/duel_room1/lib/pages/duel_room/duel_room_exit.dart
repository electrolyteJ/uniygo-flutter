import 'dart:developer' as console;

import 'package:biz/service_singleton.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'duel_field_store.dart';
import 'duel_room_store.dart';
import 'package:duel_room1/pages/duel_room/duel_chat_store.dart';

/// 退出决斗前的确认弹窗。
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
            backHome(context, surrenderOnExit: true);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('退出'),
        ),
      ],
    ),
  );
}

void backHome(BuildContext context, {bool surrenderOnExit = false}) {
  ServiceSingleton.instance.ygoSoundService.playBackNavigation();
  final duelService = ServiceSingleton.instance.duelService;
  if (surrenderOnExit) {
    duelService.surrender();
  }
  duelService.disconnect();
  final duelRoomState = context.read<DuelRoomStore>();
  final duelFieldStore = context.read<DuelFieldStore>();
  final duelChatStore = context.read<DuelChatStore>();
  final duelResult = duelFieldStore.duelResult;
  final isDuelEnded = duelRoomState.stage is RoomDuelEnded;
  context.go('/');
  console.log('backHome: isDuelEnded=$isDuelEnded, duelResult=$duelResult');
  if (duelResult != null) {
    context.go('/duel-result', extra: duelResult);
  }
  duelRoomState.reset();
  duelFieldStore.reset();
  duelChatStore.cancelChat();
  duelChatStore.reset();
}
