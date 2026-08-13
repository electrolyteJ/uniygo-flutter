import 'dart:async';
import 'package:duel_room1/pages/duel_room/duel_field_store.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:duel_room1/pages/duel_room/waiting_room_page.dart';
import 'package:biz/service_singleton.dart';
import 'package:duel_room1/pages/duel_room/duel_field_page.dart';
import 'package:duel_room1/pages/duel_room/duel_chat_store.dart';
import 'package:duel_room1/pages/duel_room/duel_room_store.dart';
import 'package:duel_room1/pages/duel_room/duel_room_exit.dart';
import '../../debug/ocgcore_web_debug_stub.dart';

class DuelRoomPage extends StatefulWidget {
  const DuelRoomPage({super.key, required this.args});

  /// 建房/匹配参数快照（由 MatchStore.toDuelRoomParams 生成），经路由 extra 传入。
  final Map<String, Object?> args;

  @override
  State<DuelRoomPage> createState() => _DuelRoomPageState();
}

class _DuelRoomPageState extends State<DuelRoomPage> {
  final IDuelService _duelService = ServiceSingleton.instance.duelService;
  late final DuelRoomStore duelRoomStore;
  late final DuelChatStore duelChatStore;
  late final DuelFieldStore duelFieldStore;

  @override
  void initState() {
    super.initState();
    duelRoomStore = context.read<DuelRoomStore>();
    duelRoomStore.bind(_duelService);
    duelChatStore = context.read<DuelChatStore>();
    duelChatStore.bind(_duelService);
    duelFieldStore = context.read<DuelFieldStore>();
    duelFieldStore.bind(_duelService);
    _connect();
  }

  Future<void> _connect() async {
    final args = widget.args;
    final uri = args['uri'] as Uri?;
    final username = args['username'] as String? ?? 'Guest';
    final password = args['serverPassword'] as String? ?? '';
    if (uri == null) return;

    final connectFuture = _duelService.connect(uri);
    if (mounted) setState(() {});

    // connect() 必须在流订阅之前调用，否则 DuelService 门面会把订阅
    // 路由到默认的 WebSocket 服务（而不是 AI/TCP 等目标协议）。
    await connectFuture;
    if (!mounted) return;
    setState(() {});

    duelRoomStore.bindRoomStageChange(context);
    duelFieldStore.bindServerMessage(context);

    // 服务器聊天消息 → 聊天仓库（发送者名字按房间玩家列表解析）。
    duelChatStore.bindChatServerMessages((msg) {
      final chat = msg.chat;
      if (chat != null) {
        final player = duelRoomStore.players
            .where((p) => p.pos == chat.player)
            .toList();
        final name = chat.player < 0
            ? 'System'
            : (player.isNotEmpty ? player.first.name : '[${chat.player}]');
        duelChatStore.addChat(chat.player, name, chat.message);
      }
      duelChatStore.markChanged();
    });

    // 房间玩家列表（用于日志文案中的玩家名）随房间阶段异步更新，
    // 通过监听 duelRoomStore 同步到对局仓库。
    duelRoomStore.addListener(_syncPlayersFromRoom);
    _syncPlayersFromRoom();

    _duelService.setPlayerName(username);
    _duelService.enterRoom(password);
  }

  void _syncPlayersFromRoom() {
    duelFieldStore.syncPlayers(duelRoomStore.players);
  }

  String _roomTitle(DuelRoomStore duelRoomStore, Map<String, Object?> args) {
    final modeName = switch (duelRoomStore.roomOptions?.mode) {
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
    final duel = context.watch<DuelRoomStore>();
    if (duelRoomStore.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(duelRoomStore.errorMessage!),
              backgroundColor: Colors.red.shade700,
            ),
          );
          duelRoomStore.clearError();
        }
      });
    }
    // 只有真正进入 RoomInDuel 后才挂载 DuelFieldPage。
    // RoomStartDuel / 猜拳 / 先后攻都属于对局启动流程，提前切到场地页会出现
    // “先闪进决斗场，再闪回等待页，然后再进一次场地页”的跳变。
    final isInDuel = duel.stage is RoomInDuel;
    final isDuelEnded = duel.stage is RoomDuelEnded;
    final showDuelSurface = isInDuel || isDuelEnded;
    final content = isInDuel
        ? DuelFieldPage(duelRoomStore.players)
        : const WaitingRoomPage();
    return Scaffold(
      key: const ValueKey('duel-room-page'),
      backgroundColor: showDuelSurface
          ? Colors.brown.shade900
          : Colors.blueGrey.shade900,
      appBar: showDuelSurface
          ? null
          : _buildAppBar(duelRoomStore) as PreferredSizeWidget?,
      body: Column(
        children: [
          if (kDebugMode)
            _DebugStatusPanel(duel: duel, duelService: _duelService),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildAppBar(DuelRoomStore duelRoomStore) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          backHomeDialog(
            context: context,
            title: '退出房间',
            content: '是否确认退出当前房间？',
          );
        },
      ),
      title: Text(_roomTitle(duelRoomStore, widget.args)),
      backgroundColor: Colors.blueGrey.shade800,
      foregroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    duelRoomStore.removeListener(_syncPlayersFromRoom);
    super.dispose();
  }
}

class _DebugStatusPanel extends StatelessWidget {
  const _DebugStatusPanel({required this.duel, required this.duelService});

  final DuelRoomStore duel;
  final IDuelService duelService;

  @override
  Widget build(BuildContext context) {
    final error = duel.errorMessage;
    final text =
        'connectionState=${duelService.connectionState.name}; '
        'stage=${duel.stage.runtimeType}; '
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
