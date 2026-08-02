import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:duelink/duelink.dart';
import '../config/servers.dart';
import '../services/match_service.dart';
import '../stores/match_store.dart';
import '../widgets/create_room/create_room_form.dart';
import '../widgets/create_room/free_room_sheet.dart';
import '../widgets/create_room/join_room_form.dart';
import '../widgets/create_room/match_join_sheet.dart';
import '../widgets/create_room/password_field.dart';

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
          IconButton(
            icon: const Icon(Icons.card_membership),
            tooltip: '卡组',
            onPressed: () => context.go('/deck-editor'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: gameServers.length,
                itemBuilder: (context, index) {
                  return _ServerCard(
                    server: gameServers[index],
                    onTap: () => _onServerTap(context, gameServers[index]),
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
            Text('正在搜索对手...', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _onServerTap(BuildContext context, GameServer server) {
    if (server.requiresMatchApi) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => MatchJoinSheet(server: server),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => FreeRoomSheet(server: server),
      );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.shade800,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
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
                    Text(server.displayName,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(server.description,
                        style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13)),
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

