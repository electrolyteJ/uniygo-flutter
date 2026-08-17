import 'dart:async';

import 'package:biz/service_providers.dart';
import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/duel_message_router.dart';
import 'package:biz/duel/field/field_overlay_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants.dart';
import 'duel_field_page.dart';
import 'duel_room_exit.dart';
import 'waiting_room_page.dart';

/// 决斗房间入口：每次进房创建独立的 [ProviderScope]，
/// 房间/对局/聊天状态随页面销毁自动回收（替代旧版的全局单例 +
/// 手动 reset）。宿主路由无需任何 Provider 装配。
///
/// scope 以 [duelRoomServiceContainer] 为 parent：服务 provider
/// （duelService/dataService/ygoSoundService）未在本 scope override，
/// 解析上溯到应用级容器，保持单例；下列房间级 provider 在此 override，
/// 保证每次进房都是全新状态、随 scope 销毁自动 dispose。
class DuelRoomPage extends StatelessWidget {
  const DuelRoomPage({super.key, required this.args});

  /// 建房/匹配参数快照（由 MatchStore.toDuelRoomParams 生成），经路由 extra 传入。
  final Map<String, Object?> args;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      // parent 作用域在 Riverpod 3.0 已移除；当前锁定 2.6.1，升级时需要
      // 改为单容器 + overrides 的方案重新实现「房间级隔离 + 服务级单例」。
      // ignore: deprecated_member_use
      parent: duelRoomServiceContainer,
      overrides: [
        duelRoomProvider.overrideWith(DuelRoomNotifier.new),
        duelChatProvider.overrideWith(DuelChatNotifier.new),
        // 四个子状态在房间 scope 内重建（不 override 会解析到 parent
        // 容器变成跨房间单例）；协调器读取子状态并负责流订阅回收。
        duelFieldProvider.overrideWith(DuelFieldNotifier.new),
        selectWindowProvider.overrideWith(SelectWindowNotifier.new),
        cardConfirmProvider.overrideWith(CardConfirmNotifier.new),
        fieldOverlayProvider.overrideWith(FieldOverlayNotifier.new),
        duelMessageRouterProvider.overrideWith(DuelMessageRouter.new),
      ],
      child: _DuelRoomView(args: args),
    );
  }
}

class _DuelRoomView extends ConsumerStatefulWidget {
  const _DuelRoomView({required this.args});

  final Map<String, Object?> args;

  @override
  ConsumerState<_DuelRoomView> createState() => _DuelRoomViewState();
}

class _DuelRoomViewState extends ConsumerState<_DuelRoomView> {
  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final args = widget.args;
    final uri = args['uri'] as Uri?;
    final username = args['username'] as String? ?? 'Guest';
    final password = args['serverPassword'] as String? ?? '';
    if (uri == null) {
      // 参数缺失：给用户可见的错误与退出路径，而不是静默返回卡在空房间页。
      _reportConnectError('房间参数缺失：未提供服务器地址');
      return;
    }

    final duelService = ref.read(duelServiceProvider);

    // connect() 必须在流订阅之前调用，否则 DuelService 门面会把订阅
    // 路由到默认的 WebSocket 服务（而不是 AI/TCP 等目标协议）。
    try {
      await duelService.connect(uri);
    } catch (e) {
      if (!mounted) return;
      _reportConnectError('连接房间失败：$e');
      return;
    }
    if (!mounted) return;

    ref.read(duelRoomProvider.notifier).start();
    ref.read(duelChatProvider.notifier).start();
    ref
        .read(duelMessageRouterProvider.notifier)
        .start(
          // l10n 依赖 BuildContext，以闭包形式注入给 router。
          phaseLabel: (phase) => getDuelPhaseText(context, phase),
        );

    duelService.setPlayerName(username);
    duelService.enterRoom(password);
  }

  /// 连接失败/参数缺失的统一处理：
  /// 1) 经房间 provider 的 errorMessage 渠道提示（复用现有 SnackBar 展示）；
  /// 2) 弹一个「回首页」对话框给用户退出路径，避免卡死在无连接的房间页。
  void _reportConnectError(String message) {
    ref.read(duelRoomProvider.notifier).setErrorText(message);
    // uri 缺失时本方法在 initState 同步触发，路由尚未就绪；
    // 对话框统一延后到帧之后再弹。错误本身已由 errorMessage 渠道提示。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('进入房间失败'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/');
              },
              child: const Text('回首页'),
            ),
          ],
        ),
      );
    });
  }

  String _roomTitle(DuelRoomState room, Map<String, Object?> args) {
    final modeName = switch (room.roomOptions?.mode) {
      RoomMode.single => '单局',
      RoomMode.match => '比赛',
      RoomMode.tag => '双打',
      _ => '',
    };
    final roomName = args['roomName'] as String? ?? '';
    if (roomName.isNotEmpty) return roomName;
    return '$modeName房间';
  }

  @override
  Widget build(BuildContext context) {
    // 连接生命周期钩子：无论以何种方式离开（系统返回、导航、被踢），
    // 房间 scope 销毁时兜底断开单例 duelService 的 socket，
    // 与 backHome 里的显式 disconnect 幂等共存。
    ref.watch(roomConnectionLifetimeProvider);
    // 房间玩家列表（日志文案中的玩家名）同步到对局状态。
    ref.listen(duelRoomProvider.select((s) => s.players), (prev, next) {
      ref.read(duelFieldProvider.notifier).syncPlayers(next);
    });
    // 服务器错误 → SnackBar。
    ref.listen(duelRoomProvider.select((s) => s.errorMessage), (prev, next) {
      if (next == null || next.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next), backgroundColor: Colors.red.shade700),
      );
      ref.read(duelRoomProvider.notifier).clearError();
    });
    // 离开房间（RoomNotJoined）→ 回首页/结算页。
    // 统一走 leaveRoomAfterNotJoined：主动退出（backHome）触发断连时
    // 这里补做导航兜底（若主动退出方在断开期间被销毁，保证仍能离房）；
    // 服务器踢人/断连（未走 backHome）时负责完整离房流程。
    ref.listen(
      duelRoomProvider.select((s) => s.stage),
      (prev, next) {
        if (prev is! RoomNotJoined && next is RoomNotJoined) {
          unawaited(leaveRoomAfterNotJoined(context, ref));
        }
      },
    );
    final room = ref.watch(duelRoomProvider);
    // 只有真正进入 RoomInDuel 后才挂载 DuelFieldPage。
    // RoomStartDuel / 猜拳 / 先后攻都属于对局启动流程，提前切到场地页会出现
    // “先闪进决斗场，再闪回等待页，然后再进一次场地页”的跳变。
    final isInDuel = room.stage is RoomInDuel;
    final isDuelEnded = room.stage is RoomDuelEnded;
    final showDuelSurface = isInDuel || isDuelEnded;
    final content = isInDuel
        ? DuelFieldPage(room.players)
        : const WaitingRoomPage();
    return PopScope(
      // 系统返回不直接弹出房间路由：先弹确认框，避免误触返回
      // 直接离房（服务器仍占座）。确认退出走 backHomeDialog → backHome。
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 对局中若正有模态选择窗口，返回键由模态自己处理（取消选择），
        // 这里不再叠加房间退出确认。
        final modalActive =
            ref.read(selectWindowProvider.notifier).selectPromptMode ==
            SelectPromptMode.modal;
        if (modalActive) return;
        backHomeDialog(
          context: context,
          ref: ref,
          title: '退出房间',
          content: '是否确认退出当前房间？',
        );
      },
      child: Scaffold(
        key: const ValueKey('duel-room-page'),
        backgroundColor: showDuelSurface
            ? Colors.brown.shade900
            : Colors.blueGrey.shade900,
        // RoomDuelEnded 时内容已切回等待页，保留 AppBar 提供退出入口；
        // 仅对局进行中（场地页自带 HUD）隐藏。
        appBar: isInDuel ? null : _buildAppBar(room),
        body: Column(
          children: [
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(DuelRoomState room) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          backHomeDialog(
            context: context,
            ref: ref,
            title: '退出房间',
            content: '是否确认退出当前房间？',
          );
        },
      ),
      title: Text(_roomTitle(room, widget.args)),
      backgroundColor: Colors.blueGrey.shade800,
      foregroundColor: Colors.white,
    );
  }
}