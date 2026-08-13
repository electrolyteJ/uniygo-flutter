import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:ygo_data/deck_info.dart';

import 'playerslot.dart';
import 'select_hand.dart';
import 'select_turn.dart';
import 'deck_selector.dart';

/// 玩家列表面板：纯 UI，房间状态与操作回调均由业务侧注入。
class PlayerPanel extends StatelessWidget {
  final int mySlot;
  final List<PlayerInfo> players;

  /// 是否展示猜拳结果（选拳/结果/选先攻阶段）。
  final bool showHandResults;

  /// 当前是否处于选拳/选先攻阶段。
  final bool isSelectingHand;
  final bool isSelectingTurn;

  final int? myHandResult;
  final int? opponentHandResult;
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

  /// 选拳/选先攻。
  final bool handSelectEnabled;
  final void Function(HandType) onSendHand;
  final bool turnSelectEnabled;
  final void Function(bool) onSendTp;

  final int observerCount;

  const PlayerPanel({
    super.key,
    required this.mySlot,
    required this.players,
    required this.showHandResults,
    required this.isSelectingHand,
    required this.isSelectingTurn,
    required this.myHandResult,
    required this.opponentHandResult,
    required this.isHost,
    required this.onKick,
    required this.deckSelectionEnabled,
    required this.decks,
    required this.selectedDeckName,
    required this.onSelectDeck,
    required this.onEditDeck,
    required this.deckInvalidationResult,
    required this.handSelectEnabled,
    required this.onSendHand,
    required this.turnSelectEnabled,
    required this.onSendTp,
    required this.observerCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey.shade800,
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
                handResult: item.pos == mySlot
                    ? myHandResult
                    : opponentHandResult,
                showResult: showHandResults,
                isHostSlot:
                    item.pos == mySlot ? isHost : (isHost ? false : true),
                isMe: item.pos == mySlot,
                canKick:
                    !(item.pos == mySlot
                        ? isHost
                        : (isHost ? false : true)) &&
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
          if (isSelectingHand)
            HandSelect(
              enabled: handSelectEnabled,
              onSendHand: onSendHand,
            ),
          if (isSelectingTurn)
            TpSelect(
              enabled: turnSelectEnabled,
              onSendTp: onSendTp,
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

