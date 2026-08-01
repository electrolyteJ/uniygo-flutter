import 'package:flutter/material.dart';
import '../../stores/duel_room_state.dart';
import 'select_menu.dart';
import 'battle_select_menu.dart';
import 'card_selector.dart';
import 'position_selector.dart';
import 'yes_no_dialog.dart';

class DuelOverlay extends StatelessWidget {
  final DuelRoomState state;
  const DuelOverlay({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final select = state.currentSelect;
    if (select == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.65),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSelectWidget(select),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectWidget(SelectState select) {
    switch (select.type) {
      case SelectType.idleCmd:
        return SelectMenu(
          actions: state.selectedIdleActions,
          onSelect: (action) => state.respondIdleCmd(action.sequence),
        );
      case SelectType.battleCmd:
        return BattleSelectMenu(
          actions: state.selectedBattleActions,
          onSelect: (action) => state.respondBattleCmd(action.sequence),
        );
      case SelectType.card:
      case SelectType.tribute:
        return CardSelector(
          select: select,
          onSelect: (sequences) => state.respondSelectCard(sequences),
          onCancel: () => state.respondSelectCard([]),
        );
      case SelectType.chain:
        return CardSelector(
          select: select,
          onSelect: (sequences) => state.respondSelectChain(sequences.isNotEmpty ? sequences.first : -1),
          onCancel: () => state.respondSelectChain(-1),
        );
      case SelectType.position:
        return PositionSelector(
          select: select,
          onSelect: (position) => state.respondSelectPosition(position),
        );
      case SelectType.effectYn:
        return YesNoDialog(
          message: '是否发动效果？',
          onYes: () => state.respondSelectEffectYn(true),
          onNo: () => state.respondSelectEffectYn(false),
        );
      case SelectType.yesNo:
        return YesNoDialog(
          message: '是否执行？',
          onYes: () => state.respondSelectYesNo(true),
          onNo: () => state.respondSelectYesNo(false),
        );
      case SelectType.option:
        return CardSelector(
          select: select,
          onSelect: (sequences) => state.respondSelectOption(sequences.isNotEmpty ? sequences.first : 0),
          onCancel: () => state.respondSelectOption(0),
        );
      case SelectType.place:
        return CardSelector(
          select: select,
          onSelect: (sequences) => state.respondSelectCard(sequences),
          onCancel: () => state.respondSelectCard([]),
        );
      case SelectType.sum:
        return CardSelector(
          select: select,
          onSelect: (sequences) => state.respondSelectSum(sequences),
          onCancel: () => state.respondSelectSum([]),
        );
      case SelectType.counter:
        return CardSelector(
          select: select,
          onSelect: (sequences) => state.respondSelectCounter(sequences),
          onCancel: () => state.respondSelectCounter([]),
        );
      case SelectType.sort:
        return CardSelector(
          select: select,
          onSelect: (sequences) => state.respondSortCard(sequences),
          onCancel: () => state.respondSortCard([]),
        );
    }
  }
}
