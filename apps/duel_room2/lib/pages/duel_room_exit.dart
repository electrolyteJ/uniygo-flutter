import 'dart:async';
import 'dart:developer' as console;

import 'package:biz/service_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'duel/duel_field_state.dart';
import 'duel_room_state.dart';

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
            unawaited(backHome(context, ref, surrenderOnExit: true));
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('退出'),
        ),
      ],
    ),
  );
}

/// 投降确认弹窗：只认输、不断开连接，留在房间看结算。
///
/// 与 [backHomeDialog] 的区别：backHomeDialog 的「退出」会认输并断开连接
/// 离开房间；此处只发 CTOS_SURRENDER，服务端随后下发 MSG_WIN 结算，
/// 玩家仍停留在房间/结算流程中。
void surrenderDialog({required BuildContext context, required WidgetRef ref}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('投降'),
      content: const Text('是否确认向对手投降？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            ref.read(duelServiceProvider).surrender();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('投降'),
        ),
      ],
    ),
  );
}

/// 离开房间回首页。
///
/// 幂等：经 [DuelRoomNotifier.markLeaving] 去重——主动退出触发的
/// disconnect 会让服务器下发 RoomNotJoined，页面 stage 监听会再次调用
/// 离房流程，第二次调用直接返回，避免重复音效/重复导航。
///
/// ref 只在函数开头的同步段使用，绝不跨 await 触碰：确认弹窗持有的是
/// 弹窗来源页面（房间页或对局页）的 ref，对局页会随 RoomDuelEnded /
/// RoomNotJoined 卸载。若在等待/断开期间页面被销毁，直接返回——
/// 断开动作本身不依赖 widget，照常执行以触发 RoomNotJoined，
/// 导航由房间页 stage 监听的 [leaveRoomAfterNotJoined] 兜底完成。
Future<void> backHome(
  BuildContext context,
  WidgetRef ref, {
  bool surrenderOnExit = false,
}) async {
  // 弹窗按钮是异步回调：点击时来源页面可能已销毁
  // （对局结束卸载对局页、或离房导航已销毁房间页），此时 ref 不可用。
  if (!context.mounted) return;
  if (!ref.read(duelRoomProvider.notifier).markLeaving()) {
    return;
  }
  ref.read(ygoSoundServiceProvider).playBackNavigation();
  final duelService = ref.read(duelServiceProvider);
  if (surrenderOnExit) {
    duelService.surrender();
    // surrender() 只是把 CTOS_SURRENDER 写进发送缓冲：断开前稍等一拍，
    // 确保服务器先收到认输再收到断连，结算按认输而不是掉线处理。
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
  // 断开不依赖 widget：即使等待/断开期间页面被销毁也照常执行，
  // 让服务器收到断连并下发 RoomNotJoined，触发兜底导航。
  await duelService.disconnect();
  // 结算数据先取出：导航后房间页 ProviderScope 销毁，provider 随之回收，
  // 各 controller/store 的流订阅由 ref.onDispose / dispose 自动清理，
  // 无需 duel_room1 那样的手动 reset 三件套。
  // 若本函数持有的页面已销毁（对局页随卸载失效），ref 不可再用，
  // 这里直接返回，由 leaveRoomAfterNotJoined 用房间页自身的 ref 完成导航。
  if (!context.mounted) return;
  final duelResult = ref.read(duelFieldProvider).duelResult;
  console.log('backHome: duelResult=$duelResult');
  // 单次导航直达目标：有结算去结算页，否则回首页
  // （旧实现先 go('/') 再 go('/duel-result')，多一次无谓跳转）。
  if (duelResult != null) {
    context.go('/duel-result', extra: duelResult);
  } else {
    context.go('/');
  }
}

/// RoomNotJoined 到达时的统一离房处理（房间页 stage 监听调用）。
///
/// 用房间页自身的 context/ref——导航发生前房间页必然存活，因此这里的
/// ref 读取始终安全，保证「离开房间」一定有导航出口：
/// - 主动退出（[backHome]）已标记 leaving：退出动作已在跑（可能因 HUD
///   弹窗所属对局页卸载而中断），这里只补做导航；
/// - 服务器踢人/连接断开（未走 backHome）：补做音效与幂等断开再导航，
///   与旧实现行为一致。
///
/// 双重导航由 `context.mounted` 守卫消除：先完成导航的一方销毁房间页，
/// 后到的一方检查到未挂载直接返回，最终恰好导航一次。
Future<void> leaveRoomAfterNotJoined(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!context.mounted) return;
  final leaving = ref.read(duelRoomProvider.notifier).isLeaving;
  if (!leaving) {
    ref.read(duelRoomProvider.notifier).markLeaving();
    ref.read(ygoSoundServiceProvider).playBackNavigation();
    await ref.read(duelServiceProvider).disconnect();
    if (!context.mounted) return;
  }
  final duelResult = ref.read(duelFieldProvider).duelResult;
  if (duelResult != null) {
    context.go('/duel-result', extra: duelResult);
  } else {
    context.go('/');
  }
}

/// 结算页「返回首页」入口。
///
/// 结算页展示时房间页的 ProviderScope 已销毁，无法再用 ref 取服务；
/// 这里直接读应用级服务容器（service_providers.dart 中的同一批单例）：
/// 播放返回音效、兜底断开连接（房间页退出时已断，幂等），再回首页。
void backHomeAfterDuel(BuildContext context) {
  duelRoomServiceContainer.read(ygoSoundServiceProvider).playBackNavigation();
  unawaited(duelRoomServiceContainer.read(duelServiceProvider).disconnect());
  context.go('/');
}
