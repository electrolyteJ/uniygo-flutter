import 'dart:developer' as console;

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../service_singleton.dart';
import '../create_room/match_store.dart';
import 'duel/bloc/duel_bloc.dart';
import 'duel/bloc/duel_event.dart';
import 'duel_room_store.dart';
import 'waiting/duel_chat_store.dart';

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
  final duelBloc = context.read<DuelBloc>();
  final duelChatStore = context.read<DuelChatStore>();
  final matchRoomStore = context.read<MatchStore>();
  final duelResult = duelBloc.state.duelResult;
  final isDuelEnded = duelRoomState.stage is RoomDuelEnded;
  context.go('/');
  console.log('backHome: isDuelEnded=$isDuelEnded, duelResult=$duelResult');
  if (duelResult != null) {
    context.go('/duel-result', extra: duelResult);
  }
  duelRoomState.reset();
  duelBloc.add(const DuelResetRequested());
  duelChatStore.cancelChat();
  duelChatStore.reset();
  matchRoomStore.reset();
}
