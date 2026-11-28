/// 等待室玩家席位卡（设计稿 401:1 / 401:7 / 401:18 / 401:33）。
library;

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart' hide CardInfo, ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/hud_theme.dart';
import 'duel_style.dart';

class PlayerCard extends ConsumerWidget {
  const PlayerCard({
    super.key,
    required this.room,
    this.roomId,
    required this.seats,
    required this.isAlly,
    this.selfSlot,
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
  final List<PlayerInfo> seats;
  final bool isAlly;
  final int? selfSlot;

  PlayerInfo? get _primary {
    if (seats.isEmpty) return null;
    final mine = selfSlot;
    if (mine != null) {
      for (final p in seats) {
        if (p.pos == mine) return p;
      }
    }
    return seats.first;
  }

  PlayerInfo? get _teammate {
    final primary = _primary;
    if (primary == null) return null;
    for (final p in seats) {
      if (p.pos != primary.pos) return p;
    }
    return null;
  }

  bool get _isTag => room.roomOptions?.mode == RoomMode.tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = _primary;
    if (_isTag) {
      if (isAlly && selfSlot != null && primary != null) {
        return _selfTagCard(context, ref, primary);
      }
      return _teamTagCard(context);
    }
    if (isAlly && selfSlot != null && primary != null) {
      return _selfCard(context, ref, primary);
    }
    return _slotCard(context, primary);
  }

  TextStyle _cap(double size, Color color) =>
      HudTheme.caption.copyWith(fontSize: size, color: color, height: 1.1);

  TextStyle _body(double size, Color color) =>
      HudTheme.body.copyWith(fontSize: size, color: color, height: 1.1);

  Widget _frame(
    BuildContext context, {
    required Key cardKey,
    required double height,
    required Widget child,
  }) {
    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.topCenter,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: SizedBox(
          width: 190,
          height: height,
          child: Container(
            key: cardKey,
            decoration: BoxDecoration(
              color: const Color(0xFF070D16),
              border: Border.all(color: const Color(0xFF1E3247)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _avatar(double left, double top, String initial, double fontSize) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFF1E4A63),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initial.isEmpty ? '?' : initial,
          maxLines: 1,
          style: _body(fontSize, duelTextColor).copyWith(height: 1),
        ),
      ),
    );
  }

  List<Widget> _selfInfo(WidgetRef ref, PlayerInfo me) {
    final ready = me.ready;
    final deck = room.selectedDeckName;
    final deckInfo = room.availableDecks
        .where((d) => d.deckName == room.selectedDeckName)
        .firstOrNull;
    final invalid = room.invalidationDeckResult;
    final valid = invalid != null && invalid.isEmpty;
    final validation = invalid == null
        ? '卡组未校验'
        : (valid ? '禁限表校验通过' : '卡组不合法 ${invalid.length} 项');
    final validationColor = invalid == null
        ? duelFaint
        : (valid ? duelHeal : duelDanger);

    return [
      _avatar(12, 12, me.name.isNotEmpty ? me.name.characters.first : '?', 12),
      Positioned(
        left: 56,
        top: 17,
        width: 86,
        child: Text(
          me.name.isNotEmpty ? me.name : '我',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(9, duelTextColor),
        ),
      ),
      if (me.host)
        Positioned(
          left: 165,
          top: 17,
          child: Text('房主', style: _cap(6.5, duelGold)),
        ),
      Positioned(
        left: 147,
        top: 35,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ready ? duelHeal : duelFaint,
          ),
        ),
      ),
      Positioned(
        left: 157,
        top: 33,
        child: Text(
          ready ? '已准备' : '未准备',
          style: _cap(7, ready ? duelHeal : duelFaint),
        ),
      ),
      Positioned(
        left: 12,
        top: 56,
        child: Container(
          width: 24,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1E4A63),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      Positioned(
        left: 44,
        top: 56,
        width: 82,
        child: Text(
          deck ?? '未选择卡组',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(8.5, duelTextColor),
        ),
      ),
      Positioned(
        left: 44,
        top: 71,
        width: 82,
        child: Text(
          deckInfo == null
              ? '主 — · 额 — · 副 —'
              : '主 ${deckInfo.mainCount} · 额 ${deckInfo.extraCount} · 副 ${deckInfo.sideCount}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _cap(7, duelFaint),
        ),
      ),
      Positioned(
        left: 44,
        top: 84,
        width: 82,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: invalid == null || invalid.isEmpty ? null : onShowDeckCheck,
          child: Text(
            validation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _cap(7, validationColor),
          ),
        ),
      ),
      Positioned(
        left: 130,
        top: 66,
        child: PopupMenuButton<String>(
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
              PopupMenuItem(value: d.deckName, child: Text(d.deckName)),
            const PopupMenuDivider(),
            const PopupMenuItem(value: '__edit__', child: Text('编辑卡组…')),
          ],
          child: Container(
            width: 48,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: duelBtnLine),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text('更换', style: _cap(7, duelCyan)),
          ),
        ),
      ),
    ];
  }

  Widget _selfCard(BuildContext context, WidgetRef ref, PlayerInfo me) {
    return _frame(
      context,
      cardKey: const ValueKey('waiting-ally-card'),
      height: 106,
      child: Stack(children: _selfInfo(ref, me)),
    );
  }

  Widget _slotCard(BuildContext context, PlayerInfo? player) {
    return _frame(
      context,
      cardKey: ValueKey(isAlly ? 'waiting-ally-card' : 'waiting-enemy-card'),
      height: 60,
      child: Stack(
        children: [
          ..._slotRow(top: 12, player: player, emptyLabel: '等待加入…', index: 0),
          if (isAlly && selfSlot == null)
            Positioned(
              left: 56,
              top: 45,
              width: 128,
              child: Text(
                '你正在观战 · 点「转为决斗者」回到席位',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _cap(6, duelFaint),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selfTagCard(BuildContext context, WidgetRef ref, PlayerInfo me) {
    final teammate = _teammate;
    return _frame(
      context,
      cardKey: const ValueKey('waiting-ally-card'),
      height: 160,
      child: Stack(
        children: [
          ..._selfInfo(ref, me),
          Positioned(
            left: 14,
            top: 105,
            child: Container(width: 166, height: 1, color: duelLine),
          ),
          _avatar(
            12,
            112,
            teammate != null && teammate.name.isNotEmpty
                ? teammate.name.characters.first
                : '?',
            teammate != null ? 12 : 18,
          ),
          Positioned(
            left: 56,
            top: 117,
            width: 118,
            child: Text(
              teammate != null && teammate.name.isNotEmpty
                  ? teammate.name
                  : '等待队友加入…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(9, teammate != null ? duelTextColor : duelMuted),
            ),
          ),
          if (teammate != null)
            Positioned(
              left: 56,
              top: 133,
              child: Text(
                teammate.ready ? '已准备' : '未准备',
                style: _cap(7, teammate.ready ? duelHeal : duelFaint),
              ),
            )
          else
            Positioned(
              left: 56,
              top: 133,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: roomId == null ? null : onInvite,
                child: Text(
                  roomId == null ? '预计 10 秒内匹配' : '▦ 邀请好友 ›',
                  style: _cap(7, roomId == null ? duelFaint : duelCyan),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _teamTagCard(BuildContext context) {
    final first = seats.isNotEmpty ? seats[0] : null;
    final second = seats.length > 1 ? seats[1] : null;
    return _frame(
      context,
      cardKey: ValueKey(isAlly ? 'waiting-ally-card' : 'waiting-enemy-card'),
      height: 114,
      child: Stack(
        children: [
          ..._slotRow(
            top: 12,
            player: first,
            emptyLabel: isAlly ? '等待队友加入…' : '等待对手 1加入…',
            index: 0,
          ),
          Positioned(
            left: 12,
            top: 56,
            child: Container(width: 166, height: 1, color: duelLine),
          ),
          ..._slotRow(
            top: 66,
            player: second,
            emptyLabel: isAlly ? '等待队友加入…' : '等待对手 2加入…',
            index: 1,
          ),
        ],
      ),
    );
  }

  List<Widget> _slotRow({
    required double top,
    required PlayerInfo? player,
    required String emptyLabel,
    required int index,
  }) {
    final name = player != null && player.name.isNotEmpty
        ? player.name
        : emptyLabel;
    final status = player == null
        ? '预计 10 秒内匹配'
        : (player.ready ? '已准备' : '未准备');
    final statusColor = player == null
        ? duelFaint
        : (player.ready ? duelHeal : duelMuted);
    return [
      _avatar(
        12,
        top,
        player != null && player.name.isNotEmpty
            ? player.name.characters.first
            : '?',
        player != null ? 12 : 18,
      ),
      Positioned(
        left: 56,
        top: top + 5,
        width: 118,
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(9, duelTextColor),
        ),
      ),
      Positioned(
        left: 56,
        top: top + 21,
        width: 118,
        child: Text(status, style: _cap(7, statusColor)),
      ),
    ];
  }
}
