import 'dart:async';

import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:duelink/duelink.dart' hide ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resource_data/lf_table.dart';

import '../hud/hud_theme.dart';
import 'widgets/automation_switch.dart';
import 'widgets/room_info_panel.dart';
import 'widgets/side_decking_panel.dart';

/// 自动化开关切换：先等 notifier 裁决，被接受才播放提示音。
///
/// 已准备状态下 notifier 会拒绝变更（返回 false），旧实现先响音后
/// 调用 action，被拒绝的切换也会发出声音；同时持久化失败已在
/// notifier 内走 errorMessage 渠道，这里兜底 catch，避免未处理异常。
Future<void> _onToggleAutomation(
  WidgetRef ref,
  bool value,
  Future<bool> Function(bool) action,
) async {
  // await（SharedPreferences 往返）之前先捕获声音服务：
  // 等待期间房间页可能销毁，事后再 ref.read 会抛异常。
  final sound = ref.read(ygoSoundServiceProvider);
  bool accepted;
  try {
    accepted = await action(value);
  } catch (_) {
    accepted = false;
  }
  if (!accepted) return;
  if (value) {
    sound.playToggleOn();
  } else {
    sound.playToggleOff();
  }
}

/// 编辑当前所选卡组：打开卡组编辑器，保存后刷新卡组校验。
///
/// 路由参数用通用 Map 传递（不依赖卡组编辑器的类型）：
/// `initialDeckName` / `noCheckDeck` / `lfTableHash` /
/// `lockDeckSelection` / `lockDeckName`；返回值同为 Map，
/// 含 `saved`（bool）。
Future<void> _onEditDeck(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(duelRoomProvider.notifier);
  final roomState = ref.read(duelRoomProvider);
  final opts = roomState.roomOptions;
  final result = await context.push<Map<String, Object?>>(
    '/deck-editor',
    extra: <String, Object?>{
      'initialDeckName': roomState.selectedDeckName,
      if (opts != null) 'noCheckDeck': opts.noCheckDeck,
      if (opts != null) 'lfTableHash': opts.lfTableHash,
      'lockDeckSelection': true,
      'lockDeckName': true,
    },
  );
  // 跨页 await 之后 context 可能已卸载。
  if (!context.mounted) return;
  if (result?['saved'] == true) {
    await controller.refreshSelectedDeckValidation();
  }
}

/// 换备确认：提交换备后的卡组并 ready，失败原因走 SnackBar。
Future<void> _onConfirmSiding(BuildContext context, WidgetRef ref) async {
  // 兜住一切异常：确认是 match 局间唯一推进通道，未处理异常会让
  // 换备永远卡住（第二局不开局）且无任何提示。
  String? error;
  try {
    error = await ref.read(duelRoomProvider.notifier).confirmSiding();
  } catch (e) {
    error = '换备提交失败: $e';
  }
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

/// MDPro3 风格等待室：暗色科技风，玩家卡座 + 卡组选择 + 准备/开始。
class WaitingRoomPage3D extends ConsumerWidget {
  const WaitingRoomPage3D({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(duelRoomProvider);
    final stage = room.stage;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1220), Color(0xFF05070F)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部：房间信息条
              _RoomHeader(room: room),
              const SizedBox(height: 20),
              // 玩家卡座
              _PlayerSlots(room: room),
              const SizedBox(height: 20),
              // 中部：按阶段切换（卡组选择/猜拳/选先后攻/换备）
              Expanded(child: _StageBody(room: room, stage: stage)),
              const SizedBox(height: 16),
              // 底部：操作栏 + 聊天入口
              _ControlBar(room: room, stage: stage),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部房间信息条：模式 + 观战数 + 可展开的完整房间信息面板。
///
/// 默认收起保持紧凑；点击信息图标展开 [RoomInfoPanel]（含禁限卡表弹层）。
class _RoomHeader extends ConsumerStatefulWidget {
  const _RoomHeader({required this.room});

  final DuelRoomState room;

  @override
  ConsumerState<_RoomHeader> createState() => _RoomHeaderState();
}

class _RoomHeaderState extends ConsumerState<_RoomHeader> {
  /// 房间信息面板是否展开。
  bool _infoExpanded = false;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final opts = room.roomOptions;
    final mode = switch (opts?.mode) {
      RoomMode.single => '单局',
      RoomMode.match => '比赛（三局两胜）',
      RoomMode.tag => '双打',
      null => '',
    };
    return Container(
      decoration: HudTheme.panel(radius: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.sports_esports, color: HudTheme.cyan, size: 20),
                const SizedBox(width: 10),
                Text('3D 决斗房间', style: HudTheme.title),
                const SizedBox(width: 12),
                Text(mode, style: HudTheme.caption),
                const Spacer(),
                if (opts != null) ...[
                  IconButton(
                    key: const ValueKey('room-info-toggle'),
                    icon: Icon(
                      _infoExpanded ? Icons.info : Icons.info_outline,
                      color: _infoExpanded
                          ? HudTheme.cyan
                          : HudTheme.textSecondary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _infoExpanded = !_infoExpanded),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(Icons.visibility, color: HudTheme.textSecondary, size: 16),
                const SizedBox(width: 4),
                Text('${room.observerCount} 观战', style: HudTheme.caption),
              ],
            ),
          ),
          if (_infoExpanded && opts != null) ...[
            const Divider(color: HudTheme.panelBorder, height: 1),
            FutureBuilder<LfTable?>(
              // getLfTable 按 hash 记忆化，FutureBuilder 不会反复重跑。
              future: ref
                  .read(duelRoomProvider.notifier)
                  .getLfTable(opts.lfTableHash),
              builder: (context, snapshot) => RoomInfoPanel(
                opts: opts,
                lfTable: snapshot.data,
                lfTableLoading:
                    snapshot.connectionState != ConnectionState.done &&
                    !snapshot.hasError,
                lfTableFailed: snapshot.hasError,
                cardLoader: ref.read(dataServiceProvider).getCard,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 玩家卡座：MDPro3 式立牌卡座，显示名字/准备态/房主踢人。
class _PlayerSlots extends ConsumerWidget {
  const _PlayerSlots({required this.room});

  final DuelRoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = room.players;
    final notifier = ref.read(duelRoomProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final player in players) ...[
          _PlayerSeat(
            player: player,
            isSelf: player.pos == room.selfType.slot && room.selfType.isDuelist,
            // 房主可踢其他决斗者座位（对齐 room2：房主不在 0 号位时
            // 也不能给自己挂踢人按钮；观战位 pos==7 不可踢）。
            canKick: room.isHost &&
                player.pos != room.selfType.slot &&
                player.pos != PlayerType.observer.slot,
            onKick: () => notifier.kickPlayer(player.pos),
          ),
          const SizedBox(width: 24),
        ],
        // 空座位
        for (var i = players.length; i < (room.roomOptions?.mode == RoomMode.tag ? 4 : 2); i++) ...[
          const _EmptySeat(),
          const SizedBox(width: 24),
        ],
      ],
    );
  }
}

class _PlayerSeat extends StatelessWidget {
  const _PlayerSeat({
    required this.player,
    required this.isSelf,
    required this.canKick,
    required this.onKick,
  });

  final PlayerInfo player;
  final bool isSelf;
  final bool canKick;
  final VoidCallback onKick;

  @override
  Widget build(BuildContext context) {
    final readyColor = player.ready ? HudTheme.heal : HudTheme.textSecondary;
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: HudTheme.glowPanel(
        glow: player.ready ? HudTheme.heal : HudTheme.cyan,
        radius: 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 立牌式头像
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [HudTheme.cyanDim, HudTheme.cyan],
              ),
              border: Border.all(color: readyColor, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              player.name.isEmpty ? '?' : player.name.characters.first,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HudTheme.body.copyWith(
              fontWeight: FontWeight.w700,
              color: isSelf ? HudTheme.cyan : HudTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                player.ready ? Icons.check_circle : Icons.hourglass_empty,
                size: 14,
                color: readyColor,
              ),
              const SizedBox(width: 4),
              Text(
                player.ready ? '已准备' : '未准备',
                style: HudTheme.caption.copyWith(color: readyColor),
              ),
            ],
          ),
          if (canKick) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: onKick,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.person_remove,
                  size: 16,
                  color: HudTheme.danger,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySeat extends StatelessWidget {
  const _EmptySeat();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: HudTheme.panelBorder,
          style: BorderStyle.solid,
        ),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_add, color: HudTheme.panelBorder, size: 40),
          SizedBox(height: 10),
          Text('等待加入', style: HudTheme.caption),
        ],
      ),
    );
  }
}

/// 中部：按房间阶段切换内容。
class _StageBody extends ConsumerWidget {
  const _StageBody({required this.room, required this.stage});

  final DuelRoomState room;
  final RoomStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stage is RoomSelectingHand || stage is RoomHandResult) {
      return _RpsPanel(room: room);
    }
    if (stage is RoomSelectingTurn) {
      return const _TurnSelectPanel();
    }
    if (stage is RoomSideDecking) {
      final notifier = ref.read(duelRoomProvider.notifier);
      // 换备内容随卡组规模增长，外层套滚动 + 宽度上限，避免长卡组溢出。
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: SideDeckingPanel(
              // tag 模式座位 2/3（player3/player4）同样是决斗者。
              isDuelist: room.selfType.isDuelist,
              sidingMain: room.sidingMain,
              sidingExtra: room.sidingExtra,
              sidingSide: room.sidingSide,
              sidingInitFailed: room.sidingInitFailed,
              onRetryInit: notifier.retrySidingInit,
              baselineMainCount: room.sidingBaseline?.main.length ?? 0,
              baselineExtraCount: room.sidingBaseline?.extra.length ?? 0,
              baselineSideCount: room.sidingBaseline?.side.length ?? 0,
              onMoveCard: notifier.moveSidingCard,
              onReset: notifier.resetSiding,
              onConfirm: () => _onConfirmSiding(context, ref),
            ),
          ),
        ),
      );
    }
    return _LobbyPanel(room: room);
  }
}

/// 大厅面板：卡组选择（含主/额/副数量）+ 校验状态 + 编辑卡组入口。
class _LobbyPanel extends ConsumerWidget {
  const _LobbyPanel({required this.room});

  final DuelRoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(duelRoomProvider.notifier);
    final decks = room.availableDecks;
    final invalid = room.invalidationDeckResult;
    // 卡组重命名/删除后所选名可能已不在列表中：value 逃逸会触发
    // DropdownButton 断言，逃逸时回退为未选中（对齐 room1）。
    final hasSelectedDeck =
        room.selectedDeckName != null &&
        decks.any((d) => d.deckName == room.selectedDeckName);
    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(20),
          decoration: HudTheme.panel(radius: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('选择出战卡组', style: HudTheme.title),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1626),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: HudTheme.panelBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: hasSelectedDeck ? room.selectedDeckName : null,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0E1626),
                    style: HudTheme.body,
                    hint: const Text('选择卡组', style: HudTheme.caption),
                    items: [
                      for (final deck in decks)
                        DropdownMenuItem(
                          value: deck.deckName,
                          // 下拉项内联显示主/额/副数量，便于选卡组时对比。
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  deck.deckName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '主${deck.mainCount}/额${deck.extraCount}/副${deck.sideCount}',
                                style: HudTheme.caption.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (name) {
                      if (name != null) notifier.selectDeck(name);
                    },
                  ),
                ),
              ),
              if (invalid != null && invalid.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '卡组不合法：${invalid.take(3).join("、")}',
                  style: HudTheme.caption.copyWith(color: HudTheme.danger),
                ),
              ],
              if (hasSelectedDeck) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _onEditDeck(context, ref),
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text('编辑当前卡组'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HudTheme.gold,
                      side: const BorderSide(color: HudTheme.gold),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                '规则：${room.roomOptions?.lfTableHash != null ? "禁限表已启用" : "无禁限"} · '
                '${room.roomOptions?.noCheckDeck == true ? "不校验卡组" : "校验卡组"}',
                style: HudTheme.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 猜拳面板。
class _RpsPanel extends ConsumerWidget {
  const _RpsPanel({required this.room});

  final DuelRoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(duelRoomProvider.notifier);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: HudTheme.glowPanel(radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('猜拳决定先后攻', style: HudTheme.title),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RpsButton(
                  icon: Icons.content_cut,
                  label: '剪刀',
                  onTap: () => notifier.sendHand(HandType.scissors),
                ),
                const SizedBox(width: 18),
                _RpsButton(
                  icon: Icons.circle_outlined,
                  label: '石头',
                  onTap: () => notifier.sendHand(HandType.rock),
                ),
                const SizedBox(width: 18),
                _RpsButton(
                  icon: Icons.back_hand_outlined,
                  label: '布',
                  onTap: () => notifier.sendHand(HandType.paper),
                ),
              ],
            ),
            if (room.myHandResult != null) ...[
              const SizedBox(height: 14),
              const Text('已出拳，等待对方…', style: HudTheme.caption),
            ],
          ],
        ),
      ),
    );
  }
}

class _RpsButton extends StatelessWidget {
  const _RpsButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 88,
        height: 88,
        decoration: HudTheme.glowPanel(radius: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: HudTheme.cyan, size: 34),
            const SizedBox(height: 8),
            Text(label, style: HudTheme.body),
          ],
        ),
      ),
    );
  }
}

/// 选先后攻面板。
class _TurnSelectPanel extends ConsumerWidget {
  const _TurnSelectPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(duelRoomProvider.notifier);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: HudTheme.glowPanel(radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('你赢了猜拳！选择先攻还是后攻', style: HudTheme.title),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RpsButton(
                  icon: Icons.looks_one_outlined,
                  label: '先攻',
                  onTap: () => notifier.sendTp(true),
                ),
                const SizedBox(width: 18),
                _RpsButton(
                  icon: Icons.looks_two_outlined,
                  label: '后攻',
                  onTap: () => notifier.sendTp(false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部操作栏：准备/开始 + 观战切换 + 聊天 + 自动化开关。
class _ControlBar extends ConsumerWidget {
  const _ControlBar({required this.room, required this.stage});

  final DuelRoomState room;
  final RoomStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(duelRoomProvider.notifier);
    final inLobby = stage is RoomInLobby || stage is RoomJoined;
    final isDuelist = room.selfType.isDuelist;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: HudTheme.panel(radius: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 自动化开关行：仅决斗者可见（自动猜拳/先后手对观战无意义），
          // 已准备后禁用，避免与准备态冲突（对齐 room1）。
          if (inLobby && isDuelist) ...[
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                if (room.isHost)
                  AutomationSwitch(
                    label: '自动加入决斗',
                    value: room.autoDuelEnabled,
                    enabled: !room.isSelfReady,
                    onChanged: (v) => unawaited(
                      _onToggleAutomation(ref, v, notifier.setAutoDuelEnabled),
                    ),
                  ),
                AutomationSwitch(
                  label: '自动猜拳',
                  value: room.autoHandEnabled,
                  enabled: !room.isSelfReady,
                  onChanged: (v) => unawaited(
                    _onToggleAutomation(ref, v, notifier.setAutoHandEnabled),
                  ),
                ),
                AutomationSwitch(
                  label: '自动随机先后手',
                  value: room.autoTurnOrderEnabled,
                  enabled: !room.isSelfReady,
                  onChanged: (v) => unawaited(
                    _onToggleAutomation(
                      ref,
                      v,
                      notifier.setAutoTurnOrderEnabled,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              // 聊天
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline,
                    color: HudTheme.textSecondary),
                onPressed: () => _showChat(context),
              ),
              const Spacer(),
              if (inLobby && isDuelist) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HudTheme.textPrimary,
                    side: const BorderSide(color: HudTheme.panelBorder),
                  ),
                  onPressed: notifier.becomeObserver,
                  child: const Text('转为观战'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: room.isSelfReady
                        ? HudTheme.panelBorder
                        : HudTheme.cyanDim,
                  ),
                  onPressed: () => notifier.toggleReady(),
                  child: Text(room.isSelfReady ? '取消准备' : '准备'),
                ),
                if (room.isHost) ...[
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: HudTheme.gold,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: room.isAllReady ? notifier.startDuel : null,
                    child: const Text('开始决斗'),
                  ),
                ],
              ] else if (inLobby) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HudTheme.textPrimary,
                    side: const BorderSide(color: HudTheme.panelBorder),
                  ),
                  onPressed: notifier.becomeDuelist,
                  child: const Text('转为决斗者'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showChat(BuildContext context) {
    // showModalBottomSheet 把内容挂到根 Navigator 的 Overlay 上，
    // 在房间级 ProviderScope（DuelRoomPage.build 内创建）之外，
    // 弹层里的 Consumer 会找不到 ProviderScope。捕获房间容器并桥接。
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => UncontrolledProviderScope(
        container: container,
        child: const _ChatSheet(),
      ),
    );
  }
}

class _ChatSheet extends ConsumerStatefulWidget {
  const _ChatSheet();

  @override
  ConsumerState<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<_ChatSheet> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(duelChatProvider).messages;
    return Container(
      height: 360,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: HudTheme.glowPanel(radius: 16),
      child: Column(
        children: [
          const Text('聊天', style: HudTheme.title),
          const Divider(color: HudTheme.panelBorder),
          Expanded(
            child: ListView(
              reverse: true,
              children: [
                for (final msg in messages.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${msg.name}: ${msg.message}',
                      style: HudTheme.body,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  style: HudTheme.body,
                  decoration: const InputDecoration(
                    hintText: '发送消息…',
                    hintStyle: HudTheme.caption,
                    isDense: true,
                  ),
                  onSubmitted: _send,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, size: 18),
                color: HudTheme.cyan,
                onPressed: () => _send(_input.text),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    ref.read(duelChatProvider.notifier).sendChat(trimmed);
    _input.clear();
  }
}
