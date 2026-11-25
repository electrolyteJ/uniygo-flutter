/// 03 主页：玩家条 / 公告 / 精选卡面 / 匹配条 / 底部页签。
///
/// 设计稿：Ardot 744179416852082 页面「03 主页大厅」。
/// 匹配条与「建房」页共享 [ModeSelection]；比赛观看与设置以页面内弹层呈现。
library;

import 'dart:math' as math;

import 'package:account_mycard/account_mycard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/route.dart';
import '../config/servers.dart';
import '../ui/duel_canvas.dart';
import 'package:ygo_settings/theme/duel_controls.dart';
import 'package:ygo_settings/theme/duel_sound.dart';
import 'package:ygo_settings/theme/duel_theme.dart';
import '../util/start_util.dart';
import '../util/snack_bar_util.dart';
import '../create_room/models/mode_models.dart';
import 'home_models.dart';
import 'package:ygo_settings/ygo_settings.dart';

import 'watch_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _watchOpen = false;
  final FocusNode _escapeFocus = FocusNode(debugLabel: 'home-escape');

  @override
  void dispose() {
    _escapeFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (_watchOpen) {
        _closeWatch();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _tap() => DuelSounds.tap();

  void _openModes() {
    DuelSounds.pageTransition();
    context.push(Routes.createRoom);
  }

  Future<void> _startCurrent() async {
    final mode = ModeSelection.instance.current;
    if (mode.action == DuelModeAction.matchAthletic ||
        mode.action == DuelModeAction.matchEntertain) {
      DuelSounds.pageTransition();
      // 进入建房页的匹配盘并自动开始匹配（登录/取消/等待都在盘上完成）。
      context.push(Routes.createRoom, extra: 'start');
      return;
    }
    await startDuelRoom(context);
  }

  void _openWatch() {
    DuelSounds.dialogOpen();
    setState(() => _watchOpen = true);
  }

  void _closeWatch() {
    DuelSounds.dialogClose();
    setState(() => _watchOpen = false);
  }

  void _onWatch(Map<String, Object?>? request) {
    setState(() => _watchOpen = false);
    context.go(Routes.duelRoom, extra: request);
  }

  void _openSettings() {
    DuelSounds.dialogOpen();
    final account = context.read<MyCardAccountApi>().account;
    showGlobalSettingsDialog(
      context,
      account: YgoSettingsAccount(
        isLoggedIn: account != null,
        name: account?.displayName,
        username: account?.username,
        onSignOut: () => context.read<MyCardAccountApi>().signOut(),
        onGoLogin: () => context.go(Routes.login),
      ),
      onOpenPreview: (is3d) =>
          context.push(is3d ? Routes.duelRoom3Preview : Routes.duelRoomPreview),
    );
  }

  void _openDeckHub() {
    DuelSounds.pageTransition();
    context.push(Routes.deckHub);
  }

  void _openCardLive() {
    DuelSounds.pageTransition();
    context.push(Routes.cardLive);
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<MyCardAccountApi>().account;

    return Scaffold(
      backgroundColor: DuelColors.base,
      resizeToAvoidBottomInset: false,
      body: Focus(
        focusNode: _escapeFocus,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: DuelStage(
          backdrop: DuelBackdropKind.home,
          child: Stack(
            children: [
              _playerBlock(account),
              _currencyRow(),
              _controls(),
              _announcements(),
              _featurePanel(),
              _matchBar(),
              _tabs(),
              _latency(),
              if (_watchOpen)
                WatchSheet(onClose: _closeWatch, onWatch: _onWatch),
            ],
          ),
        ),
      ),
    );
  }

  // ── 左上玩家条 ──────────────────────────────────────────────────
  Widget _playerBlock(MyCardAccount? account) {
    final name = account?.displayName.isNotEmpty == true
        ? account!.displayName
        : '游客';
    final initial = name.characters.first;
    final isGuest = account == null;

    return Positioned(
      left: 16,
      top: 10,
      child: DuelHit(
        onTap: isGuest ? () => context.go(Routes.login) : null,
        borderRadius: BorderRadius.circular(2),
        semanticLabel: isGuest ? '游客，点击登录' : name,
        child: SizedBox(
          width: 220,
          height: 46,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 头像框 + 等级徽标
              Positioned(
                left: 0,
                top: 0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1420),
                        border: Border.all(color: DuelColors.borderSoft),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: DuelType.serif(14, height: 1),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 54,
                top: -1,
                child: Text(name, style: DuelType.sans(13, height: 1.2)),
              ),
              Positioned(
                left: 54,
                top: 18,
                child: Text(
                  isGuest ? '未登录 · 点击登录' : '已登录 · MyCard',
                  style: DuelType.sans(9, color: DuelColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 右上货币 ────────────────────────────────────────────────────
  Widget _currencyRow() {
    return Positioned(
      right: 149,
      top: 11,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: DuelColors.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text('12,480 DP', style: DuelType.latin(11, height: 1.2)),
          const SizedBox(width: 12),
          Container(width: 1, height: 18, color: DuelColors.divider),
          const SizedBox(width: 10),
          Text(
            '860 GEM',
            style: DuelType.latin(11, color: DuelColors.textMuted, height: 1.2),
          ),
        ],
      ),
    );
  }

  // ── 邮件 / 设置 ─────────────────────────────────────────────────
  Widget _controls() {
    return Positioned(
      right: 16,
      top: 8,
      child: Row(
        children: [
          DuelHit(
            key: const ValueKey('home-mail'),
            onTap: () {
              _tap();
              showSnackBar(context, '暂无新邮件');
            },
            borderRadius: BorderRadius.circular(2),
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(
                Icons.mail_outline,
                size: 15,
                color: DuelColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 18),
          DuelHit(
            key: const ValueKey('home-settings'),
            onTap: _openSettings,
            borderRadius: BorderRadius.circular(2),
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(
                Icons.settings_outlined,
                size: 16,
                color: DuelColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 左侧公告 ────────────────────────────────────────────────────
  Widget _announcements() {
    return Positioned(
      left: 16,
      top: 92,
      width: 234,
      height: 204,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 4,
            child: Text('公告', style: DuelType.sans(12, height: 1.2)),
          ),
          Positioned(
            left: 144,
            top: 6,
            width: 90,
            child: Align(
              alignment: Alignment.centerRight,
              child: DuelHit(
                onTap: () {
                  _tap();
                  showSnackBar(context, '公告中心即将开放');
                },
                child: Text(
                  '更多 ›',
                  style: DuelType.sans(8.5, color: DuelColors.textFaint),
                ),
              ),
            ),
          ),
          // 公告大图
          Positioned(
            left: 0,
            top: 24,
            width: 234,
            height: 88,
            child: DuelHit(
              onTap: () {
                _tap();
                showSnackBar(context, '禁卡表页面即将开放');
              },
              child: Container(
                decoration: BoxDecoration(
                  color: DuelColors.surfaceRaised,
                  border: Border.all(color: DuelColors.borderSoft),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 12,
                      top: 8,
                      right: 12,
                      child: Text(
                        kHomeHighlight.title,
                        style: DuelType.sans(11, height: 1.2),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 26,
                      right: 12,
                      child: Text(
                        kHomeHighlight.subtitle,
                        style: DuelType.sans(8.5, color: DuelColors.textMuted),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 62,
                      child: Text(
                        kHomeHighlight.action,
                        style: DuelType.sans(9, color: DuelColors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 公告列表
          Positioned(
            left: 0,
            top: 120,
            width: 234,
            height: 84,
            child: Container(
              decoration: BoxDecoration(
                color: DuelColors.surface,
                border: Border.all(color: DuelColors.borderSoft),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  for (var i = 0; i < kHomeAnnouncements.length; i++) ...[
                    if (i > 0) Container(height: 1, color: DuelColors.divider),
                    SizedBox(
                      height: 26,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          kHomeAnnouncements[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DuelType.sans(
                            8.5,
                            color: DuelColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 中间精选卡面 ────────────────────────────────────────────────
  Widget _featurePanel() {
    return Positioned(
      left: 262,
      top: 96,
      width: 290,
      height: 196,
      child: DuelHit(
        onTap: () {
          _tap();
          showSnackBar(context, '卡牌详情即将开放');
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              colors: [Color(0xD91B4A63), DuelColors.baseMid],
            ),
            border: Border.all(color: DuelColors.divider),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                _heroCard(
                  left: 38,
                  top: 28,
                  width: 80,
                  height: 110,
                  angle: -14,
                  fill: DuelColors.surfaceRaised,
                  border: DuelColors.borderSoft,
                ),
                _heroCard(
                  left: 94,
                  top: 20,
                  width: 80,
                  height: 120,
                  angle: 0,
                  fill: DuelColors.cardDeep,
                  border: DuelColors.accent,
                  highlighted: true,
                ),
                _heroCard(
                  left: 150,
                  top: 28,
                  width: 80,
                  height: 110,
                  angle: 14,
                  fill: DuelColors.surfaceRaised,
                  border: DuelColors.borderSoft,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 142,
                  child: Center(
                    child: Text(
                      kHomeFeature.name,
                      style: DuelType.sans(
                        11,
                        weight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 158,
                  child: Center(
                    child: Text(
                      kHomeFeature.subtitle,
                      style: DuelType.sans(8, color: DuelColors.textDim),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroCard({
    required double left,
    required double top,
    required double width,
    required double height,
    required double angle,
    required Color fill,
    required Color border,
    bool highlighted = false,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border, width: highlighted ? 1.2 : 1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  // ── 右下匹配条（设计稿 194×59，r=8） ──────────────────────────
  Widget _matchBar() {
    return Positioned(
      left: 626,
      top: 283,
      width: 194,
      height: 59,
      child: AnimatedBuilder(
        animation: ModeSelection.instance,
        builder: (context, _) {
          final mode = ModeSelection.instance.current;
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF070D16),
              border: Border.all(color: DuelColors.borderSoft),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: 128,
                  height: 59,
                  child: DuelHit(
                    key: const ValueKey('home-match-bar'),
                    onTap: _openModes,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 10,
                          top: 7,
                          child: Icon(
                            Icons.emoji_events_outlined,
                            size: 14,
                            color: DuelColors.accent,
                          ),
                        ),
                        Positioned(
                          left: 30,
                          top: 4,
                          child: Text(
                            '${mode.title} ▾',
                            style: DuelType.sans(11, height: 1.2),
                          ),
                        ),
                        Positioned(
                          left: 30,
                          top: 21,
                          child: Text(
                            mode.barText,
                            style: DuelType.sans(
                              7,
                              color: DuelColors.textMuted,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 30,
                          top: 36,
                          child: Text(
                            '切换 ›',
                            style: DuelType.sans(7.5, color: DuelColors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 128,
                  top: 7,
                  width: 58,
                  height: 45,
                  child: DuelHit(
                    key: const ValueKey('home-start-match'),
                    onTap: _startCurrent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: DuelColors.accent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        mode.actionLabel,
                        style: DuelType.sans(
                          11,
                          color: DuelColors.inkOnAccent,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── 底部页签：比赛观看 + 卡组/战绩/商店/活动/鉴赏 ───────────────
  Widget _tabs() {
    const separators = [616.0, 656.0, 696.0, 736.0, 776.0];
    final items = <({String label, double left, VoidCallback onTap})>[
      (label: '卡组', left: 626, onTap: _openDeckHub),
      (label: '战绩', left: 666, onTap: () => showSnackBar(context, '战绩即将开放')),
      (label: '商店', left: 706, onTap: () => showSnackBar(context, '商店即将开放')),
      (label: '活动', left: 746, onTap: () => showSnackBar(context, '活动页即将开放')),
      (label: '鉴赏', left: 786, onTap: _openCardLive),
    ];

    return Stack(
      children: [
        Positioned(
          left: 536,
          top: 352,
          child: Container(
            width: 1,
            height: 16,
            color: const Color(0xFF2A4763),
          ),
        ),
        Positioned(
          left: 546,
          top: 348,
          child: DuelHit(
            key: const ValueKey('home-watch'),
            onTap: _openWatch,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '比赛观看 ▾',
                style: DuelType.sans(12, color: DuelColors.accent),
              ),
            ),
          ),
        ),
        Positioned(
          left: 546,
          top: 372,
          child: Container(width: 60, height: 2, color: DuelColors.accent),
        ),
        for (final x in separators)
          Positioned(
            left: x,
            top: 356,
            child: Container(
              width: 1,
              height: 12,
              color: const Color(0xFF243B52),
            ),
          ),
        for (final item in items)
          Positioned(
            left: item.left,
            top: 348,
            child: DuelHit(
              onTap: () {
                _tap();
                item.onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  item.label,
                  style: DuelType.sans(12, color: DuelColors.textMuted),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _latency() {
    final host = gameServers
        .firstWhere((s) => s.type == ServerType.matchAthletic)
        .host;
    return Positioned(
      right: 24,
      top: 371,
      width: 272,
      child: Text(
        '38 ms · $host',
        textAlign: TextAlign.right,
        style: DuelType.latin(8.5, color: DuelColors.textGhost),
      ),
    );
  }
}
