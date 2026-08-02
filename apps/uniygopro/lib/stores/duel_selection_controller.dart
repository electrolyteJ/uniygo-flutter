import 'package:duelink/duelink.dart';

import '../models/BattleAction.dart';
import '../models/IdleAction.dart';
import '../models/SelectState.dart';
import '../models/duel_selection_state.dart';

class DuelSelectionController {
  final DuelSelectionState selection;

  DuelSelectionController({required this.selection});

  void setSelect(SelectState select) {
    selection.currentSelect = select;
  }

  void clearSelect() {
    selection.currentSelect = null;
  }

  void applyIdleCmd(MsgSelectIdleCmd msg) {
    final actions = <IdleAction>[];
    for (final group in msg.commandGroups) {
      final type = group.type.index;
      for (final option in group.options) {
        actions.add(
          IdleAction(
            type: type,
            sequence: option.response,
            code: option.cardInfo.code,
            controller: option.cardInfo.controller,
            location: option.cardInfo.location,
            locationSequence: option.cardInfo.sequence,
            position: 0,
          ),
        );
      }
    }
    selection.selectedIdleActions = actions;
    selection.enableBp = msg.enableBp;
    selection.enableEp = msg.enableEp;
    selection.currentSelect = SelectState(
      type: SelectType.idleCmd,
      player: msg.player,
      min: 1,
      max: 1,
    );
  }

  void applyBattleCmd(MsgSelectBattleCmd msg) {
    final actions = <BattleAction>[];
    for (final group in msg.commandGroups) {
      final type = group.type.index;
      for (final option in group.options) {
        actions.add(
          BattleAction(
            type: type,
            sequence: option.response,
            attackerController: option.cardInfo.controller,
            attackerLocation: option.cardInfo.location,
            attackerSequence: option.cardInfo.sequence,
            attackerPosition: 0,
            directAttack: option.directAttackable,
          ),
        );
      }
    }
    selection.selectedBattleActions = actions;
    selection.enableM2 = msg.enableM2;
    selection.enableEp = msg.enableEp;
    selection.currentSelect = SelectState(
      type: SelectType.battleCmd,
      player: msg.player,
      min: 1,
      max: 1,
    );
  }

  void applySelectCard(MsgSelectCard msg) {
    final options = <SelectOption>[];
    for (int i = 0; i < msg.count; i++) {
      options.add(
        SelectOption(
          code: msg.codes[i],
          controller: msg.locations[i].controller,
          zone: msg.locations[i].location,
          sequence: msg.locations[i].sequence,
        ),
      );
    }
    selection.currentSelect = SelectState(
      type: SelectType.card,
      player: msg.player,
      options: options,
      min: msg.min,
      max: msg.max,
      cancelable: msg.cancelable != 0,
    );
  }

  void applySelectChain(MsgSelectChain msg) {
    final options = <SelectOption>[];
    for (final chain in msg.chains) {
      options.add(
        SelectOption(
          code: chain.code,
          controller: chain.location.controller,
          zone: chain.location.location,
          sequence: chain.location.sequence,
          label: '连锁${chain.effectDescription}',
        ),
      );
    }
    selection.currentSelect = SelectState(
      type: SelectType.chain,
      player: msg.player,
      options: options,
      min: msg.forced ? 1 : 0,
      max: 1,
      cancelable: !msg.forced,
    );
  }

  void applySelectEffectYn(MsgSelectEffectYn msg) {
    selection.currentSelect = SelectState(
      type: SelectType.effectYn,
      player: msg.player,
      options: [
        SelectOption(
          code: msg.code,
          controller: msg.location.controller,
          zone: msg.location.location,
          sequence: msg.location.sequence,
        ),
      ],
      min: 1,
      max: 1,
      effectDescription: msg.effectDescription,
    );
  }

  void applySelectYesNo(MsgSelectYesNo msg) {
    selection.currentSelect = SelectState(
      type: SelectType.yesNo,
      player: msg.player,
      min: 1,
      max: 1,
      effectDescription: msg.effectDescription,
    );
  }

  void applySelectPlace(MsgSelectPlace msg) {
    selection.currentSelect = SelectState(
      type: SelectType.place,
      player: msg.player,
      min: msg.count,
      max: msg.count,
      cancelable: false,
    );
  }

  void applySelectPosition(MsgSelectPosition msg) {
    final options = <SelectOption>[];
    for (final position in msg.availablePositions) {
      String label;
      switch (position) {
        case CardPosition.faceupAttack:
          label = '表侧攻击';
          break;
        case CardPosition.facedownAttack:
          label = '里侧攻击';
          break;
        case CardPosition.faceupDefense:
          label = '表侧守备';
          break;
        case CardPosition.facedownDefense:
          label = '里侧守备';
          break;
        default:
          label = position.name;
      }
      options.add(SelectOption(code: msg.code, position: position.value, label: label));
    }
    selection.currentSelect = SelectState(
      type: SelectType.position,
      player: msg.player,
      options: options,
      min: 1,
      max: 1,
    );
  }

  void applySelectTribute(MsgSelectTribute msg) {
    final options = <SelectOption>[];
    for (int i = 0; i < msg.count; i++) {
      options.add(
        SelectOption(
          code: msg.codes[i],
          controller: msg.locations[i].controller,
          zone: msg.locations[i].location,
          sequence: msg.locations[i].sequence,
          level: msg.levels[i],
        ),
      );
    }
    selection.currentSelect = SelectState(
      type: SelectType.tribute,
      player: msg.player,
      options: options,
      min: msg.min,
      max: msg.max,
      cancelable: msg.cancelable != 0,
    );
  }

  void applySelectCounter(MsgSelectCounter msg) {
    final options = <SelectOption>[];
    for (int i = 0; i < msg.count; i++) {
      options.add(
        SelectOption(
          code: msg.codes[i],
          controller: msg.locations[i].controller,
          zone: msg.locations[i].location,
          sequence: msg.locations[i].sequence,
          level: msg.counterCounts[i],
        ),
      );
    }
    selection.currentSelect = SelectState(
      type: SelectType.counter,
      player: msg.player,
      options: options,
      min: msg.min,
      max: msg.min,
    );
  }

  void applySelectSum(MsgSelectSum msg) {
    final options = <SelectOption>[];
    for (final card in [...msg.mustSelectCards, ...msg.selectableCards]) {
      options.add(
        SelectOption(
          code: card.code,
          controller: card.location.controller,
          zone: card.location.location,
          sequence: card.location.sequence,
          level: card.level1,
        ),
      );
    }
    selection.currentSelect = SelectState(
      type: SelectType.sum,
      player: msg.player,
      options: options,
      min: msg.min,
      max: msg.max,
    );
  }

  void applySortCard(MsgSortCard msg) {
    final options = <SelectOption>[];
    for (int i = 0; i < msg.count; i++) {
      options.add(
        SelectOption(
          code: msg.codes[i],
          controller: msg.locations[i].controller,
          zone: msg.locations[i].location,
          sequence: msg.locations[i].sequence,
        ),
      );
    }
    selection.currentSelect = SelectState(
      type: SelectType.sort,
      player: msg.player,
      options: options,
      min: msg.count,
      max: msg.count,
    );
  }

  void applySelectOption(MsgSelectOption msg) {
    selection.currentSelect = SelectState(
      type: SelectType.option,
      player: msg.player,
      options: msg.codes.map((code) => SelectOption(code: code)).toList(),
      min: 1,
      max: 1,
    );
  }

  void applySelectUnselectCard(MsgSelectUnselectCard msg) {
    final options = <SelectOption>[];
    for (final card in msg.selectableCards) {
      options.add(
        SelectOption(
          code: card.code,
          controller: card.location.controller,
          zone: card.location.location,
          sequence: card.location.sequence,
        ),
      );
    }
    selection.currentSelect = SelectState(
      type: SelectType.card,
      player: msg.player,
      options: options,
      min: msg.min,
      max: msg.max,
      cancelable: msg.cancelable,
    );
  }

  void applySelectDisfield(MsgSelectPlace msg) {
    final options = <SelectOption>[];
    for (int bit = 0; bit < 32; bit++) {
      if ((msg.field & (1 << bit)) == 0) continue;
      options.add(
        SelectOption(
          code: 0,
          controller: bit >= 16 ? 1 : 0,
          zone: bit < 8 || (bit >= 16 && bit < 24) ? CARD_ZONE_MZONE : CARD_ZONE_SZONE,
          sequence: bit % 8,
        ),
      );
    }
    selection.currentSelect = SelectState(
      type: SelectType.place,
      player: msg.player,
      options: options,
      min: msg.count,
      max: msg.count,
      cancelable: false,
    );
  }
}
