import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/SelectState.dart';
import '../../pages/duel_room/field/duel_selection_store.dart';
import 'select_menu.dart';
import 'battle_select_menu.dart';
import 'card_selector.dart';
import 'position_selector.dart';
import 'yes_no_dialog.dart';

class DuelOverlay extends StatelessWidget {
  const DuelOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final selectionState = context.watch<DuelSelectionStore>();
    final select = selectionState.currentSelect;
    if (select == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildSelectWidget(select, selectionState),
              ),
            ),
          ),
      ),
    );
  }

  Widget _buildSelectWidget(SelectState select, DuelSelectionStore selectionState) {
    switch (select.type) {
      case SelectType.idleCmd:
        return SelectMenu(
          actions: selectionState.selectedIdleActions,
          onSelect: (action) => selectionState.respondIdleCmd(action.sequence),
        );
      case SelectType.battleCmd:
        return BattleSelectMenu(
          actions: selectionState.selectedBattleActions,
          onSelect: (action) =>
              selectionState.respondBattleCmd(action.sequence),
        );
      case SelectType.card:
      case SelectType.tribute:
        return CardSelector(
          select: select,
          onSelect: (sequences) => selectionState.respondSelectCard(sequences),
          onCancel: () => selectionState.respondSelectCard([]),
        );
      case SelectType.chain:
        return CardSelector(
          select: select,
          onSelect: (sequences) => selectionState.respondSelectChain(
            sequences.isNotEmpty ? sequences.first : -1,
          ),
          onCancel: () => selectionState.respondSelectChain(-1),
        );
      case SelectType.position:
        return PositionSelector(
          select: select,
          onSelect: (position) =>
              selectionState.respondSelectPosition(position),
        );
      case SelectType.effectYn:
        return YesNoDialog(
          message: '是否发动效果？',
          onYes: () => selectionState.respondSelectEffectYn(true),
          onNo: () => selectionState.respondSelectEffectYn(false),
        );
      case SelectType.yesNo:
        return YesNoDialog(
          message: '是否执行？',
          onYes: () => selectionState.respondSelectYesNo(true),
          onNo: () => selectionState.respondSelectYesNo(false),
        );
      case SelectType.option:
        return CardSelector(
          select: select,
          onSelect: (sequences) => selectionState.respondSelectOption(
            sequences.isNotEmpty ? sequences.first : 0,
          ),
          onCancel: () => selectionState.respondSelectOption(0),
        );
      case SelectType.place:
        return CardSelector(
          select: select,
          onSelect: (sequences) => selectionState.respondSelectCard(sequences),
          onCancel: () => selectionState.respondSelectCard([]),
        );
      case SelectType.sum:
        return CardSelector(
          select: select,
          onSelect: (sequences) => selectionState.respondSelectSum(sequences),
          onCancel: () => selectionState.respondSelectSum([]),
        );
      case SelectType.counter:
        return CardSelector(
          select: select,
          onSelect: (sequences) =>
              selectionState.respondSelectCounter(sequences),
          onCancel: () => selectionState.respondSelectCounter([]),
        );
      case SelectType.sort:
        return CardSelector(
          select: select,
          onSelect: (sequences) => selectionState.respondSortCard(sequences),
          onCancel: () => selectionState.respondSortCard([]),
        );
    }
  }
}
