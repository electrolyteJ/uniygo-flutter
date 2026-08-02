import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uniygopro/stores/waiting_room_store.dart';

import '../stores/duel_board_store.dart';
import '../stores/duel_chat_store.dart';
import '../stores/duel_selection_store.dart';
import '../stores/duel_ui_store.dart';
import '../stores/duel_room_state.dart';
import '../stores/match_store.dart';
import '../widgets/duel_room/chain_indicator.dart';
import '../widgets/duel_room/duel_overlay.dart';
import '../widgets/playmat/playmat.dart';

class DuelFieldPage extends StatefulWidget {
  const DuelFieldPage({super.key});

  @override
  State<DuelFieldPage> createState() => _DuelFieldPageState();
}

class _DuelFieldPageState extends State<DuelFieldPage> {
  late final DuelRoomState controller;
  late final WaitingRoomStore waitingRoomStore;
  late final DuelBoardStore boardState;
  late final DuelSelectionStore selectionState;
  late final DuelChatStore chatState;
  late final DuelUiStore uiState;
  late final MatchStore matchRoomStore;

  @override
  void initState() {
    super.initState();
    controller = context.read<DuelRoomState>();
    waitingRoomStore = context.read<WaitingRoomStore>();
    boardState = context.read<DuelBoardStore>();
    selectionState = context.read<DuelSelectionStore>();
    chatState = context.read<DuelChatStore>();
    uiState = context.read<DuelUiStore>();
    matchRoomStore = context.read<MatchStore>();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Playmat(),
          if (selectionState.isWaitingForInput) DuelOverlay(),
          if (boardState.chains.isNotEmpty)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: ChainIndicator(chainCount: boardState.chains.length),
              ),
            ),
          Positioned(top: 8, left: 8, child: _buildBackButton(context)),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _confirmBack(context),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  void _confirmBack(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出决斗'),
        content: const Text('确定要退出当前决斗吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              controller.reset();
              waitingRoomStore.reset();
              boardState.reset();
              selectionState.reset();
              chatState.reset();
              uiState.reset();
              matchRoomStore.reset();
              Navigator.of(ctx).pop();
              context.go('/');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
