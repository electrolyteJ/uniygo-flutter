/// 游戏大厅（首页）。
///
/// 4 个一级入口：决斗 / 卡组 / 观战 / 我的。导航形态由
/// [AppLayoutSpec] 决定：compact 用底部 Tab，regular / wide 用左侧 Rail。
library;

import 'dart:async';

import 'package:account_mycard/account_mycard.dart';
import 'package:deck_editor1/deck_editor1.dart' show DeckEditorPage;
import 'package:deck_editor3/deck_editor3.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ygo_settings/ygo_settings.dart';
import 'package:ygo_settings/ygo_settings_dialog.dart';

import 'package:biz/service_singleton.dart';

import '../config/route.dart';
import '../config/servers.dart';
import '../layout/app_layout.dart';
import '../widgets/create_room/room_dialog.dart';
import '../widgets/mycard_account_button.dart';
import 'create_room/ai_room_sheet.dart';
import 'create_room/free_room_sheet.dart';
import 'create_room/match_join_sheet.dart';
import 'create_room/match_store.dart';
import 'create_room/puzzle_room_sheet.dart';
import 'create_room/spectate_room_sheet.dart';

const Color _bg = Color(0xFF0C1220);
const Color _panel = Color(0xFF13203A);
const Color _panelAlt = Color(0xFF0E1626);
const Color _cyan = Color(0xFF37E2FF);
const Color _gold = Color(0xFFFFD75A);

/// 冷启恢复「上次停留的一级分区」的 SharedPreferences 键（spec §178 原文）。
const String kAppLastTabKey = 'app_last_tab';

/// Web 端展示的服务器列表：不支持残局（duelink_ai_edo / ocgcore_edo，
/// web 构建已剔除其资产），过滤掉残局房避免点击后加载失败。
List<GameServer> get _visibleServers => kIsWeb
    ? gameServers
          .where((s) => s.type != ServerType.puzzleRoom)
          .toList(growable: false)
    : gameServers;

GameServer _serverOfType(ServerType type) =>
    gameServers.firstWhere((s) => s.type == type);

/// 「决斗」分区展示的对战模式（观战类归入「观战」分区）。
const List<ServerType> _duelModeOrder = [
  ServerType.matchAthletic,
  ServerType.matchEntertain,
  ServerType.freeRoom,
  ServerType.aiRoom,
  ServerType.puzzleRoom,
  ServerType.monsterLive,
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _destinations = [
    _LobbyDestination(label: '决斗', icon: Icons.sports_esports_outlined, selectedIcon: Icons.sports_esports),
    _LobbyDestination(label: '卡组', icon: Icons.style_outlined, selectedIcon: Icons.style),
    _LobbyDestination(label: '观战', icon: Icons.visibility_outlined, selectedIcon: Icons.visibility),
    _LobbyDestination(label: '我的', icon: Icons.person_outline, selectedIcon: Icons.person),
  ];

  int _index = 0;

  /// 用户是否已在本实例内手动切过分区。
  ///
  /// 冷启恢复是**异步**读盘：若读盘期间用户已经点了某个 Tab，不能用落后一个
  /// 异步拍的旧值覆盖用户操作，故一旦手动切过就不再写回。
  bool _userSelectedTab = false;

  /// 已访问过的分区：懒构建，避免没进「卡组」就拉取卡组市场数据。
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    unawaited(_restoreLastTab());
  }

  /// 冷启恢复上次停留的分区（spec §178）。
  ///
  /// 用 `get` + `is int` 而不是 `getInt`：`SharedPreferences.getInt` 在存量值
  /// 类型不符时直接抛 `_TypeError`（`String is not a subtype of int?`），而这里
  /// 是 fire-and-forget 的异步路径，抛出会变成未捕获异步异常。越界值
  /// （脏数据 / 分区数量减少）与非法类型一律丢弃回「决斗」，不让一条坏
  /// prefs 把用户困在一个空分区。
  Future<void> _restoreLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _userSelectedTab) return;
    final saved = prefs.get(kAppLastTabKey);
    if (saved is! int || saved < 0 || saved >= _destinations.length) return;
    if (saved == _index) return;
    setState(() {
      _index = saved;
      _visited.add(saved);
    });
  }

  /// 切分区时**立即**落盘。
  ///
  /// 刻意不放在 `dispose`：本特性就是为了「杀进程后冷启回到原分区」，
  /// 被杀进程不会走 dispose，只有点击瞬间发起写入才留得下记录。
  Future<void> _persistLastTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kAppLastTabKey, index);
  }

  void _selectTab(int index) {
    if (index == _index) return;
    ServiceSingleton.instance.ygoSoundService.playButtonTap();
    _userSelectedTab = true;
    setState(() {
      _index = index;
      _visited.add(index);
    });
    unawaited(_persistLastTab(index));
  }

  Widget _pageFor(int index) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => const _DuelTab(),
      1 => const DeckHubTab(),
      2 => const _SpectateTab(),
      _ => const _ProfileTab(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final spec = AppLayout.of(context);
    final searching = context.select<MatchStore, bool>((s) => s.isSearching);

    final content = IndexedStack(
      index: _index,
      children: [for (var i = 0; i < _destinations.length; i++) _pageFor(i)],
    );

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: spec.usesRail,
        child: Stack(
          children: [
            if (spec.usesRail)
              Row(
                children: [
                  _LobbyRail(
                    width: spec.railWidth,
                    index: _index,
                    destinations: _destinations,
                    onSelect: _selectTab,
                  ),
                  Expanded(child: content),
                ],
              )
            else
              content,
            if (searching) _buildSearchingOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: spec.usesRail
          ? null
          : SafeArea(
              top: false,
              child: _LobbyTabBar(
                height: spec.bottomTabHeight,
                index: _index,
                destinations: _destinations,
                onSelect: _selectTab,
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
}

// ────────────────────────────────────────────────────────────
// 导航
// ────────────────────────────────────────────────────────────

class _LobbyDestination {
  const _LobbyDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// 桌面 / 平板：左侧竖向导航栏。
class _LobbyRail extends StatelessWidget {
  const _LobbyRail({
    required this.width,
    required this.index,
    required this.destinations,
    required this.onSelect,
  });

  final double width;
  final int index;
  final List<_LobbyDestination> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: _panelAlt,
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.casino, color: _gold, size: 28),
          const SizedBox(height: 18),
          for (var i = 0; i < destinations.length; i++)
            _RailItem(
              width: width,
              destination: destinations[i],
              selected: i == index,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.width,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final _LobbyDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _cyan : const Color(0xFF8A93A8);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? _cyan.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              destination.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 移动横屏：底部 Tab（图标 + 文字，左右 4 等分）。
class _LobbyTabBar extends StatelessWidget {
  const _LobbyTabBar({
    required this.height,
    required this.index,
    required this.destinations,
    required this.onSelect,
  });

  final double height;
  final int index;
  final List<_LobbyDestination> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: _panelAlt,
      child: Row(
        children: [
          for (var i = 0; i < destinations.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onSelect(i),
                child: _TabBarItem(
                  destination: destinations[i],
                  selected: i == index,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabBarItem extends StatelessWidget {
  const _TabBarItem({required this.destination, required this.selected});

  final _LobbyDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _cyan : const Color(0xFF8A93A8);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          selected ? destination.selectedIcon : destination.icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 2),
        Text(
          destination.label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// 决斗分区
// ────────────────────────────────────────────────────────────

class _DuelTab extends StatelessWidget {
  const _DuelTab();

  @override
  Widget build(BuildContext context) {
    final spec = AppLayout.of(context);
    final modes = [
      for (final type in _duelModeOrder)
        if (_visibleServers.any((s) => s.type == type)) _serverOfType(type),
    ];
    final columns = switch (spec.tier) {
      AppLayoutTier.compact => 2,
      AppLayoutTier.regular => 3,
      AppLayoutTier.wide => 3,
    };
    final tileExtent = spec.tier == AppLayoutTier.compact ? 68.0 : 82.0;

    return ListView(
      padding: EdgeInsets.all(spec.pagePadding),
      children: [
        const _PlayerBar(),
        SizedBox(height: spec.gutter),
        _QuickBattleCard(spec: spec),
        SizedBox(height: spec.gutter),
        const _SectionLabel('对战模式'),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: tileExtent,
            mainAxisSpacing: spec.gutter * 0.75,
            crossAxisSpacing: spec.gutter * 0.75,
          ),
          itemBuilder: (context, i) => _ModeTile(
            server: modes[i],
            spec: spec,
            onTap: () => _onServerTap(context, modes[i]),
          ),
        ),
        if (spec.tier != AppLayoutTier.compact) ...[
          SizedBox(height: spec.gutter),
          const _NoticeBoard(),
        ],
        SizedBox(height: spec.pagePadding),
      ],
    );
  }
}

/// 玩家信息条 + 全局操作（设置 / 组卡器 / 账号）。
class _PlayerBar extends StatelessWidget {
  const _PlayerBar();

  @override
  Widget build(BuildContext context) {
    final account = context.watch<MyCardAccountApi>().account;
    final compact = AppLayout.of(context).tier == AppLayoutTier.compact;
    return Row(
      children: [
        CircleAvatar(
          radius: compact ? 18 : 22,
          backgroundColor: _panel,
          child: account == null
              ? const Icon(Icons.person, color: Color(0xFF8A93A8), size: 18)
              : Text(
                  account.displayName.isEmpty
                      ? '?'
                      : account.displayName.characters.first,
                  style: const TextStyle(
                    color: _cyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account?.displayName ?? '游客',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 15 : 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                account == null ? '未登录 · 仅可进行本地对战' : '@${account.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF8A93A8), fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.card_membership),
          tooltip: '卡组编辑器',
          color: const Color(0xFFB9C4D6),
          onPressed: () {
            ServiceSingleton.instance.ygoSoundService.playPageTransition();
            context.push(Routes.deckEditor);
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: '设置',
          color: const Color(0xFFB9C4D6),
          onPressed: () {
            ServiceSingleton.instance.ygoSoundService.playPageTransition();
            showGlobalSettingsDialog(
              context,
              extraActions: [
                if (!kIsWeb)
                  SettingsExtraAction(
                    label: '2D 场景预览',
                    icon: Icons.grid_on,
                    onTap: (ctx) {
                      Navigator.of(ctx).pop();
                      context.push(Routes.duelRoomPreview);
                    },
                  ),
                if (!kIsWeb)
                  SettingsExtraAction(
                    label: '3D 场景预览',
                    icon: Icons.view_in_ar,
                    onTap: (ctx) {
                      Navigator.of(ctx).pop();
                      context.push(Routes.duelRoom3Preview);
                    },
                  ),
              ],
            );
          },
        ),
        const MyCardAccountButton(),
      ],
    );
  }
}

/// 主 CTA：快速对战（直接进入竞技匹配面板）。
class _QuickBattleCard extends StatelessWidget {
  const _QuickBattleCard({required this.spec});

  final AppLayoutSpec spec;

  @override
  Widget build(BuildContext context) {
    final compact = spec.tier == AppLayoutTier.compact;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B3A5C), Color(0xFF122236)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _cyan.withValues(alpha: 0.25)),
      ),
      padding: EdgeInsets.all(compact ? 14 : 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '快速对战',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '一键进入竞技匹配，自动撮合旗鼓相当的对手',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF9FB3CC),
                    fontSize: compact ? 11 : 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            // 命中区下限 44（spec 触控要求）；compact 不能用 40。
            height: compact ? 44 : 48,
            child: FilledButton(
              key: const ValueKey('quick-battle-start'),
              onPressed: () =>
                  _onServerTap(context, _serverOfType(ServerType.matchAthletic)),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: const Color(0xFF231A00),
                padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 28),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('开始'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.server,
    required this.spec,
    required this.onTap,
  });

  final GameServer server;
  final AppLayoutSpec spec;
  final VoidCallback onTap;

  Color get _accent {
    switch (server.type) {
      case ServerType.matchAthletic:
        return _gold;
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

  @override
  Widget build(BuildContext context) {
    final compact = spec.tier == AppLayoutTier.compact;
    return Material(
      color: _panel,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: server.type == ServerType.aiRoom
            ? const ValueKey('home-server-ai-room')
            : null,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 10 : 14,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 34 : 42,
                height: compact ? 34 : 42,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: _accent, size: compact ? 18 : 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      server.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 2),
                      Text(
                        server.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8A93A8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 大屏专属：公告 / 活动占位卡片流。
class _NoticeBoard extends StatelessWidget {
  const _NoticeBoard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3A55)),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined, color: _cyan, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '欢迎来到 uniygo：本地 AI 与残局无需登录即可体验，竞技匹配需要 MyCard 账号。',
              style: TextStyle(
                color: Colors.blueGrey.shade200,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF8A93A8),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );
  }
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

// ────────────────────────────────────────────────────────────
// 卡组分区（市场 / 我的卡组 / 组卡器）
// ────────────────────────────────────────────────────────────

/// 卡组分区：三段式（市场 / 我的卡组 / 组卡器）。
///
/// UI 唯一实现在 `deck_editor3.DeckHubPage`（`/deck-hub` 路由与 apps/debug 共用），
/// 本类只是宿主适配层，负责注入应用级响应式档位与 deck_editor1 的组卡器：
/// - 间距：[AppLayoutSpec.pagePadding]
/// - 组卡器栏数：[AppLayoutSpec.contentColumns]（compact 1 / regular 2 / wide 3，
///   对应 deck_editor1 的单栏 / 双栏 / 三栏 240·flex·380）。
class DeckHubTab extends StatelessWidget {
  const DeckHubTab({super.key});

  @override
  Widget build(BuildContext context) {
    final spec = AppLayout.of(context);
    return DeckHubPage(
      embedded: true,
      pagePadding: spec.pagePadding,
      editorBuilder: (_) =>
          DeckEditorPage(embedded: true, columns: spec.contentColumns),
    );
  }
}

// ────────────────────────────────────────────────────────────
// 观战分区
// ────────────────────────────────────────────────────────────

class _SpectateTab extends StatelessWidget {
  const _SpectateTab();

  @override
  Widget build(BuildContext context) {
    final spec = AppLayout.of(context);
    final servers = _visibleServers
        .where(
          (s) =>
              s.type == ServerType.spectateAthletic ||
              s.type == ServerType.spectateEntertain,
        )
        .toList(growable: false);

    return ListView(
      padding: EdgeInsets.all(spec.pagePadding),
      children: [
        const _SectionLabel('观战'),
        const SizedBox(height: 8),
        for (final server in servers) ...[
          _ModeTile(
            server: server,
            spec: spec,
            onTap: () => _onServerTap(context, server),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(height: spec.gutter),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _panelAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E3A55)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF8A93A8), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '观战需要登录 MyCard 账号；房间列表随对局实时刷新。',
                  style: TextStyle(
                    color: Colors.blueGrey.shade200,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// 我的分区
// ────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final spec = AppLayout.of(context);
    final account = context.watch<MyCardAccountApi>().account;

    return ListView(
      padding: EdgeInsets.all(spec.pagePadding),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E3A55)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _panelAlt,
                child: account == null
                    ? const Icon(Icons.person, color: Color(0xFF8A93A8))
                    : Text(
                        account.displayName.isEmpty
                            ? '?'
                            : account.displayName.characters.first,
                        style: const TextStyle(
                          color: _cyan,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account?.displayName ?? '游客',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account == null
                          ? '登录后可使用竞技匹配、卡组上传与观战'
                          : '@${account.username}',
                      style: const TextStyle(
                        color: Color(0xFF8A93A8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (account == null)
                FilledButton(
                  onPressed: () {
                    ServiceSingleton.instance.ygoSoundService
                        .playPageTransition();
                    context.push(Routes.login);
                  },
                  child: const Text('登录 MyCard 账号'),
                ),
            ],
          ),
        ),
        SizedBox(height: spec.gutter),
        const _SectionLabel('设置'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _panelAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E3A55)),
          ),
          clipBehavior: Clip.antiAlias,
          // ListTile 的底色与水波纹画在最近的 Material 上；若只由带背景色的
          // DecoratedBox 包裹，会触发「ink splashes may be invisible」断言，
          // 且点击反馈确实会被遮住。这里补一层透明 Material 承接。
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: _cyan),
                  title: const Text('全局设置'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    ServiceSingleton.instance.ygoSoundService
                        .playPageTransition();
                    showGlobalSettingsDialog(context);
                  },
                ),
                const Divider(height: 1, color: Color(0xFF1E3A55)),
                ValueListenableBuilder<DuelRoomRenderer>(
                  valueListenable: DuelRoomRendererPreference.current,
                  builder: (context, value, _) => SwitchListTile(
                    secondary: const Icon(Icons.view_in_ar, color: _cyan),
                    title: const Text('3D 决斗场地'),
                    value: value == DuelRoomRenderer.room3d,
                    onChanged: (v) => DuelRoomRendererPreference.set(
                      v ? DuelRoomRenderer.room3d : DuelRoomRenderer.room2d,
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
}
