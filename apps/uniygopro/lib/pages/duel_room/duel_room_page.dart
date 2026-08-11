import 'dart:async';
import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uniygopro/pages/duel_room/waiting/waiting_room_page.dart';
import '../../service_singleton.dart';
import '../../debug/ocgcore_web_debug.dart';
import 'duel/duel_field_store.dart';
import 'duel/duel_field_page.dart';
import 'waiting/duel_chat_store.dart';
import 'duel_room_store.dart';
import '../create_room/match_store.dart';
import 'duel_room_exit.dart';

class DuelRoomPage extends StatefulWidget {
  const DuelRoomPage({super.key});

  @override
  State<DuelRoomPage> createState() => _DuelRoomPageState();
}

class _DuelRoomPageState extends State<DuelRoomPage> {
  final IDuelService _duelService = ServiceSingleton.instance.duelService;
  late final DuelRoomStore duelRoomStore;
  late final DuelChatStore duelChatStore;
  late final DuelFieldStore duelFieldStore;
  late final MatchStore matchRoomStore;

  @override
  void initState() {
    super.initState();
    duelRoomStore = context.read<DuelRoomStore>();
    duelRoomStore.bind(_duelService);
    duelChatStore = context.read<DuelChatStore>();
    duelChatStore.bind(_duelService);
    duelFieldStore = context.read<DuelFieldStore>();
    duelFieldStore.bind(_duelService);
    matchRoomStore = context.read<MatchStore>();
    _connect();
  }

  Future<void> _connect() async {
    final host = matchRoomStore.serverAddress;
    final port = matchRoomStore.serverPort;
    final env = matchRoomStore.environment;
    final password = matchRoomStore.serverPassword;
    if (host == null || port == null) {
      return;
    }
    // 残局环境：URI 路径携带残局脚本（puzzle://local/<category>/<file>.lua），
    // 路径段逐个编码以兼容空格/方括号等特殊字符。
    final Uri? uri;
    if (env.isPuzzle) {
      final script = matchRoomStore.puzzleScript;
      if (script == null || script.isEmpty) {
        return;
      }
      final rel = script.startsWith('puzzle/') ? script.substring(7) : script;
      final encoded = rel.split('/').map(Uri.encodeComponent).join('/');
      uri = Uri.tryParse('${env.schema}://$host/$encoded');
    } else if (env.isAi) {
      // AI 环境：房间参数经 URI 查询参数传递给本地引擎连接。
      final base = Uri.tryParse('${env.schema}://$host:$port');
      final options = matchRoomStore.roomOptions;
      uri = base?.replace(queryParameters: options?.toAiQuery());
    } else {
      uri = Uri.tryParse('${env.schema}://$host:$port');
    }
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

    _duelService.setPlayerName(matchRoomStore.username);
    _duelService.enterRoom(password ?? '');
  }

  void _syncPlayersFromRoom() {
    duelFieldStore.syncPlayers(duelRoomStore.players);
  }

  String _roomTitle(DuelRoomStore duelRoomStore, MatchStore match) {
    final modeName = switch (duelRoomStore.roomOptions?.mode) {
      RoomMode.single => '单局',
      RoomMode.match => '比赛',
      RoomMode.tag => '双打',
      _ => '',
    };
    if (match.roomName.isNotEmpty) return match.roomName;
    return '$modeName房间';
  }

  @override
  Widget build(BuildContext context) {
    final duel = context.watch<DuelRoomStore>();
    final matchRoomStore = context.watch<MatchStore>();
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
          : _buildAppBar(duelRoomStore, matchRoomStore) as PreferredSizeWidget?,
      body: Column(
        children: [
          if (kDebugMode)
            _DebugStatusPanel(duel: duel, duelService: _duelService),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildAppBar(DuelRoomStore duelRoomStore, MatchStore matchRoomStore) {
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
      title: Text(_roomTitle(duelRoomStore, matchRoomStore)),
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
