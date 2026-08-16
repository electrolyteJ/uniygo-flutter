import 'dart:async';
import 'dart:developer' as console;

import 'package:biz/card_image_loader.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ygo_data/card_info.dart' as pkg;

import 'duel_field_state.dart';
import 'models/battle_action.dart';
import 'models/field_card.dart';
import 'models/field_zone_key.dart';
import 'models/idle_action.dart';
import 'models/select_state.dart';
import 'models/sum_check.dart' as sum_check;

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
    if (select == null) return false;
    if (select.type == SelectType.sum) {
      // SUM 窗口的可确认性由引擎校验决定（数量/合计两重约束），
      // 不是简单的 count >= min。
      return sum_check.sumSelectionIsValid(
        mustOptions: select.mustOptions,
        options: select.options,
        sumTarget: select.sumTarget,
        sumExact: select.sumExact,
        min: select.min,
        max: select.max,
        selectedIndices: inlineSelectedOptionIndices,
      );
    }
    return inlineSelectedOptionIndices.length >= select.min;
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
        return select.sumExact
            ? '选择卡使合计等于 ${select.sumTarget}'
            : '按等级合计选择卡 ($count/${select.max})';
      case SelectType.counter:
        return '选择要移除的指示物（共 ${select.counterRequired} 个）';
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

  /// 窗口序号计数器：只增不减（reset 也不归零），
  /// 保证跨窗口、跨对局的陈旧 UI 响应都能被识别并丢弃。
  int _generationCounter = 0;

  @override
  SelectWindowState build() {
    _dataService = ref.watch(dataServiceProvider);
    _duelService = ref.watch(duelServiceProvider);
    return const SelectWindowState();
  }

  /// 读取战场状态（myController / fieldCards / 战斗演出清理）。
  DuelFieldState get _board => ref.read(duelFieldProvider);

  // ──────────────────────────────────────────
  // 选择响应
  // ──────────────────────────────────────────

  /// 分配递增的 generation，返回新窗口快照（不写 state）。
  /// 需要连同其他字段一次性写入 state 的 apply* 使用该 helper。
  SelectState _nextWindow(SelectState select) {
    _generationCounter++;
    return select.copyWith(generation: _generationCounter);
  }

  /// 打开一个新的选择窗口：分配递增的 generation、预热卡图缓存。
  /// 所有 apply* 一律经此入口（或 [_nextWindow]）开窗，
  /// 保证 generation 语义统一。
  /// （unselect 窗口的初始勾选由 applySelectUnselectCard 在开窗后补写。）
  void _openWindow(SelectState select) {
    final window = _nextWindow(select);
    state = state.copyWith(
      currentSelect: window,
      inlineSelectedOptionIndices: const {},
    );
    _preloadSelectImages(window);
  }

  /// 记录当前等待玩家处理的选择请求，同时预热所有选项的卡图缓存。
  void setSelect(SelectState select) {
    _openWindow(select);
  }

  /// 预热 CardSelector 中所有卡片图片到 [CardImageLoader] 全局缓存。
  void _preloadSelectImages(SelectState select) {
    for (final opt in [...select.mustOptions, ...select.options]) {
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

  /// generation 门卫：UI 回传的 generation 与当前窗口不一致时，
  /// 说明是陈旧菜单的迟到点击，记录日志并忽略。
  /// generation 为 null（旧调用方未传）时不做门卫。
  bool _acceptGeneration(int? generation, String method) {
    if (generation == null) return true;
    final current = state.currentSelect?.generation;
    if (generation != current) {
      console.log(
        '$method: stale generation $generation (current window generation=$current), ignored',
      );
      return false;
    }
    return true;
  }

  void respondIdleCmd(int sequence, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondIdleCmd')) return;
    _sendResponse(CtosGameMsgResponse.selectIdleCmd(sequence));
    clearSelect();
  }

  void respondBattleCmd(int sequence, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondBattleCmd')) return;
    _sendResponse(CtosGameMsgResponse.selectBattleCmd(sequence));
    clearSelect();
  }

  bool respondCurrentCommand(int sequence, {int? generation}) {
    if (state.hasIdleCommandWindow) {
      respondIdleCmd(sequence, generation: generation);
      return true;
    }
    if (state.hasBattleCommandWindow) {
      respondBattleCmd(sequence, generation: generation);
      return true;
    }
    return false;
  }

  void respondSelectCard(List<int> sequences, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectCard')) return;
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

  void respondSelectChain(int sequence, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectChain')) return;
    _sendResponse(CtosGameMsgResponse.selectSingle(sequence));
    clearSelect();
  }

  void respondSelectEffectYn(bool yes, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectEffectYn')) return;
    _sendResponse(CtosGameMsgResponse.selectEffectYn(yes ? 1 : 0));
    clearSelect();
  }

  void respondSelectYesNo(bool yes, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectYesNo')) return;
    _sendResponse(CtosGameMsgResponse.selectEffectYn(yes ? 1 : 0));
    clearSelect();
  }

  void respondSelectPosition(int position, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectPosition')) return;
    _sendResponse(CtosGameMsgResponse.selectPosition(position));
    clearSelect();
  }

  void respondSelectOption(int sequence, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectOption')) return;
    _sendResponse(CtosGameMsgResponse.selectOption(sequence));
    clearSelect();
  }

  void respondSelectPlace(int player, int zone, int sequence, {
    int? generation,
  }) {
    if (!_acceptGeneration(generation, 'respondSelectPlace')) return;
    _sendResponse(
      CtosGameMsgResponse.selectPlace(
        CtosSelectPlace(player: player, zone: zone, sequence: sequence),
      ),
    );
    clearSelect();
  }

  void respondSelectTribute(List<int> sequences, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectTribute')) return;
    _sendResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSelectUnselectCard(int? sequence, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectUnselectCard')) return;
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

  /// MSG_SELECT_COUNTER 回包（playerop.cpp:624-637）：
  /// 每卡一个 int16（窗口顺序），各值 ≤ 该卡指示物数，
  /// 且总和必须恰好等于需移除总数，否则服务端回 MSG_RETRY。
  /// 本地先行校验，违规直接拒绝并记录日志，避免无谓的往返重试。
  void respondSelectCounter(List<int> counts, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectCounter')) return;
    final select = state.currentSelect;
    if (select == null || select.type != SelectType.counter) {
      console.log('respondSelectCounter: no active COUNTER window, ignored');
      return;
    }
    if (counts.length != select.options.length) {
      console.log(
        'respondSelectCounter: expected ${select.options.length} values '
        '(one per card), got ${counts.length}; rejected',
      );
      return;
    }
    var sum = 0;
    for (var i = 0; i < counts.length; i++) {
      final limit = select.options[i].level ?? 0;
      if (counts[i] < 0 || counts[i] > limit) {
        console.log(
          'respondSelectCounter: value ${counts[i]} out of range 0..$limit '
          'for card #$i; rejected',
        );
        return;
      }
      sum += counts[i];
    }
    if (sum != select.counterRequired) {
      console.log(
        'respondSelectCounter: sum $sum != required ${select.counterRequired}; '
        'rejected',
      );
      return;
    }
    _sendResponse(CtosGameMsgResponse.selectCounter(counts));
    clearSelect();
  }

  /// MSG_SELECT_SUM 回包（playerop.cpp:690-751 select_with_sum_limit）：
  /// bvalue[0] = 含必选卡的总数；bvalue[1..mcount] 为必选占位（引擎不读）；
  /// bvalue[mcount+1..] = 仅相对可选段（state.options）的下标。
  /// selectMulti 的 count 字节即 bvalue[0]，故 payload =
  /// [占位 × mcount, ...可选段下标]。
  void respondSelectSum(List<int> selectableIndices, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSelectSum')) return;
    final select = state.currentSelect;
    if (select == null || select.type != SelectType.sum) {
      console.log('respondSelectSum: no active SUM window, ignored');
      return;
    }
    final seen = <int>{};
    for (final index in selectableIndices) {
      if (index < 0 || index >= select.options.length || !seen.add(index)) {
        console.log(
          'respondSelectSum: invalid indices $selectableIndices for '
          '${select.options.length} selectable cards; rejected',
        );
        return;
      }
    }
    final mcount = select.mustOptions.length;
    final payload = <int>[
      for (var i = 0; i < mcount; i++) 0,
      ...selectableIndices,
    ];
    console.log(
      'respondSelectSum: count=${mcount + selectableIndices.length} '
      '(must=$mcount + selected=${selectableIndices.length}) '
      'exact=${select.sumExact} target=${select.sumTarget} '
      'indices=$selectableIndices',
    );
    _sendResponse(CtosGameMsgResponse.selectMulti(payload));
    clearSelect();
  }

  void respondSortCard(List<int> indices, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondSortCard')) return;
    _sendResponse(CtosGameMsgResponse.sortCard(indices));
    clearSelect();
  }

  void respondAnnounceCard(int code, {int? generation}) {
    if (!_acceptGeneration(generation, 'respondAnnounceCard')) return;
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
    ref.read(duelFieldProvider.notifier)
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
      currentSelect: _nextWindow(
        SelectState(
          type: SelectType.idleCmd,
          player: msg.player,
          min: 1,
          max: 1,
        ),
      ),
      inlineSelectedOptionIndices: const {},
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
      currentSelect: _nextWindow(
        SelectState(
          type: SelectType.battleCmd,
          player: msg.player,
          min: 1,
          max: 1,
        ),
      ),
      inlineSelectedOptionIndices: const {},
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
    _openWindow(
      SelectState(
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
    console.log('applySelectChain: ${msg.chains.length} options');
    for (final chain in msg.chains) {
      options.add(
        SelectOption(
          code: chain.code,
          controller: chain.location.controller,
          zone: chain.location.location,
          // 就地高亮需要真实场上/手牌位置；连锁响应值与选项下标一致，
          // 提交时仍按下标回传。
          sequence: chain.location.sequence,
          // 不使用 effectDescription 原始数值作为文案（对玩家无意义）。
        ),
      );
    }
    _openWindow(
      SelectState(
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
    _openWindow(
      SelectState(
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
    _openWindow(
      SelectState(
        type: SelectType.yesNo,
        player: msg.player,
        min: 1,
        max: 1,
        effectDescription: msg.effectDescription,
      ),
    );
  }

  void applySelectPlace(MsgSelectPlace msg) {
    _openWindow(
      SelectState(
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
    _openWindow(
      SelectState(
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
    _openWindow(
      SelectState(
        type: SelectType.tribute,
        player: msg.player,
        options: options,
        min: msg.min,
        max: msg.max,
        cancelable: msg.cancelable != 0,
      ),
    );
  }

  /// MSG_SELECT_COUNTER 窗口：level = 该卡当前可用指示物数，
  /// counterRequired = 需移除的指示物总数（msg.min）。
  /// 响应编码见 [respondSelectCounter]（playerop.cpp:624-637）。
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
    console.log(
      'applySelectCounter: player=${msg.player} required=${msg.min} '
      'cards=${msg.count} counterCounts=${msg.counterCounts}',
    );
    _openWindow(
      SelectState(
        type: SelectType.counter,
        player: msg.player,
        options: options,
        min: msg.min,
        max: msg.min,
        counterRequired: msg.min,
      ),
    );
  }

  /// MSG_SELECT_SUM 窗口（playerop.cpp:690-751）：
  /// options 只含可选段（selectable），必选段（must）进 mustOptions；
  /// level/level2 = 合计参数 o1/o2（o2==0 时 duelink 已归一为 level2==level1，
  /// 这里原样保留，sum_check 按引擎 get_sum_params 语义还原）。
  /// sumTarget = msg.levelSum；sumExact = msg.max == 0。
  /// 响应下标仅相对可选段，见 [respondSelectSum]。
  void applySelectSum(MsgSelectSum msg) {
    SelectOption toOption(MsgSelectSumInfo card) {
      return SelectOption(
        code: card.code,
        controller: card.location.controller,
        zone: card.location.location,
        sequence: card.location.sequence,
        level: card.level1,
        level2: card.level2,
      );
    }

    final mustOptions = msg.mustSelectCards.map(toOption).toList(growable: false);
    final options = msg.selectableCards.map(toOption).toList(growable: false);
    console.log(
      'applySelectSum: player=${msg.player} target=${msg.levelSum} '
      'min=${msg.min} max=${msg.max} exact=${msg.max == 0} '
      'must=${mustOptions.length} selectable=${options.length}',
    );
    _openWindow(
      SelectState(
        type: SelectType.sum,
        player: msg.player,
        options: options,
        mustOptions: mustOptions,
        min: msg.min,
        max: msg.max,
        sumTarget: msg.levelSum,
        sumExact: msg.max == 0,
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
    _openWindow(
      SelectState(
        type: SelectType.sort,
        player: msg.player,
        options: options,
        min: msg.count,
        max: msg.count,
      ),
    );
  }

  void applySelectOption(MsgSelectOption msg) {
    _openWindow(
      SelectState(
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
      currentSelect: _nextWindow(
        SelectState(
          type: SelectType.announceCard,
          player: msg.player,
          min: 1,
          max: 1,
        ),
      ),
      inlineSelectedOptionIndices: const {},
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
      currentSelect: _nextWindow(
        SelectState(
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
      ),
      // 就地选择模式下同步已勾选项，保证高亮与「完成」门槛一致。
      inlineSelectedOptionIndices: {...initiallySelected},
    );
    _preloadSelectImages(state.currentSelect!);
  }

  /// MSG_SELECT_DISFIELD 与 MSG_SELECT_PLACE 共用引擎 field::select_place，
  /// flag 位 置位 = 不可用；回包校验为 `(sel & flag)` 即重试
  /// （playerop.cpp:460-467）。因此与 MSG_SELECT_PLACE 相同：
  /// 仅 flag 未置位的区域可选（selectableWhenBitSet: false）。
  void applySelectDisfield(MsgSelectPlace msg) {
    _openWindow(
      SelectState(
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
  ///
  /// 保持单槽位响应语义：引擎 select_place 在 count>1 时期望
  /// 连续 count 组 (p,l,s)，单槽位回包会触发 MSG_RETRY；
  /// 此处保留单选行为但对 count>1 记录告警（多位放置需专门 UI）。
  void respondSelectPlaceKey(String key, {int? generation}) {
    final select = state.currentSelect;
    if (select?.type != SelectType.place) return;
    if (select!.max > 1) {
      console.log(
        'respondSelectPlaceKey: place window expects ${select.max} slots, '
        'single-slot tap may be retried by server',
      );
    }
    for (final option in select.options) {
      if (zoneKeyOf(option.controller, option.zone, option.sequence) == key) {
        respondSelectPlace(
          option.controller,
          option.zone,
          option.sequence,
          generation: generation,
        );
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

  /// 当前 SUM 窗口下已勾选集合是否通过引擎校验
  /// （数量约束 + select_sum_check1 / 精确合计窗口判定，
  /// 移植见 models/sum_check.dart）。[selectedIndices] 相对可选段
  /// （state.options）。非 SUM 窗口返回 false。
  bool isSumSelectionValid(Set<int> selectedIndices) {
    final select = state.currentSelect;
    if (select == null || select.type != SelectType.sum) return false;
    return sum_check.sumSelectionIsValid(
      mustOptions: select.mustOptions,
      options: select.options,
      sumTarget: select.sumTarget,
      sumExact: select.sumExact,
      min: select.min,
      max: select.max,
      selectedIndices: selectedIndices,
    );
  }

  /// 多选模式下切换某选项的勾选状态。
  /// 数量上限仅对非精确合计窗口生效（limit = max，
  /// 引擎对可选段的数量约束即 max；必选段另计）；
  /// 精确合计（sumExact）模式无数量上限，合法性由
  /// [isSumSelectionValid] 判定。
  void toggleInlineOption(int index) {
    final select = state.currentSelect;
    if (select == null) return;
    final next = {...state.inlineSelectedOptionIndices};
    if (next.contains(index)) {
      next.remove(index);
    } else {
      final countLimited =
          select.type != SelectType.sum || !select.sumExact;
      if (!countLimited || next.length < select.max) {
        next.add(index);
      }
    }
    state = state.copyWith(inlineSelectedOptionIndices: next);
  }

  /// 多选确认：按选项下标升序提交已勾选的卡。
  /// SUM 窗口先过引擎合计校验，非法组合不提交（避免 MSG_RETRY）。
  void confirmInlineSelect() {
    final select = state.currentSelect;
    if (select == null) return;
    final selected = state.inlineSelectedOptionIndices;
    if (select.type == SelectType.sum) {
      if (!isSumSelectionValid(selected)) {
        console.log(
          'confirmInlineSelect: SUM selection $selected does not satisfy '
          'target=${select.sumTarget} exact=${select.sumExact}, ignored',
        );
        return;
      }
      respondSelectSum(selected.toList()..sort());
      return;
    }
    if (!state.inlineSelectCanConfirm) return;
    respondInlineMulti(selected.toList()..sort());
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
  ///
  /// 引擎取消语义：可取消窗口回 -1 即被接受
  /// （playerop.cpp:271-275 select_card 响应分支：
  /// `returns.ivalue[0] == -1 && cancelable` → 通过；
  /// select_chain / select_unselect_card 同样以 -1 表示放弃）。
  /// 因此 min>=1 的可取消窗口一律回 selectSingle(-1)，
  /// 而不是空 selectMulti（空列表会被引擎当成 0 张选择而 MSG_RETRY）。
  /// min==0 的窗口空选择本身即合法应答，保持空列表行为。
  void cancelInlineSelect() {
    final select = state.currentSelect;
    if (select == null || !select.cancelable) return;
    switch (select.type) {
      case SelectType.chain:
        respondSelectChain(-1);
      case SelectType.unselect:
        respondSelectUnselectCard(null);
      default:
        if (select.min == 0) {
          respondSelectCard(const []);
        } else {
          _sendResponse(CtosGameMsgResponse.selectSingle(-1));
          clearSelect();
        }
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
