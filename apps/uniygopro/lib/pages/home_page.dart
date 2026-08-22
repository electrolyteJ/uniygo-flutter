import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:account_mycard/account_mycard.dart';
import '../widgets/mycard_account_button.dart';
import '../config/servers.dart';
import 'package:biz/service_singleton.dart';
import '../widgets/create_room/room_dialog.dart';
import 'create_room/match_store.dart';
import 'create_room/ai_room_sheet.dart';
import 'create_room/free_room_sheet.dart';
import 'create_room/match_join_sheet.dart';
import 'create_room/puzzle_room_sheet.dart';
import 'create_room/spectate_room_sheet.dart';

/// Web 端展示的服务器列表：不支持残局（duelink_ai_edo / ocgcore_edo，
/// web 构建已剔除其资产），过滤掉残局房避免点击后加载失败。
List<GameServer> get _webGameServers => gameServers
    .where((s) => s.type != ServerType.puzzleRoom)
    .toList(growable: false);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final matchStore = context.watch<MatchStore>();

    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.casino, color: Colors.amber),
            SizedBox(width: 8),
            Text('uniygo'),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // MyCard 账号入口：未登录显示登录图标，已登录显示用户名首字。
          MyCardAccountButton(),
          IconButton(
            icon: const Icon(Icons.card_membership),
            tooltip: '卡组',
            onPressed: () {
              ServiceSingleton.instance.ygoSoundService.playPageTransition();
              context.go('/deck-editor');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: kIsWeb ? _webGameServers.length : gameServers.length,
                itemBuilder: (context, index) {
                  final server = kIsWeb
                      ? _webGameServers[index]
                      : gameServers[index];
                  return _ServerCard(
                    server: server,
                    onTap: () => _onServerTap(context, server),
                  );
                },
              ),
            ),
            if (matchStore.isSearching) _buildSearchingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 16),
            Text(
              '正在搜索对手...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _onServerTap(BuildContext context, GameServer server) {
    ServiceSingleton.instance.ygoSoundService.playButtonTap();
    if (server.type == ServerType.monsterLive) {
      // 怪兽动画鉴赏页（cardlive）：直接跳转，无房间弹窗。
      ServiceSingleton.instance.ygoSoundService.playPageTransition();
      context.go('/card-live');
      return;
    }
    ServiceSingleton.instance.ygoSoundService.playDialogOpen();
    if (server.type == ServerType.puzzleRoom) {
      showRoomDialog(context, PuzzleRoomSheet(server: server));
    } else if (server.type == ServerType.aiRoom) {
      showRoomDialog(context, AiRoomSheet(server: server));
    } else if (server.type == ServerType.spectateAthletic ||
        server.type == ServerType.spectateEntertain) {
      showRoomDialog(context, SpectateRoomSheet(server: server));
    } else if (server.requiresMatchApi) {
      showRoomDialog(context, MatchJoinSheet(server: server));
    } else {
      showRoomDialog(context, FreeRoomSheet(server: server));
    }
  }
}

// ────────────────────────────────────────────────────────────
// Server Card (3 items: 竞技, 娱乐, 自由)
// ────────────────────────────────────────────────────────────

class _ServerCard extends StatelessWidget {
  final GameServer server;
  final VoidCallback onTap;

  const _ServerCard({required this.server, required this.onTap});

  IconData get _icon {
    switch (server.type) {
      case ServerType.matchAthletic:
        return Icons.emoji_events;
      case ServerType.matchEntertain:
        return Icons.sports_esports;
      case ServerType.freeRoom:
        return Icons.meeting_room;
      case ServerType.aiRoom:
        return Icons.smart_toy;
      case ServerType.puzzleRoom:
        return Icons.extension;
      case ServerType.monsterLive:
        return Icons.movie_filter;
      case ServerType.spectateAthletic:
      case ServerType.spectateEntertain:
        return Icons.visibility;
    }
  }

  Color get _accentColor {
    switch (server.type) {
      case ServerType.matchAthletic:
        return Colors.amber;
      case ServerType.matchEntertain:
        return Colors.lightBlue;
      case ServerType.freeRoom:
        return Colors.green;
      case ServerType.aiRoom:
        return Colors.deepOrange;
      case ServerType.puzzleRoom:
        return Colors.deepPurpleAccent;
      case ServerType.monsterLive:
        return Colors.tealAccent;
      case ServerType.spectateAthletic:
        return Colors.orangeAccent;
      case ServerType.spectateEntertain:
        return Colors.cyanAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.shade800,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        key: server.type == ServerType.aiRoom
            ? const ValueKey('home-server-ai-room')
            : null,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: _accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      server.description,
                      style: TextStyle(
                        color: Colors.blueGrey.shade300,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.blueGrey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
