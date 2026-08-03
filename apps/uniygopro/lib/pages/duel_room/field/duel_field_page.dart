import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'duel_board_store.dart';
import 'duel_selection_store.dart';
import '../../../widgets/duel_room/chain_indicator.dart';
import '../../../widgets/duel_room/duel_overlay.dart';
import '../../../widgets/playmat/playmat.dart';
import '../../../widgets/shared/duel_room.dart';

class DuelFieldPage extends StatefulWidget {
  const DuelFieldPage({super.key});

  @override
  State<DuelFieldPage> createState() => _DuelFieldPageState();
}

class _DuelFieldPageState extends State<DuelFieldPage> {
  @override
  Widget build(BuildContext context) {
    final boardState = context.watch<DuelBoardStore>();
    final selectionState = context.watch<DuelSelectionStore>();

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
          Positioned(top: 8, left: 8, child: buildBackButton(context)),
        ],
      ),
    );
  }
}
