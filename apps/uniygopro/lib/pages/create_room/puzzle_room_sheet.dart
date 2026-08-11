// ────────────────────────────────────────────────────────────
// Puzzle Room Sheet (残局选择 + 详情 + 启动)
// ────────────────────────────────────────────────────────────

import 'package:duelink_ai_edo/duelink_puzzle.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/servers.dart';
import '../../service_singleton.dart';
import '../../widgets/create_room/room_dialog.dart';
import 'match_store.dart';

/// 残局房面板 — 列出 vendor/Puzzles 残局合集，选择后进入本地残局对局。
class PuzzleRoomSheet extends StatefulWidget {
  final GameServer server;
  const PuzzleRoomSheet({super.key, required this.server});

  @override
  State<PuzzleRoomSheet> createState() => _PuzzleRoomSheetState();
}

class _PuzzleRoomSheetState extends State<PuzzleRoomSheet> {
  final _puzzleService = ServiceSingleton.instance.puzzleService;
  late final Future<List<PuzzleInfo>> _puzzles = _puzzleService.listPuzzles();
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: sheetContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.server.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.server.description,
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '搜索残局…',
                hintStyle: TextStyle(color: Colors.blueGrey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.blueGrey.shade400),
                filled: true,
                fillColor: Colors.blueGrey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v.trim()),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 420,
              child: FutureBuilder<List<PuzzleInfo>>(
                future: _puzzles,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '残局加载失败: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    );
                  }
                  return _buildPuzzleList(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzleList(List<PuzzleInfo> puzzles) {
    final filtered = _filter.isEmpty
        ? puzzles
        : puzzles
              .where(
                (p) => p.fileName.toLowerCase().contains(_filter.toLowerCase()),
              )
              .toList();
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          '没有匹配的残局',
          style: TextStyle(color: Colors.blueGrey.shade400),
        ),
      );
    }
    // 按分类分组（保持合集目录顺序）
    final byCategory = <String, List<PuzzleInfo>>{};
    for (final p in filtered) {
      byCategory.putIfAbsent(p.category, () => []).add(p);
    }
    final categories = byCategory.keys.toList();

    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final category = categories[i];
        final items = byCategory[category]!;
        return ExpansionTile(
          title: Text(
            '$category (${items.length})',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          iconColor: Colors.amber,
          collapsedIconColor: Colors.blueGrey.shade400,
          children: [
            for (final p in items)
              ListTile(
                dense: true,
                title: Text(
                  p.displayName,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                trailing: Icon(
                  Icons.play_arrow,
                  color: Colors.blueGrey.shade400,
                ),
                onTap: () => _showPuzzleDetail(p),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showPuzzleDetail(PuzzleInfo info) async {
    final detail = await _puzzleService.puzzleDetail(info);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A38),
        title: Text(
          info.displayName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Text(
            detail?.description ?? '在该局面下击败对手。',
            style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('开始挑战'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<MatchStore>().selectPuzzle(widget.server, info.scriptName);
    Navigator.of(context).pop(); // 关闭 sheet
    context.go('/duel-room');
  }
}
