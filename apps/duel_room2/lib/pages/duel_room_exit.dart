import 'dart:developer' as console;

import 'package:biz/service_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'duel/duel_field_state.dart';

/// 退出决斗前的确认弹窗。
void backHomeDialog({
  required BuildContext context,
  required WidgetRef ref,
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
            backHome(context, ref, surrenderOnExit: true);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('退出'),
        ),
      ],
    ),
  );
}

void backHome(BuildContext context, WidgetRef ref,
    {bool surrenderOnExit = false}) {
  ref.read(ygoSoundServiceProvider).playBackNavigation();
  final duelService = ref.read(duelServiceProvider);
  if (surrenderOnExit) {
    duelService.surrender();
  }
  duelService.disconnect();
  // 结算数据先取出：导航后房间页 ProviderScope 销毁，provider 随之回收，
  // 各 controller/store 的流订阅由 ref.onDispose / dispose 自动清理，
  // 无需 duel_room1 那样的手动 reset 三件套。
  final duelResult = ref.read(duelFieldProvider).duelResult;
  console.log('backHome: duelResult=$duelResult');
  context.go('/');
  if (duelResult != null) {
    context.go('/duel-result', extra: duelResult);
  }
}

/// 结算页「返回首页」入口。
///
/// 结算页展示时房间页的 ProviderScope 已销毁，无法再用 ref 取服务；
/// 这里直接读应用级服务容器（service_providers.dart 中的同一批单例）：
/// 播放返回音效、兜底断开连接（房间页退出时已断，幂等），再回首页。
void backHomeAfterDuel(BuildContext context) {
  duelRoomServiceContainer.read(ygoSoundServiceProvider).playBackNavigation();
  duelRoomServiceContainer.read(duelServiceProvider).disconnect();
  context.go('/');
}
