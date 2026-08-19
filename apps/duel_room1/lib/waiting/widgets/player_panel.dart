import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:ygo_data/deck_info.dart';

import 'playerslot.dart';
import 'deck_selector.dart';

/// 玩家列表面板：纯 UI，房间状态与操作回调均由业务侧注入。
///
/// 猜拳/选先攻不在这里：它们由 DuelRoomPage 直接挂载的
/// HandSelectPanel/TurnSelectPanel 承担（含结果展示）。
class PlayerPanel extends StatelessWidget {
  final int mySlot;
  final List<PlayerInfo> players;

  final bool isHost;
  final ValueChanged<int> onKick;

  /// 卡组选择。
  final bool deckSelectionEnabled;
  final List<DeckInfo> decks;
  final String? selectedDeckName;
  final ValueChanged<String?> onSelectDeck;

  /// 编辑所选卡组（导航逻辑由业务侧处理）；无可编辑卡组时为 null。
  final VoidCallback? onEditDeck;
  final List<String>? deckInvalidationResult;

  final int observerCount;

  const PlayerPanel({
    super.key,
    required this.mySlot,
    required this.players,
    required this.isHost,
    required this.onKick,
    required this.deckSelectionEnabled,
    required this.decks,
    required this.selectedDeckName,
    required this.onSelectDeck,
    required this.onEditDeck,
    required this.deckInvalidationResult,
    required this.observerCount,
  });

  @override
  Widget build(BuildContext context) {
    // 不设底色：等待室已改为半透明弹窗，面板背景由弹窗容器提供。
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '玩家',
            style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
          ),
          ...players.map(
            (item) => Container(
              margin: const EdgeInsets.only(top: 8),
              child: PlayerSlot(
                player: item,
                placeholder: '玩家 ${item.pos + 1}',
                isHostSlot: item.pos == mySlot
                    ? isHost
                    : (isHost ? false : true),
                isMe: item.pos == mySlot,
                canKick:
                    !(item.pos == mySlot ? isHost : (isHost ? false : true)) &&
                    item.pos != mySlot,
                onKick: () => onKick(item.pos),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DeckSelector(
            enabled: deckSelectionEnabled,
            decks: decks,
            selectedDeckName: selectedDeckName,
            mySlot: mySlot,
            onSelectDeck: onSelectDeck,
            onEditDeck: onEditDeck,
            invalidationResult: deckInvalidationResult,
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.blueGrey.shade600, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.visibility, size: 16, color: Colors.blueGrey.shade400),
              const SizedBox(width: 6),
              Text(
                '观战: $observerCount人',
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
