import 'dart:async';

import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants.dart';
import '../../debug/ocgcore_web_debug_stub.dart';
import '../../providers/service_providers.dart';
import '../../state/duel_chat_state.dart';
import '../../state/card_confirm_state.dart';
import '../../state/duel_field_state.dart';
import '../../state/duel_field_controller.dart';
import '../../state/duel_room_state.dart';
import '../../state/field_overlay_state.dart';
import '../../state/select_window_state.dart';
import 'duel_field_page.dart';
import 'duel_room_exit.dart';
import 'waiting_room_page.dart';

/// 决斗房间入口：每次进房创建独立的 [ProviderScope]，
/// 房间/对局/聊天状态随页面销毁自动回收（替代 duel_room1 的全局单例 +
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
      // parent 作用域在 Riverpod 3.0 已移除；当前锁定 2.6.1，升级时需
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
        duelFieldControllerProvider.overrideWith(createDuelFieldController),
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
    if (uri == null) return;

    final duelService = ref.read(duelServiceProvider);

    // connect() 必须在流订阅之前调用，否则 DuelService 门面会把订阅
    // 路由到默认的 WebSocket 服务（而不是 AI/TCP 等目标协议）。
    await duelService.connect(uri);
    if (!mounted) return;

    ref.read(duelRoomProvider.notifier).start();
    ref.read(duelChatProvider.notifier).start();
    ref.read(duelFieldControllerProvider).bindServerMessage(
      // l10n 依赖 BuildContext，以闭包形式注入给 store。
      phaseLabel: (phase) => getDuelPhaseText(context, phase),
    );

    duelService.setPlayerName(username);
    duelService.enterRoom(password);
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
    // 房间玩家列表（日志文案中的玩家名）同步到对局 store。
    ref.listen(duelRoomProvider.select((s) => s.players), (prev, next) {
      ref.read(duelFieldProvider.notifier).syncPlayers(next);
    });
    // 服务器错误 → SnackBar（替代原 build 内 addPostFrameCallback 写法）。
    ref.listen(duelRoomProvider.select((s) => s.errorMessage), (prev, next) {
      if (next == null || next.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next),
          backgroundColor: Colors.red.shade700,
        ),
      );
      ref.read(duelRoomProvider.notifier).clearError();
    });
    // 游戏结束或离开房间（RoomNotJoined）→ 回首页。
    ref.listen(duelRoomProvider.select((s) => s.stage), (prev, next) {
      if (prev is! RoomNotJoined && next is RoomNotJoined) {
        backHome(context, ref);
      }
    });

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
    return Scaffold(
      key: const ValueKey('duel-room-page'),
      backgroundColor: showDuelSurface
          ? Colors.brown.shade900
          : Colors.blueGrey.shade900,
      appBar: showDuelSurface ? null : _buildAppBar(room),
      body: Column(
        children: [
          if (kDebugMode) _DebugStatusPanel(room: room),
          Expanded(child: content),
        ],
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

class _DebugStatusPanel extends ConsumerWidget {
  const _DebugStatusPanel({required this.room});

  final DuelRoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duelService = ref.watch(duelServiceProvider);
    final error = room.errorMessage;
    final text =
        'connectionState=${duelService.connectionState.name}; '
        'stage=${room.stage.runtimeType}; '
        'errorMessage=${(error == null || error.isEmpty) ? '<none>' : error}; '
        '${ocgcoreWebDebugStatus()}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black54,
      child: Text(
        text,
        key: const ValueKey('duel-room-debug-status'),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
