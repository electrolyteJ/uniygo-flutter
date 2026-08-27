import 'package:biz/duel/chat/duel_chat_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart' hide ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hud/hud_theme.dart';

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

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({required this.room});

  final DuelRoomState room;

  @override
  Widget build(BuildContext context) {
    final mode = switch (room.roomOptions?.mode) {
      RoomMode.single => '单局',
      RoomMode.match => '比赛（三局两胜）',
      RoomMode.tag => '双打',
      null => '',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: HudTheme.panel(radius: 12),
      child: Row(
        children: [
          const Icon(Icons.sports_esports, color: HudTheme.cyan, size: 20),
          const SizedBox(width: 10),
          Text('3D 决斗房间', style: HudTheme.title),
          const SizedBox(width: 12),
          Text(mode, style: HudTheme.caption),
          const Spacer(),
          const Icon(Icons.visibility, color: HudTheme.textSecondary, size: 16),
          const SizedBox(width: 4),
          Text('${room.observerCount} 观战', style: HudTheme.caption),
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
      return _SidingPanel(room: room);
    }
    return _LobbyPanel(room: room);
  }
}

/// 大厅面板：卡组选择 + 校验状态。
class _LobbyPanel extends ConsumerWidget {
  const _LobbyPanel({required this.room});

  final DuelRoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(duelRoomProvider.notifier);
    final decks = room.availableDecks;
    final invalid = room.invalidationDeckResult;
    return Center(
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
                  value: room.selectedDeckName,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0E1626),
                  style: HudTheme.body,
                  hint: const Text('选择卡组', style: HudTheme.caption),
                  items: [
                    for (final deck in decks)
                      DropdownMenuItem(
                        value: deck.deckName,
                        child: Text(deck.deckName),
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
            const SizedBox(height: 14),
            Text(
              '规则：${room.roomOptions?.lfTableHash != null ? "禁限表已启用" : "无禁限"} · '
              '${room.roomOptions?.noCheckDeck == true ? "不校验卡组" : "校验卡组"}',
              style: HudTheme.caption,
            ),
          ],
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

/// 换备面板（简化版：显示副卡组数量状态，确认提交）。
class _SidingPanel extends ConsumerWidget {
  const _SidingPanel({required this.room});

  final DuelRoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(duelRoomProvider.notifier);
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        decoration: HudTheme.panel(radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('换备阶段', style: HudTheme.title),
            const SizedBox(height: 12),
            Text(
              room.sidingInitFailed
                  ? '换备初始化失败，请重试'
                  : '本版本暂不支持换卡操作；数量合法即可直接进入下一局。',
              style: HudTheme.caption,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (room.sidingInitFailed)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: notifier.retrySidingInit,
                      child: const Text('重试'),
                    ),
                  ),
                if (room.sidingInitFailed) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: HudTheme.cyanDim,
                    ),
                    onPressed: room.isSidingCountsValid
                        ? () => notifier.confirmSiding()
                        : null,
                    child: const Text('确认换备'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部操作栏：准备/开始 + 观战切换 + 聊天。
class _ControlBar extends ConsumerWidget {
  const _ControlBar({required this.room, required this.stage});

  final DuelRoomState room;
  final RoomStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(duelRoomProvider.notifier);
    final inLobby = stage is RoomInLobby || stage is RoomJoined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: HudTheme.panel(radius: 14),
      child: Row(
        children: [
          // 聊天
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline,
                color: HudTheme.textSecondary),
            onPressed: () => _showChat(context),
          ),
          const Spacer(),
          if (inLobby && room.selfType.isDuelist) ...[
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
    );
  }

  void _showChat(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _ChatSheet(),
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
