import 'dart:developer' as console;

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../pages/duel_room/duel/duel_field_store.dart';
import '../../pages/duel_room/waiting/duel_chat_store.dart';
import '../../pages/duel_room/duel_room_store.dart';
import '../../pages/create_room/match_store.dart';
import '../../service_singleton.dart';

Widget buildBackButton(BuildContext context) {
  return Material(
    color: Colors.black54,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => {
        ServiceSingleton.instance.uiSoundService.playDialogOpen(),
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
  ServiceSingleton.instance.uiSoundService.playBackNavigation();
  final duelService = ServiceSingleton.instance.duelService;
  if (surrenderOnExit) {
    duelService.surrender();
  }
  duelService.disconnect();
  final duelRoomState = context.read<DuelRoomStore>();
  final duelFieldStore = context.read<DuelFieldStore>();
  final duelChatStore = context.read<DuelChatStore>();
  final matchRoomStore = context.read<MatchStore>();
  final duelResult = duelFieldStore.duelResult;
  final isDuelEnded = duelRoomState.stage is RoomDuelEnded;
  context.go('/');
  console.log('backHome: isDuelEnded=$isDuelEnded, duelResult=$duelResult');
  if (duelResult != null) {
    context.go('/duel-result', extra: duelResult);
  }
  duelRoomState.reset();
  duelFieldStore.reset();
  duelChatStore.reset();
  matchRoomStore.reset();
}
