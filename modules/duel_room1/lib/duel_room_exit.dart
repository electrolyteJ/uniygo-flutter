import 'dart:async';

import 'package:biz/service_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:biz/duel/room/duel_room_state.dart';

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
            // 先关弹窗再离房：弹窗推在 root navigator 上，backHome 里的
            // context.go 只改写 router 内部栈，不关弹窗它会悬浮在首页/结算页上。
            Navigator.of(ctx).pop();
            unawaited(backHome(context, ref, surrenderOnExit: true));
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('退出'),
        ),
      ],
    ),
  );
}

/// 投降确认弹窗（阶段轨道顶端「投降」按钮）。
///
/// 与 [backHomeDialog] 的区别：只发送 CTOS_SURRENDER，不做离房导航——
/// 服务器回 MSG_WIN 后由结算弹窗接管展示，「返回首页」走结算弹窗的出口。
void showSurrenderConfirmDialog({
  required BuildContext context,
  required WidgetRef ref,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('确认投降？'),
      content: const Text('投降将立即判负并结束本局决斗。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            // 只认输不退出：surrender() 把 CTOS_SURRENDER 写入发送缓冲，
            // 服务器判负后下发 MSG_WIN，结算弹窗按既有逻辑挂载。
            ref.read(duelServiceProvider).surrender();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('投降'),
        ),
      ],
    ),
  );
}

/// 意外断连（服务器关闭/网络重置/被踢）时的页面内提醒弹窗。
///
/// 与 [backHomeDialog] 的区别：这不是用户主动退出，不弹确认框——
/// 告知断连事实后，唯一出口「返回首页」走 [leaveRoomAfterNotJoined]
/// （幂等：断开已完成时仅补导航）。
/// 返回对话框关闭的 Future：调用方据此跟踪弹窗是否仍在展示
/// （断连弹窗弹出期间若 MSG_WIN 才从节奏泵消费到，需要关掉弹窗
/// 让结算页展示）。
Future<void> showDisconnectDialog({
  required BuildContext context,
  required WidgetRef ref,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('连接已断开'),
      content: const Text('与服务器的连接已中断，无法继续对局。'),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            unawaited(leaveRoomAfterNotJoined(context, ref));
          },
          child: const Text('返回首页'),
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
  // 各 notifier 的流订阅由 ref.onDispose 自动清理，无需手动 reset 三件套。
  // 若本函数持有的页面已销毁（对局页随卸载失效），ref 不可再用，
  // 这里直接返回，由 leaveRoomAfterNotJoined 用房间页自身的 ref 完成导航。
  if (!context.mounted) return;
  // 结算由决斗页的全屏居中半弹窗展示（MSG_WIN 触发），退出一律回首页。
  context.go('/');
}

/// RoomNotJoined 到达时的统一离房处理（房间页 stage 监听调用）。
///
/// 用房间页自身的 context/ref——导航发生前房间页必然存活，因此这里的
/// ref 读取始终安全，保证「离开房间」一定有导航出口：
/// - 主动退出（[backHome]）已标记 leaving：退出动作已在跑（可能因 HUD
///   弹窗所属对局页卸载而中断），这里只补做导航；
/// - 服务器踢人/连接断开（未走 backHome）：补做音效与幂等断开再导航。
///
/// 双重导航由 `context.mounted` 守卫消除：先完成导航的一方销毁房间页，
/// 后到的一方检查到未挂载直接返回，最终恰好导航一次。
Future<void> leaveRoomAfterNotJoined(BuildContext context,
    WidgetRef ref,) async {
  if (!context.mounted) {
    return;
  }
  final notifier = ref.read(duelRoomProvider.notifier);
  if (!notifier.isLeaving) {
    // 原子抢离房权：弹窗按钮与 stage 监听可能并发进入，markLeaving 只有
    // 第一个调用返回 true；失败的调用方直接返回，避免双导航触发
    // Navigator._debugLocked 断言。
    if (!notifier.markLeaving()) {
      return;
    }
    ref.read(ygoSoundServiceProvider).playBackNavigation();
    await ref.read(duelServiceProvider).disconnect();
    if (!context.mounted) {
      return;
    }
  }
  // 已标记 leaving（backHome 在跑）时也补做导航：backHome 持有的页面
  // 可能已在断开期间销毁，它的 context.go 不会执行。
  // 结算由决斗页的半弹窗展示（MSG_WIN 触发），离房一律回首页。
  context.go('/');
}
