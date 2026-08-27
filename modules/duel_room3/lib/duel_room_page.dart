import 'dart:async';

import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/duel_message_router.dart';
import 'package:biz/duel/field/field_overlay_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants.dart';
import 'duel_room_exit.dart';
import 'field/duel_field_page.dart';
import 'waiting/waiting_room_page.dart';

/// duel_room3 决斗房间入口：纯 flame_3d 3D 场地 + MDPro3 风格 HUD。
///
/// 接线方式与 duel_room2 一致：每次进房创建独立 [ProviderScope]，
/// 房间/对局/聊天状态随页面销毁自动回收；服务 provider 解析上溯到
/// 应用级容器保持单例。
///
/// flame_3d 依赖 Flutter GPU，Web 不支持 → 降级提示页。
class DuelRoomPage3D extends StatelessWidget {
  const DuelRoomPage3D({super.key, required this.args});

  /// 建房/匹配参数快照（由 MatchStore.toDuelRoomParams 生成），经路由 extra 传入。
  final Map<String, Object?> args;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFF05070F),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_in_ar, size: 64, color: Color(0xFF37E2FF)),
              const SizedBox(height: 16),
              const Text(
                '3D 决斗场暂不支持 Web',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 8),
              const Text(
                'flame_3d 依赖 Flutter GPU，请在原生平台体验 duel_room3',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }
    return ProviderScope(
      // parent 作用域在 Riverpod 3.0 已移除；当前锁定 2.6.1，升级时需
      // 改为单容器 + overrides 的方案重新实现「房间级隔离 + 服务级单例」。
      // ignore: deprecated_member_use
      parent: duelRoomServiceContainer,
      overrides: [
        duelRoomProvider.overrideWith(DuelRoomNotifier.new),
        duelChatProvider.overrideWith(DuelChatNotifier.new),
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
      _reportConnectError('房间参数缺失：未提供服务器地址');
      return;
    }

    final duelService = ref.read(duelServiceProvider);

    // connect() 必须在流订阅之前调用（同 duel_room2）。
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
        .start(phaseLabel: (phase) => getDuelPhaseText(phase));

    duelService.setPlayerName(username);
    duelService.enterRoom(password);
  }

  void _reportConnectError(String message) {
    ref.read(duelRoomProvider.notifier).setErrorText(message);
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
                Navigator.of(context).maybePop();
              },
              child: const Text('返回'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 连接生命周期钩子（同 duel_room2）。
    ref.watch(roomConnectionLifetimeProvider);
    ref.listen(duelRoomProvider.select((s) => s.players), (prev, next) {
      ref.read(duelFieldProvider.notifier).syncPlayers(next);
    });
    ref.listen(duelRoomProvider.select((s) => s.errorMessage), (prev, next) {
      if (next == null || next.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next), backgroundColor: Colors.red.shade700),
      );
      ref.read(duelRoomProvider.notifier).clearError();
    });
    ref.listen(duelRoomProvider.select((s) => s.stage), (prev, next) {
      if (prev is! RoomNotJoined && next is RoomNotJoined) {
        unawaited(leaveRoomAfterNotJoined(context, ref));
      }
    });

    final room = ref.watch(duelRoomProvider);
    final isInDuel = room.stage is RoomInDuel;
    final content = isInDuel
        ? DuelFieldPage3D(players: room.players)
        : const WaitingRoomPage3D();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        backHomeDialog(
          context: context,
          ref: ref,
          title: '退出房间',
          content: '是否确认退出当前房间？',
        );
      },
      child: Scaffold(
        key: const ValueKey('duel-room3-page'),
        backgroundColor: const Color(0xFF05070F),
        appBar: isInDuel ? null : _buildAppBar(room),
        body: content,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(DuelRoomState room) {
    final modeName = switch (room.roomOptions?.mode) {
      RoomMode.single => '单局',
      RoomMode.match => '比赛',
      RoomMode.tag => '双打',
      null => '',
    };
    final roomName = widget.args['roomName'] as String? ?? '';
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
      title: Text(roomName.isNotEmpty ? roomName : '$modeName房间（3D）'),
      backgroundColor: const Color(0xFF0C1220),
      foregroundColor: Colors.white,
    );
  }
}
