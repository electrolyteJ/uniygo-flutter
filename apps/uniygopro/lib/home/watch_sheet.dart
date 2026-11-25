/// 03e 比赛观看：进行中对局列表（竞技/娱乐两个观战源合并）。
///
/// 设计稿：Ardot 744179416852082 页面「03 主页大厅 · 比赛观看」。
/// 数据来自既有 SpectateService（WebSocket 实时列表），观战复用
/// prepareSpectateWatch 的进房逻辑。
library;

import 'package:flutter/material.dart';

import '../config/servers.dart';
import 'services/spectate_service.dart';
import 'spectate_watch.dart';
import 'package:ygo_settings/theme/duel_controls.dart';
import 'package:ygo_settings/theme/duel_sound.dart';
import 'package:ygo_settings/theme/duel_theme.dart';

class WatchSheet extends StatefulWidget {
  const WatchSheet({super.key, required this.onClose, required this.onWatch});

  final VoidCallback onClose;
  final void Function(Map<String, Object?> request) onWatch;

  @override
  State<WatchSheet> createState() => _WatchSheetState();
}

class _WatchFeed {
  _WatchFeed({
    required this.server,
    required this.tag,
    required this.athletic,
    required this.service,
  });

  final GameServer server;
  final String tag;
  final bool athletic;
  final SpectateService service;
}

class _WatchRow {
  const _WatchRow({
    required this.server,
    required this.room,
    required this.athletic,
  });

  final GameServer server;
  final SpectateRoom room;
  final bool athletic;
}

class _WatchSheetState extends State<WatchSheet> {
  static const _filters = ['全部', '竞技', '娱乐', '单局', '比赛', '双打'];

  final List<_WatchFeed> _feeds = [];
  int _filter = 0;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _startFeeds();
  }

  @override
  void dispose() {
    for (final feed in _feeds) {
      feed.service
        ..removeListener(_onChanged)
        ..dispose();
    }
    super.dispose();
  }

  void _startFeeds() {
    _feeds
      ..clear()
      ..add(_newFeed(ServerType.spectateAthletic, true))
      ..add(_newFeed(ServerType.spectateEntertain, false));
  }

  _WatchFeed _newFeed(ServerType type, bool athletic) {
    final server = gameServers.firstWhere((s) => s.type == type);
    final service = SpectateService(host: server.host, port: server.port)
      ..addListener(_onChanged)
      ..connect();
    return _WatchFeed(
      server: server,
      tag: athletic ? '竞技' : '娱乐',
      athletic: athletic,
      service: service,
    );
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    DuelSounds.tabSwitch();
    setState(() => _refreshing = true);
    for (final feed in _feeds) {
      feed.service
        ..removeListener(_onChanged)
        ..dispose();
    }
    _startFeeds();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _refreshing = false);
  }

  List<_WatchRow> get _rows {
    final rows = <_WatchRow>[];
    for (final feed in _feeds) {
      for (final room in feed.service.rooms) {
        if (_matches(feed, room)) {
          rows.add(
            _WatchRow(server: feed.server, room: room, athletic: feed.athletic),
          );
        }
      }
    }
    return rows;
  }

  bool _matches(_WatchFeed feed, SpectateRoom room) {
    return switch (_filter) {
      0 => true,
      1 => feed.athletic,
      2 => !feed.athletic,
      3 => room.modeLabel == '单局',
      4 => room.modeLabel == '比赛',
      5 => room.modeLabel == '双打',
      _ => true,
    };
  }

  Future<void> _watch(_WatchRow row) async {
    final request = await prepareSpectateWatch(
      context,
      server: row.server,
      room: row.room,
    );
    if (request == null) return;
    widget.onWatch(request);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
            child: Container(color: const Color(0xB8000000)),
          ),
        ),
        Positioned(
          left: 102,
          top: 45,
          width: 640,
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              color: DuelColors.panel,
              border: Border.all(color: DuelColors.borderPanel),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  child: Container(height: 2, color: DuelColors.accent),
                ),
                Positioned(
                  left: 20,
                  top: 11,
                  child: Text('比赛观看', style: DuelType.sans(14, height: 1.2)),
                ),
                Positioned(
                  left: 20,
                  top: 31,
                  child: Text(
                    '进行中的对局 · 实时推送',
                    style: DuelType.sans(8, color: DuelColors.textFaint),
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 8,
                  child: DuelHit(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(2),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 15,
                        color: DuelColors.textMuted,
                      ),
                    ),
                  ),
                ),
                for (var i = 0; i < _filters.length; i++) _filterChip(i),
                Positioned(
                  left: 20,
                  top: 73,
                  right: 22,
                  child: Container(height: 1, color: DuelColors.divider),
                ),
                _columnHeader('类型', 24),
                _columnHeader('房间', 74),
                _columnHeader('对局', 198),
                _columnHeader('赛制', 366),
                _columnHeader('人数', 422),
                Positioned(
                  left: 20,
                  top: 87,
                  width: 598,
                  height: 156,
                  child: _table(),
                ),
                Positioned(
                  left: 20,
                  top: 251,
                  right: 22,
                  child: Container(height: 1, color: DuelColors.divider),
                ),
                Positioned(
                  left: 20,
                  top: 259,
                  child: Text(
                    _footnote(),
                    style: DuelType.sans(8.5, color: DuelColors.textGhost),
                  ),
                ),
                Positioned(
                  left: 518,
                  top: 255,
                  width: 100,
                  height: 26,
                  child: DuelHit(
                    key: const ValueKey('watch-refresh'),
                    onTap: _refresh,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: DuelColors.borderPanel),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _refreshing ? '刷新中…' : '刷新',
                        style: DuelType.sans(9, color: DuelColors.textBody),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(int index) {
    final selected = index == _filter;
    return Positioned(
      left: 20 + index * 48.0,
      top: 47,
      width: 40,
      height: 18,
      child: DuelHit(
        onTap: () {
          if (_filter == index) return;
          DuelSounds.tabSwitch();
          setState(() => _filter = index);
        },
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? DuelColors.surfaceSelected
                : const Color(0xFF0A121C),
            border: Border.all(
              color: selected ? DuelColors.accent : DuelColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            _filters[index],
            textAlign: TextAlign.center,
            style: DuelType.sans(
              8,
              color: selected ? DuelColors.accent : DuelColors.textMuted,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _columnHeader(String label, double left) {
    return Positioned(
      left: left,
      top: 79,
      child: Text(
        label,
        style: DuelType.sans(7.5, color: const Color(0xFF4F5B70)),
      ),
    );
  }

  Widget _table() {
    final rows = _rows;
    if (rows.isEmpty) {
      final connecting = _feeds.any((f) => f.service.isConnecting);
      final error = _feeds.every((f) => f.service.error != null);
      final total = _feeds.fold<int>(0, (n, f) => n + f.service.rooms.length);
      return Center(
        child: Text(
          error
              ? '观战服务连接失败 · 点击刷新重试'
              : connecting
              ? '正在连接观战服务器…'
              : total == 0
              ? '当前没有进行中的对局'
              : '该筛选下暂无对局',
          style: DuelType.sans(9, color: DuelColors.textGhost),
        ),
      );
    }
    return ClipRect(
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        itemBuilder: (context, index) => _row(rows[index], index),
      ),
    );
  }

  Widget _row(_WatchRow row, int index) {
    final tagColor = row.athletic ? DuelColors.accent : DuelColors.textMuted;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      height: 28,
      decoration: BoxDecoration(
        color: index.isEven ? const Color(0xFF091019) : const Color(0xFF0A121C),
        border: Border.all(color: DuelColors.divider),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 6,
            width: 36,
            height: 16,
            child: Container(
              decoration: BoxDecoration(
                color: row.athletic
                    ? DuelColors.surfaceSelected
                    : const Color(0xFF12161F),
                border: Border.all(
                  color: row.athletic
                      ? DuelColors.accent
                      : DuelColors.borderPanel,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                row.athletic ? '竞技' : '娱乐',
                style: DuelType.sans(8, color: tagColor, height: 1),
              ),
            ),
          ),
          Positioned(
            left: 54,
            top: 7,
            width: 120,
            child: _cell(
              row.room.title.isEmpty ? '房间 ${row.room.id}' : row.room.title,
              DuelColors.textPrimary,
            ),
          ),
          Positioned(
            left: 178,
            top: 7,
            width: 160,
            child: _cell(row.room.playersLabel, DuelColors.textMuted),
          ),
          Positioned(
            left: 346,
            top: 7,
            width: 50,
            child: _cell(row.room.modeLabel, DuelColors.textBody),
          ),
          Positioned(
            left: 402,
            top: 7,
            width: 60,
            child: _cell('${row.room.users.length} 人', DuelColors.textFaint),
          ),
          Positioned(
            right: 32,
            top: 7,
            width: 60,
            child: DuelHit(
              onTap: () => _watch(row),
              child: Text(
                '观战 ›',
                textAlign: TextAlign.right,
                style: DuelType.sans(9, color: DuelColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, Color color) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: DuelType.sans(9, color: color),
    );
  }

  String _footnote() {
    final count = _rows.length;
    return '共 $count 场进行中 · 数据每 3 秒推送 · 观战为只读模式';
  }
}
