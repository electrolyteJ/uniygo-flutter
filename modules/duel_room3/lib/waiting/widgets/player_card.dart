/// 等待室玩家席位卡（05a 设计稿）。
library;

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart' hide CardInfo, ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../hud/hud_theme.dart';
import 'duel_style.dart';

class PlayerCard extends ConsumerWidget {
  const PlayerCard({
    super.key,
    required this.room,
    this.roomId,
    required this.isSelf,
    required this.onChangeDeck,
    required this.onEditDeck,
    required this.onShowDeckCheck,
    required this.onInvite,
  });

  final VoidCallback onChangeDeck;
  final VoidCallback onEditDeck;
  final VoidCallback onShowDeckCheck;
  final VoidCallback onInvite;

  final DuelRoomState room;
  final String? roomId;
  final bool isSelf;

  PlayerInfo? get _self {
    for (final p in room.players) {
      if (p.pos == room.selfType.slot) return p;
    }
    return null;
  }

  /// 除自己以外的玩家（2v2 时可能有两名对手/队友）。
  List<PlayerInfo> get _others =>
      room.players.where((p) => p.pos != room.selfType.slot).toList();

  PlayerInfo? get _opponent => _others.isEmpty ? null : _others.first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = isSelf ? _self : _opponent;
    final opts = room.roomOptions;
    final deck = room.selectedDeckName;
    final invalid = room.invalidationDeckResult;
    final valid = invalid != null && invalid.isEmpty;
    final ready = player?.ready ?? false;

    if (!isSelf && player == null) {
      return Container(
        key: const ValueKey('waiting-opponent-empty'),
        decoration: BoxDecoration(
          color: duelPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: duelLine),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 40,
              color: duelSub.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            const Text('等待对手加入…', style: HudTheme.caption),
            const SizedBox(height: 6),
            if (roomId != null)
              InkWell(
                onTap: () => onInvite(),
                child: Text(
                  '邀码 $roomId · 点击邀请好友',
                  style: HudTheme.caption.copyWith(
                    fontSize: 10,
                    color: duelCyan,
                  ),
                ),
              )
            else
              Text(
                '预计 10 秒内匹配',
                style: HudTheme.caption.copyWith(fontSize: 10, color: duelSub),
              ),
            const SizedBox(height: 2),
            Text(
              '空位 ${_others.length} / 1',
              style: HudTheme.caption.copyWith(fontSize: 9, color: duelFaint),
            ),
          ],
        ),
      );
    }

    return Container(
      key: ValueKey(isSelf ? 'waiting-self-card' : 'waiting-opponent-card'),
      decoration: BoxDecoration(
        color: duelPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: duelLine),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 844×390 设计画布下卡片高度只有 ~150，压缩头像与间距避免溢出。
          final compact = constraints.maxHeight < 210;
          final avatarSize = compact ? 30.0 : 46.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    isSelf ? '房主' : '对手',
                    style: HudTheme.caption.copyWith(
                      fontSize: 7.5,
                      color: isSelf ? duelCyan : duelSub,
                    ),
                  ),
                  const Spacer(),
                  if (roomId != null)
                    Text(
                      '房间号 #$roomId',
                      style: HudTheme.caption.copyWith(
                        fontSize: 7,
                        color: duelSub,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Container(height: 1, color: duelLine),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A1F2F), duelCyan],
                      ),
                      border: Border.all(
                        color: ready ? duelHeal : duelCyan,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (player != null && player.name.isNotEmpty)
                          ? player.name.characters.first
                          : '?',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: compact ? 15 : 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player?.name ?? (isSelf ? '我' : '对手'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HudTheme.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isSelf ? duelCyan : duelTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ready)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: duelHeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: duelHeal),
                      ),
                      child: Text(
                        '已准备',
                        style: HudTheme.caption.copyWith(
                          color: duelHeal,
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: compact ? 6 : 12),
              Container(height: 1, color: duelLine),
              SizedBox(height: compact ? 6 : 10),
              Row(
                children: [
                  Text('出战卡组', style: HudTheme.caption),
                  const Spacer(),
                  if (isSelf)
                    PopupMenuButton<String>(
                      key: const ValueKey('waiting-deck-change'),
                      tooltip: '切换卡组',
                      enabled: room.availableDecks.isNotEmpty,
                      color: duelPanel,
                      onSelected: (name) {
                        if (name == '__edit__') {
                          onEditDeck();
                          return;
                        }
                        ref.read(duelRoomProvider.notifier).selectDeck(name);
                      },
                      itemBuilder: (_) => [
                        for (final d in room.availableDecks)
                          PopupMenuItem(
                            value: d.deckName,
                            child: Text(d.deckName),
                          ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: '__edit__',
                          child: Text('编辑卡组…'),
                        ),
                      ],
                      child: Text(
                        '变更',
                        style: HudTheme.caption.copyWith(color: duelCyan),
                      ),
                    ),
                ],
              ),
              SizedBox(height: compact ? 2 : 6),
              Text(
                deck ?? '未选择卡组',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HudTheme.body.copyWith(fontSize: 12),
              ),
              Text(
                () {
                  final info = room.availableDecks
                      .where((d) => d.deckName == room.selectedDeckName)
                      .firstOrNull;
                  if (info == null) return '主 — · 额 — · 副 —';
                  return '主 ${info.mainCount} · 额 ${info.extraCount} · 副 ${info.sideCount}';
                }(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HudTheme.caption.copyWith(fontSize: 7, color: duelFaint),
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: invalid == null || invalid.isEmpty
                      ? null
                      : () => onShowDeckCheck(),
                  child: Row(
                    children: [
                      Icon(
                        valid ? Icons.verified : Icons.error_outline,
                        size: 13,
                        color: valid
                            ? duelHeal
                            : (invalid == null ? duelSub : duelDanger),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          invalid == null
                              ? '卡组未校验'
                              : (valid
                                    ? '卡组校验通过'
                                    : '卡组不合法 ${invalid.length} 项'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HudTheme.caption.copyWith(
                            fontSize: 10,
                            color: valid
                                ? duelHeal
                                : (invalid == null ? duelSub : duelDanger),
                          ),
                        ),
                      ),
                      if (invalid != null && invalid.isNotEmpty)
                        const Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: duelDanger,
                        ),
                    ],
                  ),
                ),
              ],
              if (compact) const SizedBox(height: 4) else const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: compact ? 2 : 4,
                ),
                decoration: BoxDecoration(
                  color: duelGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: duelGold.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'LP ${opts?.startLp ?? 8000}',
                  style: HudTheme.caption.copyWith(color: duelGold),
                ),
              ),
              if (isSelf || _others.length <= 1) ...[
                const SizedBox(height: 2),
                Text(
                  isSelf
                      ? (roomId == null ? '房间号 —' : '房间号 #$roomId')
                      : '空位 ${_others.length} / 1',
                  style: HudTheme.caption.copyWith(fontSize: 7, color: duelSub),
                ),
              ],
              if (!isSelf && !compact && _others.length > 1) ...[
                const SizedBox(height: 2),
                for (final p in _others.skip(1))
                  Padding(
                    padding: const EdgeInsets.only(top: 0),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.ready ? duelHeal : duelSub,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HudTheme.caption.copyWith(fontSize: 10),
                          ),
                        ),
                        Text(
                          p.ready ? '已准备' : '未准备',
                          style: HudTheme.caption.copyWith(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
