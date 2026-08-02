import 'package:flutter/foundation.dart';

import '../models/BattleAction.dart';
import '../models/IdleAction.dart';
import '../models/SelectState.dart';
import 'package:duelink/duelink.dart';

/// 对局选择态仓库。
///
/// 负责维护服务端下发的当前选择题、可执行行动，以及把 UI 的选择
/// 重新编码成对应的对局响应消息。
class DuelSelectionStore extends ChangeNotifier {
  List<IdleAction> selectedIdleActions = [];
  List<BattleAction> selectedBattleActions = [];
  bool enableBp = false;
  bool enableM2 = false;
  bool enableEp = false;
  SelectState? currentSelect;

  bool get isWaitingForInput => currentSelect != null;
  IDuelService? _duelService;

  /// 清空当前选择上下文，供离开房间或新对局开始时使用。
  void reset() {
    selectedIdleActions = [];
    selectedBattleActions = [];
    enableBp = false;
    enableM2 = false;
    enableEp = false;
    currentSelect = null;
    notifyListeners();
  }

  /// 供页面在批量字段赋值后显式触发刷新。
  void markChanged() {
    notifyListeners();
  }

  /// 记录当前等待玩家处理的选择请求。
  void setSelect(SelectState select) {
    currentSelect = select;
    notifyListeners();
  }

  /// 清除当前选择请求。
  void clearSelect() {
    currentSelect = null;
    notifyListeners();
  }

  void respondIdleCmd(int sequence) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectIdleCmd(sequence));
    clearSelect();
  }

  void respondBattleCmd(int sequence) {
    _duelService?.playGameResponse(
      CtosGameMsgResponse.selectBattleCmd(sequence),
    );
    clearSelect();
  }

  void respondSelectCard(List<int> sequences) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSelectChain(int sequence) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectSingle(sequence));
    clearSelect();
  }

  void respondSelectEffectYn(bool yes) {
    _duelService?.playGameResponse(
      CtosGameMsgResponse.selectEffectYn(yes ? 1 : 0),
    );
    clearSelect();
  }

  void respondSelectYesNo(bool yes) {
    _duelService?.playGameResponse(
      CtosGameMsgResponse.selectEffectYn(yes ? 1 : 0),
    );
    clearSelect();
  }

  void respondSelectPosition(int position) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectPosition(position));
    clearSelect();
  }

  void respondSelectOption(int sequence) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectOption(sequence));
    clearSelect();
  }

  void respondSelectPlace(int player, int zone, int sequence) {
    _duelService?.playGameResponse(
      CtosGameMsgResponse.selectPlace(
        CtosSelectPlace(player: player, zone: zone, sequence: sequence),
      ),
    );
    clearSelect();
  }

  void respondSelectTribute(List<int> sequences) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSelectCounter(List<int> values) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectCounter(values));
    clearSelect();
  }

  void respondSelectSum(List<int> sequences) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSortCard(List<int> indices) {
    _duelService?.playGameResponse(CtosGameMsgResponse.sortCard(indices));
    clearSelect();
  }

  /// 把手牌/场上可执行行动整理成 idle command 菜单。
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
    selectedIdleActions = actions;
    enableBp = msg.enableBp;
    enableEp = msg.enableEp;
    currentSelect = SelectState(
      type: SelectType.idleCmd,
      player: msg.player,
      min: 1,
      max: 1,
    );
  }

  /// 把战斗阶段可执行行动整理成 battle command 菜单。
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
    selectedBattleActions = actions;
    enableM2 = msg.enableM2;
    enableEp = msg.enableEp;
    currentSelect = SelectState(
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
    currentSelect = SelectState(
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
    currentSelect = SelectState(
      type: SelectType.chain,
      player: msg.player,
      options: options,
      min: msg.forced ? 1 : 0,
      max: 1,
      cancelable: !msg.forced,
    );
  }

  void applySelectEffectYn(MsgSelectEffectYn msg) {
    currentSelect = SelectState(
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
    currentSelect = SelectState(
      type: SelectType.yesNo,
      player: msg.player,
      min: 1,
      max: 1,
      effectDescription: msg.effectDescription,
    );
  }

  void applySelectPlace(MsgSelectPlace msg) {
    currentSelect = SelectState(
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
      options.add(
        SelectOption(code: msg.code, position: position.value, label: label),
      );
    }
    currentSelect = SelectState(
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
    currentSelect = SelectState(
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
    currentSelect = SelectState(
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
    currentSelect = SelectState(
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
    currentSelect = SelectState(
      type: SelectType.sort,
      player: msg.player,
      options: options,
      min: msg.count,
      max: msg.count,
    );
  }

  void applySelectOption(MsgSelectOption msg) {
    currentSelect = SelectState(
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
    currentSelect = SelectState(
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
          zone: bit < 8 || (bit >= 16 && bit < 24)
              ? CARD_ZONE_MZONE
              : CARD_ZONE_SZONE,
          sequence: bit % 8,
        ),
      );
    }
    currentSelect = SelectState(
      type: SelectType.place,
      player: msg.player,
      options: options,
      min: msg.count,
      max: msg.count,
      cancelable: false,
    );
  }

  void bind(IDuelService duelService) {
    _duelService = duelService;
  }
}
