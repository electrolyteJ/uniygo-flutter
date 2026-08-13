import 'dart:async';
import 'dart:developer' as console;

import 'package:biz/card_image_loader.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ygo_data/card_info.dart' as pkg;

import '../../providers/service_providers.dart';
import '../../models/battle_action.dart';
import '../../models/field_card.dart';
import '../../models/field_zone_key.dart';
import '../../models/idle_action.dart';
import '../../models/select_state.dart';
import 'duel_field_state.dart';

const Object _undefined = Object();

/// 支持就地选择的类型。排序/计数器/效果选项等交互复杂或没有
/// 场上位置，仍走 CardSelector 弹窗。
const _inlineSelectTypes = {
  SelectType.chain,
  SelectType.card,
  SelectType.tribute,
  SelectType.unselect,
  SelectType.sum,
};

/// 选择窗口状态：服务端下发、等待玩家作答、必须回包的选择题，不可变快照。
///
/// 「必须回包」是与确认展示（CardConfirmState，只展示不回包）的
/// 本质区别：这里每个窗口都阻塞对局，直到玩家作答或取消。
///
/// 字段全部只读，变更通过 [copyWith] 生成新快照；
/// MSG_SELECT_* 消息应用与 respond* 编码逻辑收敛在 [SelectWindowNotifier]。
class SelectWindowState {
  const SelectWindowState({
    this.selectedIdleActions = const [],
    this.selectedBattleActions = const [],
    this.enableBp = false,
    this.enableM2 = false,
    this.enableEp = false,
    this.currentSelect,
    this.inlineSelectedOptionIndices = const {},
    this.announceCardBlockedCodes = const [],
  });

  final List<IdleAction> selectedIdleActions;
  final List<BattleAction> selectedBattleActions;
  final bool enableBp;
  final bool enableM2;
  final bool enableEp;
  final SelectState? currentSelect;

  /// 就地选择（高亮手牌/场上卡代替 CardSelector 弹窗）时已勾选的选项下标。
  final Set<int> inlineSelectedOptionIndices;

  final List<int> announceCardBlockedCodes;

  SelectWindowState copyWith({
    List<IdleAction>? selectedIdleActions,
    List<BattleAction>? selectedBattleActions,
    bool? enableBp,
    bool? enableM2,
    bool? enableEp,
    Object? currentSelect = _undefined,
    Set<int>? inlineSelectedOptionIndices,
    List<int>? announceCardBlockedCodes,
  }) {
    return SelectWindowState(
      selectedIdleActions: selectedIdleActions ?? this.selectedIdleActions,
      selectedBattleActions:
          selectedBattleActions ?? this.selectedBattleActions,
      enableBp: enableBp ?? this.enableBp,
      enableM2: enableM2 ?? this.enableM2,
      enableEp: enableEp ?? this.enableEp,
      currentSelect: identical(currentSelect, _undefined)
          ? this.currentSelect
          : currentSelect as SelectState?,
      inlineSelectedOptionIndices:
          inlineSelectedOptionIndices ?? this.inlineSelectedOptionIndices,
      announceCardBlockedCodes:
          announceCardBlockedCodes ?? this.announceCardBlockedCodes,
    );
  }

  // ──────────────────────────────────────────
  // 纯派生读取（不依赖战场状态）
  // ──────────────────────────────────────────

  bool get isWaitingForInput => currentSelect != null;
  bool get hasIdleCommandWindow => currentSelect?.type == SelectType.idleCmd;
  bool get hasBattleCommandWindow =>
      currentSelect?.type == SelectType.battleCmd;
  bool get hasPhaseCommandWindow =>
      hasIdleCommandWindow || hasBattleCommandWindow;

  bool ownsCurrentWindow(int player) => currentSelect?.player == player;
  bool canOpenPhaseMenuFor(int player) =>
      ownsCurrentWindow(player) && hasPhaseCommandWindow;

  int get inlineSelectedCount => inlineSelectedOptionIndices.length;

  bool get inlineSelectCanConfirm {
    final select = currentSelect;
    return select != null &&
        inlineSelectedOptionIndices.length >= select.min;
  }

  /// 当前为放置选择（MSG_SELECT_PLACE）时的可放置槽位 key 集合，
  /// 供场地组件直接高亮对应槽位。
  Set<String> get placeTargetFieldKeys {
    final select = currentSelect;
    if (select?.type != SelectType.place) return const {};
    return {
      for (final option in select!.options)
        if (option.zone == CARD_ZONE_MZONE || option.zone == CARD_ZONE_SZONE)
          zoneKeyOf(option.controller, option.zone, option.sequence),
    };
  }

  /// 就地选择的提示文案。
  String get inlineSelectHint {
    final select = currentSelect!;
    final count = inlineSelectedOptionIndices.length;
    switch (select.type) {
      case SelectType.chain:
        return '选择要连锁的卡';
      case SelectType.tribute:
        return select.max == 1
            ? '请选择解放的怪兽'
            : '选择解放的怪兽 ($count/${select.max})';
      case SelectType.unselect:
        return '已选择 $count 张卡，点卡切换，满足条件后完成';
      case SelectType.sum:
        return '按等级合计选择卡 ($count/${select.max})';
      default:
        return select.max == 1
            ? '请选择 1 张卡'
            : '选择 ${select.min}-${select.max} 张卡 ($count/${select.max})';
    }
  }
}

/// 选择窗口的 Notifier：持有全部 MSG_SELECT_* / MSG_SORT_CARD /
/// MSG_ANNOUNCE_CARD 的消息应用逻辑，以及 respond* 回包编码。
class SelectWindowNotifier extends Notifier<SelectWindowState> {
  late YgoDataService _dataService;
  IDuelService? _duelService;

  @override
  SelectWindowState build() {
    _dataService = ref.watch(dataServiceProvider);
    return const SelectWindowState();
  }

  /// 读取战场状态（myController / fieldCards / 战斗演出清理）。
  DuelFieldState get _board => ref.read(duelFieldProvider);

  void bind(IDuelService duelService) {
    _duelService = duelService;
  }

  /// 清空选择窗口状态（对局事实之外的作答态）。
  void reset() {
    state = const SelectWindowState();
  }

  // ──────────────────────────────────────────
  // 选择响应
  // ──────────────────────────────────────────

  /// 记录当前等待玩家处理的选择请求，同时预热所有选项的卡图缓存。
  void setSelect(SelectState select) {
    state = state.copyWith(currentSelect: select);
    _preloadSelectImages(select);
  }

  /// 预热 CardSelector 中所有卡片图片到 [CardImageLoader] 全局缓存。
  void _preloadSelectImages(SelectState select) {
    for (final opt in select.options) {
      if (opt.code > 0) CardImageLoader.I.load(opt.code);
    }
  }

  /// 清除当前选择请求。
  void clearSelect() {
    state = state.copyWith(
      currentSelect: null,
      inlineSelectedOptionIndices: const {},
      announceCardBlockedCodes: const [],
    );
  }

  void _sendResponse(CtosGameMsgResponse response) {
    _duelService?.playGameResponse(response);
  }

  void respondIdleCmd(int sequence) {
    _sendResponse(CtosGameMsgResponse.selectIdleCmd(sequence));
    clearSelect();
  }

  void respondBattleCmd(int sequence) {
    _sendResponse(CtosGameMsgResponse.selectBattleCmd(sequence));
    clearSelect();
  }

  bool respondCurrentCommand(int sequence) {
    if (state.hasIdleCommandWindow) {
      respondIdleCmd(sequence);
      return true;
    }
    if (state.hasBattleCommandWindow) {
      respondBattleCmd(sequence);
      return true;
    }
    return false;
  }

  void respondSelectCard(List<int> sequences) {
    final select = state.currentSelect;
    if (select?.type == SelectType.card || select?.type == SelectType.tribute) {
      final summary = sequences
          .map((index) {
            if (select == null || index < 0 || index >= select.options.length) {
              return '#$index';
            }
            final option = select.options[index];
            return '#$index code=${option.code} c=${option.controller} z=${option.zone} s=${option.sequence}';
          })
          .join(', ');
      console.log('respondSelectCard: [$summary]');
    }
    _sendResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSelectChain(int sequence) {
    _sendResponse(CtosGameMsgResponse.selectSingle(sequence));
    clearSelect();
  }

  void respondSelectEffectYn(bool yes) {
    _sendResponse(CtosGameMsgResponse.selectEffectYn(yes ? 1 : 0));
    clearSelect();
  }

  void respondSelectYesNo(bool yes) {
    _sendResponse(CtosGameMsgResponse.selectEffectYn(yes ? 1 : 0));
    clearSelect();
  }

  void respondSelectPosition(int position) {
    _sendResponse(CtosGameMsgResponse.selectPosition(position));
    clearSelect();
  }

  void respondSelectOption(int sequence) {
    _sendResponse(CtosGameMsgResponse.selectOption(sequence));
    clearSelect();
  }

  void respondSelectPlace(int player, int zone, int sequence) {
    _sendResponse(
      CtosGameMsgResponse.selectPlace(
        CtosSelectPlace(player: player, zone: zone, sequence: sequence),
      ),
    );
    clearSelect();
  }

  void respondSelectTribute(List<int> sequences) {
    _sendResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSelectUnselectCard(int? sequence) {
    console.log(
      sequence == null
          ? 'respondSelectUnselectCard: finish/cancel'
          : 'respondSelectUnselectCard: toggle #$sequence',
    );
    if (sequence == null) {
      _sendResponse(CtosGameMsgResponse.selectSingle(-1));
    } else {
      _sendResponse(CtosGameMsgResponse.selectMulti([sequence]));
    }
    clearSelect();
  }

  void respondSelectCounter(List<int> values) {
    _sendResponse(CtosGameMsgResponse.selectCounter(values));
    clearSelect();
  }

  void respondSelectSum(List<int> sequences) {
    _sendResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSortCard(List<int> indices) {
    _sendResponse(CtosGameMsgResponse.sortCard(indices));
    clearSelect();
  }

  void respondAnnounceCard(int code) {
    console.log('respondAnnounceCard: code=$code');
    _sendResponse(CtosGameMsgResponse.selectOption(code));
    clearSelect();
  }

  Future<List<pkg.CardInfo>> searchAnnounceCards(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return const <pkg.CardInfo>[];
    }
    final blockedCodes = state.announceCardBlockedCodes.toSet();
    final results = await _dataService.searchCards(trimmed);
    return results
        .where(
          (card) =>
              !blockedCodes.contains(card.code) &&
              card.name.trim().isNotEmpty &&
              card.alias != card.code,
        )
        .take(50)
        .toList(growable: false);
  }

  // ──────────────────────────────────────────
  // 选择消息应用
  // ──────────────────────────────────────────

  /// 把手牌/场上可执行行动整理成 idle command 菜单。
  void applyIdleCmd(MsgSelectIdleCmd msg) {
    // 进入新的选择阶段时清除残留的动效（如攻击动画被反射镜力中断，怪兽破坏后无 MSG_BATTLE 结算）
    ref
        .read(duelFieldProvider.notifier)
        .scheduleBattlePresentationClear();
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
    final activateDebug = actions
        .where((action) => action.type == 5)
        .map(
          (action) =>
              '#${action.sequence} code=${action.code} c=${action.controller} z=${action.location} s=${action.locationSequence}',
        )
        .join(', ');
    console.log(
      'applyIdleCmd: player=${msg.player} summon=${msg.commandGroups[0].options.length} '
      'spSummon=${msg.commandGroups[1].options.length} pos=${msg.commandGroups[2].options.length} '
      'mset=${msg.commandGroups[3].options.length} sset=${msg.commandGroups[4].options.length} '
      'activate=${msg.commandGroups[5].options.length} activateActions=[$activateDebug]',
    );
    state = state.copyWith(
      selectedIdleActions: actions,
      enableBp: msg.enableBp,
      enableEp: msg.enableEp,
      currentSelect: SelectState(
        type: SelectType.idleCmd,
        player: msg.player,
        min: 1,
        max: 1,
      ),
    );
  }

  /// 把战斗阶段可执行行动整理成 battle command 菜单。
  void applyBattleCmd(MsgSelectBattleCmd msg) {
    // 进入新的战斗指令选择时，若前一击未进入伤害计算（如怪兽在伤害计算前被效果破坏，
    // 无 MSG_BATTLE 结算），则清除残留的攻击动效。
    ref
        .read(duelFieldProvider.notifier)
        .scheduleBattlePresentationClear();
    final actions = <BattleAction>[];
    for (final group in msg.commandGroups) {
      final type = group.type.index;
      for (final option in group.options) {
        actions.add(
          BattleAction(
            type: type,
            sequence: option.response,
            code: option.cardInfo.code,
            attackerController: option.cardInfo.controller,
            attackerLocation: option.cardInfo.location,
            attackerSequence: option.cardInfo.sequence,
            attackerPosition: 0,
            directAttack: option.directAttackable,
          ),
        );
      }
    }
    state = state.copyWith(
      selectedBattleActions: actions,
      enableM2: msg.enableM2,
      enableEp: msg.enableEp,
      currentSelect: SelectState(
        type: SelectType.battleCmd,
        player: msg.player,
        min: 1,
        max: 1,
      ),
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
    console.log(
      'applySelectCard: min=${msg.min} max=${msg.max} count=${msg.count} options='
      '${List.generate(msg.count, (i) => "#$i code=${msg.codes[i]} c=${msg.locations[i].controller} z=${msg.locations[i].location} s=${msg.locations[i].sequence}")}',
    );
    state = state.copyWith(
      currentSelect: SelectState(
        type: SelectType.card,
        player: msg.player,
        options: options,
        min: msg.min,
        max: msg.max,
        cancelable: msg.cancelable != 0,
      ),
    );
  }

  void applySelectChain(MsgSelectChain msg) {
    // 官方客户端在无可连锁卡、非强制且非时点提示时直接回传 -1 放弃连锁，
    // 避免弹出空选择器阻塞对局。
    final isEmptyWindow =
        msg.chains.isEmpty && !msg.forced && msg.specialCount != 0x7f;
    if (isEmptyWindow) {
      console.log('applySelectChain: 无可连锁卡，自动放弃连锁');
      respondSelectChain(-1);
      return;
    }
    final options = <SelectOption>[];
    console.log('applySelectChain: ${msg.chains} options');
    for (final chain in msg.chains) {
      options.add(
        SelectOption(
          code: chain.code,
          controller: chain.location.controller,
          zone: chain.location.location,
          // 就地高亮需要真实场上/手牌位置；连锁响应值与选项下标一致，
          // 提交时仍按下标回传。
          sequence: chain.location.sequence,
          label: '连锁${chain.effectDescription}',
        ),
      );
    }
    state = state.copyWith(
      currentSelect: SelectState(
        type: SelectType.chain,
        player: msg.player,
        options: options,
        min: msg.forced ? 1 : 0,
        max: 1,
        cancelable: !msg.forced,
      ),
    );
  }

  void applySelectEffectYn(MsgSelectEffectYn msg) {
    state = state.copyWith(
      currentSelect: SelectState(
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
      ),
    );
  }

  void applySelectYesNo(MsgSelectYesNo msg) {
    state = state.copyWith(
      currentSelect: SelectState(
        type: SelectType.yesNo,
        player: msg.player,
        min: 1,
        max: 1,
        effectDescription: msg.effectDescription,
      ),
    );
  }

  void applySelectPlace(MsgSelectPlace msg) {
    state = state.copyWith(
      currentSelect: SelectState(
        type: SelectType.place,
        player: msg.player,
        options: _placeOptionsFromFieldMask(
          msg.field,
          selectingPlayer: msg.player,
          selectableWhenBitSet: false,
        ),
        min: msg.count,
        max: msg.count,
        cancelable: false,
      ),
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
    state = state.copyWith(
      currentSelect: SelectState(
        type: SelectType.position,
        player: msg.player,
        options: options,
        min: 1,
        max: 1,
      ),
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
    state = state.copyWith(
      currentSelect: SelectState(
        type: SelectType.tribute,
        player: msg.player,
        options: options,
        min: msg.min,
        max: msg.max,
        cancelable: msg.cancelable != 0,
      ),
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
    state = state.copyWith(
      currentSelect: SelectState(
        type: SelectType.counter,
        player: msg.player,
        options: options,
        min: msg.min,
        max: msg.min,
      ),
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
    state = state.copyWith(
      currentSelect: SelectState(
        type: SelectType.sum,
        player: msg.player,
        options: options,
        min: msg.min,
        max: msg.max,
      ),
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
    state = state.copyWith(
      currentSelect: SelectState(
        type: SelectType.sort,
        player: msg.player,
        options: options,
        min: msg.count,
        max: msg.count,
      ),
    );
  }

  void applySelectOption(MsgSelectOption msg) {
    state = state.copyWith(
      currentSelect: SelectState(
        type: SelectType.option,
        player: msg.player,
        options: [
          for (var index = 0; index < msg.codes.length; index++)
            SelectOption(
              code: cardCodeFromDescriptionValue(msg.codes[index]) ?? 0,
              sequence: index,
              label: '选项 ${index + 1}',
            ),
        ],
        min: 1,
        max: 1,
      ),
    );
  }

  void applyAnnounceCard(MsgAnnounceCard msg) {
    state = state.copyWith(
      announceCardBlockedCodes: [...msg.codes],
      currentSelect: SelectState(
        type: SelectType.announceCard,
        player: msg.player,
        min: 1,
        max: 1,
      ),
    );
    console.log(
      'applyAnnounceCard: player=${msg.player} blocked=${msg.count} codes=[${msg.codes.join(', ')}]',
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
    final initiallySelected = <int>[];
    final selectableCount = options.length;
    for (int i = 0; i < msg.selectedCards.length; i++) {
      final card = msg.selectedCards[i];
      options.add(
        SelectOption(
          code: card.code,
          controller: card.location.controller,
          zone: card.location.location,
          sequence: card.location.sequence,
        ),
      );
      initiallySelected.add(selectableCount + i);
    }
    console.log(
      'applySelectUnselectCard: min=${msg.min} max=${msg.max} '
      'selectable=${msg.selectableCards.length} selected=${msg.selectedCards.length} '
      'finishable=${msg.finishable} cancelable=${msg.cancelable}',
    );
    state = state.copyWith(
      currentSelect: SelectState(
        type: SelectType.unselect,
        player: msg.player,
        options: options,
        min: msg.min,
        max: msg.max,
        cancelable: msg.cancelable,
        finishable: msg.finishable,
        immediateSingleToggle: true,
        initialSelectedIndices: initiallySelected,
      ),
      // 就地选择模式下同步已勾选项，保证高亮与「完成」门槛一致。
      inlineSelectedOptionIndices: {...initiallySelected},
    );
  }

  void applySelectDisfield(MsgSelectPlace msg) {
    state = state.copyWith(
      currentSelect: SelectState(
        type: SelectType.place,
        player: msg.player,
        options: _placeOptionsFromFieldMask(
          msg.field,
          selectingPlayer: msg.player,
          selectableWhenBitSet: true,
        ),
        min: msg.count,
        max: msg.count,
        cancelable: false,
      ),
    );
  }

  List<SelectOption> _placeOptionsFromFieldMask(
    int field, {
    required int selectingPlayer,
    required bool selectableWhenBitSet,
  }) {
    final options = <SelectOption>[];
    for (int bit = 0; bit < 32; bit++) {
      final bitSet = (field & (1 << bit)) != 0;
      if (selectableWhenBitSet ? !bitSet : bitSet) {
        continue;
      }
      final decoded = _decodePlaceBit(bit, selectingPlayer: selectingPlayer);
      if (decoded == null) continue;
      options.add(
        SelectOption(
          code: 0,
          controller: decoded.controller,
          zone: decoded.zone,
          sequence: decoded.sequence,
          label: _placeOptionLabel(
            selectingPlayer: selectingPlayer,
            controller: decoded.controller,
            zone: decoded.zone,
            sequence: decoded.sequence,
          ),
        ),
      );
    }
    return options;
  }

  ({int controller, int zone, int sequence})? _decodePlaceBit(
    int bit, {
    required int selectingPlayer,
  }) {
    final opponent = 1 - selectingPlayer;
    if (bit < 8) {
      return (
        controller: selectingPlayer,
        zone: CARD_ZONE_MZONE,
        sequence: bit,
      );
    }
    if (bit < 16) {
      return (
        controller: selectingPlayer,
        zone: CARD_ZONE_SZONE,
        sequence: bit - 8,
      );
    }
    if (bit < 24) {
      return (controller: opponent, zone: CARD_ZONE_MZONE, sequence: bit - 16);
    }
    if (bit < 32) {
      return (controller: opponent, zone: CARD_ZONE_SZONE, sequence: bit - 24);
    }
    return null;
  }

  String _placeOptionLabel({
    required int selectingPlayer,
    required int controller,
    required int zone,
    required int sequence,
  }) {
    final prefix = controller == selectingPlayer ? '我方' : '对方';
    if (zone == CARD_ZONE_MZONE) {
      if (sequence <= 4) {
        return '$prefix 怪兽区 ${sequence + 1}';
      }
      if (sequence == 5) {
        return '$prefix 额外怪兽区 1';
      }
      if (sequence == 6) {
        return '$prefix 额外怪兽区 2';
      }
      return '$prefix 怪兽区 ${sequence + 1}';
    }
    if (zone == CARD_ZONE_SZONE) {
      if (sequence <= 4) {
        return '$prefix 魔陷区 ${sequence + 1}';
      }
      if (sequence == 5) {
        return '$prefix 场地区';
      }
      return '$prefix 魔陷区 ${sequence + 1}';
    }
    return '$prefix 区域 ${sequence + 1}';
  }

  // ──────────────────────────────────────────
  // 就地选择（高亮手牌/场上卡代替 CardSelector 弹窗）
  //
  // 依赖战场状态（myController / fieldCards）的派生读取放在 Notifier 上。
  // ──────────────────────────────────────────

  /// 当前选择是否可以就地进行：类型受支持，且所有选项都落在
  /// 己方手牌或双方场上（怪兽/魔陷区）的可见位置。
  /// 任一选项落在卡组/墓地/除外/对方手牌等不可直接点击的区域时，
  /// 整体回退到弹窗选择。
  bool get inlineSelectActive {
    final select = state.currentSelect;
    if (select == null ||
        !_inlineSelectTypes.contains(select.type) ||
        select.options.isEmpty) {
      return false;
    }
    return select.options.every(_isInlineVisibleOption);
  }

  bool _isInlineVisibleOption(SelectOption option) {
    if (option.zone == CARD_ZONE_HAND) {
      return option.controller == _board.myController;
    }
    if (option.zone == CARD_ZONE_MZONE || option.zone == CARD_ZONE_SZONE) {
      return _board.fieldCards.containsKey(
        zoneKeyOf(option.controller, option.zone, option.sequence),
      );
    }
    // 卡组、墓地、额外、除外等区域不可直接点击，应通过弹窗选择
    return false;
  }

  /// 就地选择中可点击的己方手牌下标。
  Set<int> get inlineSelectableHandSequences {
    if (!inlineSelectActive) return const {};
    return {
      for (final option in state.currentSelect!.options)
        if (option.zone == CARD_ZONE_HAND &&
            option.controller == _board.myController)
          option.sequence,
    };
  }

  /// 就地选择中可点击的场上卡 key（`controller_zone_sequence`）。
  Set<String> get inlineSelectableFieldKeys {
    if (!inlineSelectActive) return const {};
    return {
      for (final option in state.currentSelect!.options)
        if (option.zone == CARD_ZONE_MZONE ||
            option.zone == CARD_ZONE_SZONE)
          zoneKeyOf(option.controller, option.zone, option.sequence),
    };
  }

  /// 就地选择中已勾选的手牌下标 / 场上卡 key（用于高亮样式）。
  Set<int> get inlineSelectedHandSequences {
    final select = state.currentSelect;
    if (select == null) return const {};
    return {
      for (final index in state.inlineSelectedOptionIndices)
        if (index < select.options.length)
          if (select.options[index] case final option
              when option.zone == CARD_ZONE_HAND &&
                  option.controller == _board.myController)
            option.sequence,
    };
  }

  Set<String> get inlineSelectedFieldKeys {
    final select = state.currentSelect;
    if (select == null) return const {};
    return {
      for (final index in state.inlineSelectedOptionIndices)
        if (index < select.options.length)
          if (select.options[index] case final option
              when option.zone == CARD_ZONE_MZONE ||
                  option.zone == CARD_ZONE_SZONE)
            zoneKeyOf(option.controller, option.zone, option.sequence),
    };
  }

  /// 点击可放置槽位（场地组件直接回调，key 为 `controller_zone_sequence`）。
  void respondSelectPlaceKey(String key) {
    final select = state.currentSelect;
    if (select?.type != SelectType.place) return;
    for (final option in select!.options) {
      if (zoneKeyOf(option.controller, option.zone, option.sequence) == key) {
        respondSelectPlace(option.controller, option.zone, option.sequence);
        return;
      }
    }
  }

  /// 选择提示的统一呈现方式：页面只消费该结果插入 SelectPromptLayer，
  /// 不再各自判断放置/就地/模态的互斥关系。
  SelectPromptMode get selectPromptMode {
    final select = state.currentSelect;
    // 阶段指令窗口由阶段菜单/场上操作处理，不出选择提示。
    if (select == null || state.hasPhaseCommandWindow) {
      return SelectPromptMode.none;
    }
    if (select.type == SelectType.place &&
        state.placeTargetFieldKeys.isNotEmpty) {
      return SelectPromptMode.place;
    }
    if (inlineSelectActive) return SelectPromptMode.inline;
    return SelectPromptMode.modal;
  }

  /// 手牌下标对应的就地选择选项下标；不可选时返回 null。
  int? inlineOptionIndexForHand(int sequence) {
    final select = state.currentSelect;
    if (select == null) return null;
    for (var i = 0; i < select.options.length; i++) {
      final option = select.options[i];
      if (option.zone == CARD_ZONE_HAND &&
          option.controller == _board.myController &&
          option.sequence == sequence) {
        return i;
      }
    }
    return null;
  }

  /// 场上卡对应的就地选择选项下标；不可选时返回 null。
  int? inlineOptionIndexForField(FieldCard card) {
    final select = state.currentSelect;
    if (select == null) return null;
    for (var i = 0; i < select.options.length; i++) {
      final option = select.options[i];
      if (option.controller == card.controller &&
          option.zone == card.zone &&
          option.sequence == card.sequence) {
        return i;
      }
    }
    return null;
  }

  /// 多选模式下切换某选项的勾选状态（受 max 限制）。
  void toggleInlineOption(int index) {
    final select = state.currentSelect;
    if (select == null) return;
    final next = {...state.inlineSelectedOptionIndices};
    if (next.contains(index)) {
      next.remove(index);
    } else if (next.length < select.max) {
      next.add(index);
    }
    state = state.copyWith(inlineSelectedOptionIndices: next);
  }

  /// 多选确认：按选项下标升序提交已勾选的卡。
  void confirmInlineSelect() {
    if (!state.inlineSelectCanConfirm) return;
    respondInlineMulti(state.inlineSelectedOptionIndices.toList()..sort());
  }

  /// 解除选择（unselect）的「完成」：向服务端确认当前勾选结果。
  void finishInlineUnselect() {
    final select = state.currentSelect;
    if (select?.type != SelectType.unselect ||
        !state.inlineSelectCanConfirm) {
      return;
    }
    respondSelectUnselectCard(null);
  }

  /// 取消当前就地选择（等价于弹窗的「取消」）。
  void cancelInlineSelect() {
    final select = state.currentSelect;
    if (select == null || !select.cancelable) return;
    switch (select.type) {
      case SelectType.chain:
        respondSelectChain(-1);
      case SelectType.unselect:
        respondSelectUnselectCard(null);
      case SelectType.sum:
        respondSelectSum(const []);
      default:
        respondSelectCard(const []);
    }
  }

  /// 按当前窗口类型把多选下标编码为对应的响应消息。
  void respondInlineMulti(List<int> indices) {
    switch (state.currentSelect?.type) {
      case SelectType.tribute:
        respondSelectTribute(indices);
      case SelectType.sum:
        respondSelectSum(indices);
      default:
        respondSelectCard(indices);
    }
  }
}

/// 选择窗口状态的 provider，按房间 ProviderScope override 隔离。
final selectWindowProvider =
    NotifierProvider<SelectWindowNotifier, SelectWindowState>(
  SelectWindowNotifier.new,
);
