import 'package:applog/console.dart' as console;

import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:resource_data/card_info.dart' as pkg;

import 'duel_field_state.dart';
import 'field_overlay_state.dart';
import '../models/battle_action.dart';
import '../models/chain_link.dart';
import '../models/select_state.dart';
import '../models/duel_menu.dart';
import '../models/field_card.dart';
import '../models/idle_action.dart';
import '../models/playmat_resolved_action.dart';
import 'select_window_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 场地派生读取：把「当前窗口 + 选中态」派生为动作/菜单条目，供页面
/// 以 Provider 形式响应式消费（替代原 DuelFieldController 里的纯读取方法）。
///
/// 这里只放「读多个子状态 → 算出一个派生值」的逻辑；写单个状态仍直连
/// 对应 Notifier。少数需要回包的闭包（菜单 onTap）在闭包内通过
/// ref.read 取 Notifier 调用，属于事件处理而非 build 期读取。
/// 与交互逻辑（inspectCard / handleXxxCardTap 等）分离，后者留在
/// DuelFieldPage 内作为薄方法。
///
/// ⚠️ 维护约定（两处易碎的隐式约束，改动时务必遵守）：
/// 1. 派生 provider 一律手写 `Provider(...)` 并显式声明 `dependencies:`
///    （列出所有 ref.watch/read 的房间级 provider）。riverpod_generator
///    不会从函数体推导 dependencies（生成恒为 null），缺了它 provider
///    会解析到根容器、读到根容器的空状态而不是房间 scope 的 override
///    （announce_modal_scope_test.dart 是本类问题的回归兜底）。
/// 2. onTap 闭包通过 `ref.read(xxxProvider.notifier)` 捕获 Notifier 实例；
///    依赖「四个子状态 Provider 在房间 scope 内实例稳定」这一前提。
///    全部 provider 保持 @Riverpod(keepAlive: true)（手写时代语义），
///    不要改成默认的 autoDispose，否则闭包可能持有 stale notifier。

// ──────────────────────────────────────────
// 纯函数（不依赖外部服务，只读传入状态）
// ──────────────────────────────────────────

bool _isBrowserZone(int location) =>
    location == CARD_ZONE_GRAVE ||
    location == CARD_ZONE_REMOVED ||
    location == CARD_ZONE_EXTRA;

int? _controllerForZoneKey(String zoneKey, int myController) {
  if (zoneKey.startsWith('self_')) return myController;
  if (zoneKey.startsWith('opp_')) return 1 - myController;
  return null;
}

int? _locationForZoneKey(String zoneKey) {
  if (zoneKey.endsWith('_grave')) return CARD_ZONE_GRAVE;
  if (zoneKey.endsWith('_removed')) return CARD_ZONE_REMOVED;
  if (zoneKey.endsWith('_extra')) return CARD_ZONE_EXTRA;
  return null;
}

String? _locationToZonePrefix(int location) {
  if (location == CARD_ZONE_GRAVE) return 'grave';
  if (location == CARD_ZONE_REMOVED) return 'removed';
  if (location == CARD_ZONE_EXTRA) return 'extra';
  return null;
}

String _resolvedActionLabel(
  PlaymatResolvedAction action,
  pkg.CardInfo? cardInfo,
) {
  final isSpellTrap = cardInfo?.isSpell == true || cardInfo?.isTrap == true;
  switch (action.kind) {
    case PlaymatResolvedActionKind.activate:
      return isSpellTrap ? '发动' : action.label;
    default:
      return action.label;
  }
}

/// 「坏兽」系列的卡组代码（setcode 低 16 位），用于区分往双方场上的特召。
const int _kaijuSetcode = 0xd3;

/// 是否为「坏兽」系列卡（如坏星坏兽 基兹基尔）。
bool _isKaiju(pkg.CardInfo? cardInfo) => cardInfo != null &&
    cardInfo.setcode.any((sc) => (sc & 0xffff) == _kaijuSetcode);

/// 当一张卡有多个特殊召唤动作时，为其生成可区分的展示标签。
String _disambiguatedSpLabel(int ordinal, bool kaiju) {
  // 坏兽的顺序约定：脚本里「往对方场上特召（解放对方怪兽）」先注册、
  // 「往自己场上特召（对方场上有坏兽时）」后注册，引擎按效果注册顺序下发。
  if (kaiju) {
    if (ordinal == 0) return '特殊召唤（到对方场上）';
    if (ordinal == 1) return '特殊召唤（到自己场上）';
  }
  return '特殊召唤（方式${ordinal + 1}）';
}

/// 为同一张卡的一组动作生成展示标签。
///
/// 引擎（ocgcore）对一张卡注册了多个特召规则时（如坏兽可同时「解放对方怪兽
/// 往对方场上特召」与「对方场上有坏兽时往自己场上特召」），会下发多个同为
/// 「特殊召唤」的选项，且协议里不带特召去向。这里按去向/序号区分，避免菜单里
/// 出现多个一模一样、无法区分的条目。
List<String> disambiguateActionLabels(
  List<PlaymatResolvedAction> actions,
  pkg.CardInfo? cardInfo,
) {
  final labels = actions
      .map((action) => _resolvedActionLabel(action, cardInfo))
      .toList();

  final spIndexes = <int>[
    for (var i = 0; i < actions.length; i++)
      if (actions[i].kind == PlaymatResolvedActionKind.specialSummon) i,
  ];
  if (spIndexes.length <= 1) return labels;

  final kaiju = _isKaiju(cardInfo);
  for (var k = 0; k < spIndexes.length; k++) {
    labels[spIndexes[k]] = _disambiguatedSpLabel(k, kaiju);
  }
  return labels;
}

PlaymatResolvedAction _resolveIdleAction(IdleAction action, int myController) {
  return PlaymatResolvedAction(
    label: action.label(myController),
    response: action.sequence,
    kind: action.kind,
    code: action.code,
    controller: action.controller,
    location: action.location,
    sequence: action.locationSequence,
  );
}

PlaymatResolvedAction _resolveBattleAction(BattleAction action) {
  return PlaymatResolvedAction(
    label: action.label,
    response: action.sequence,
    kind: action.kind,
    code: action.code,
    controller: action.attackerController,
    location: action.attackerLocation,
    sequence: action.attackerSequence,
  );
}

List<PlaymatResolvedAction> _resolveHandActions(
  int sequence,
  SelectWindowState select,
  DuelFieldState board,
) {
  if (!select.hasIdleCommandWindow ||
      !select.ownsCurrentWindow(board.myController)) {
    return const [];
  }
  return select.selectedIdleActions
      .where(
        (action) =>
            action.controller == board.myController &&
            action.location == CARD_ZONE_HAND &&
            action.locationSequence == sequence,
      )
      .map((action) => _resolveIdleAction(action, board.myController))
      .toList(growable: false);
}

List<PlaymatResolvedAction> _resolveFieldActions(
  int controller,
  int location,
  int sequence,
  int? code,
  SelectWindowState select,
  DuelFieldState board,
) {
  if (!select.ownsCurrentWindow(board.myController)) {
    return const [];
  }

  final actions = <PlaymatResolvedAction>[];
  if (select.hasIdleCommandWindow) {
    final idleActions = select.selectedIdleActions
        .where(
          (action) =>
              action.controller == controller && action.location == location,
        )
        .toList(growable: false);
    final exactIdleActions = idleActions
        .where((action) => action.locationSequence == sequence)
        .map((action) => _resolveIdleAction(action, board.myController));
    actions.addAll(exactIdleActions);
    if (actions.isEmpty && code != null && code > 0) {
      final codeMatchedActions = idleActions
          .where((action) => action.code == code)
          .map((action) => _resolveIdleAction(action, board.myController))
          .toList(growable: false);
      if (codeMatchedActions.length == 1) {
        actions.addAll(codeMatchedActions);
      }
    }
  }
  if (select.hasBattleCommandWindow) {
    actions.addAll(
      select.selectedBattleActions
          .where(
            (action) =>
                action.attackerController == controller &&
                action.attackerLocation == location &&
                action.attackerSequence == sequence,
          )
          .map(_resolveBattleAction),
    );
  }
  return actions;
}

List<PlaymatResolvedAction> _resolveZoneActions(
  int controller,
  int location,
  int code,
  int? sequence,
  SelectWindowState select,
  DuelFieldState board,
) {
  if (!select.ownsCurrentWindow(board.myController) ||
      !_isBrowserZone(location)) {
    return const [];
  }

  final actions = <PlaymatResolvedAction>[];
  if (select.hasIdleCommandWindow) {
    actions.addAll(
      select.selectedIdleActions
          .where(
            (action) =>
                action.code == code &&
                action.controller == controller &&
                action.location == location &&
                (sequence == null || action.locationSequence == sequence),
          )
          .map((action) => _resolveIdleAction(action, board.myController)),
    );
  }
  if (select.hasBattleCommandWindow) {
    actions.addAll(
      select.selectedBattleActions
          .where(
            (action) =>
                action.type == 0 &&
                action.code == code &&
                action.attackerController == controller &&
                action.attackerLocation == location &&
                (sequence == null || action.attackerSequence == sequence),
          )
          .map(_resolveBattleAction),
    );
  }
  return actions;
}

List<PlaymatResolvedAction> _resolvePhaseActions(
  SelectWindowState select,
  DuelFieldState board,
) {
  if (!select.ownsCurrentWindow(board.myController)) {
    return const [];
  }

  if (select.hasIdleCommandWindow) {
    return [
      if (select.enableBp)
        const PlaymatResolvedAction(
          label: '进入战斗阶段',
          response: 6,
          kind: PlaymatResolvedActionKind.toBattlePhase,
        ),
      if (select.enableEp)
        const PlaymatResolvedAction(
          label: '结束回合',
          response: 7,
          kind: PlaymatResolvedActionKind.toEndPhase,
        ),
    ];
  }

  if (select.hasBattleCommandWindow) {
    return [
      if (select.enableM2)
        const PlaymatResolvedAction(
          label: '进入主要阶段2',
          response: 2,
          kind: PlaymatResolvedActionKind.toMainPhase2,
        ),
      if (select.enableEp)
        const PlaymatResolvedAction(
          label: '结束回合',
          response: 3,
          kind: PlaymatResolvedActionKind.toEndPhase,
        ),
    ];
  }

  return const [];
}

List<PlaymatResolvedAction> _handActionsForSequence(
  int sequence,
  SelectWindowState select,
  DuelFieldState board,
) {
  final actions = _resolveHandActions(sequence, select, board);
  // 魔法/陷阱卡：发动在上，盖放在下
  if (actions.length <= 1) return actions;
  final sorted = List<PlaymatResolvedAction>.of(actions);
  sorted.sort((a, b) {
    if (a.kind == PlaymatResolvedActionKind.activate &&
        b.kind == PlaymatResolvedActionKind.spellSet) {
      return -1;
    }
    if (b.kind == PlaymatResolvedActionKind.activate &&
        a.kind == PlaymatResolvedActionKind.spellSet) {
      return 1;
    }
    return 0;
  });
  return sorted;
}

pkg.CardInfo? _cardInfoForHandSequence(
  int sequence,
  DuelFieldState board,
  DuelFieldNotifier boardN,
) {
  if (sequence < 0 || sequence >= board.selfHand.length) {
    return null;
  }
  return boardN.getCardInfo(board.selfHand[sequence]);
}

/// 场上卡在当前窗口下可执行的动作（含空匹配时的调试日志）。
/// 供 fieldActionMenuProvider 与页面交互方法（handleFieldCardTap）共用。
List<PlaymatResolvedAction> resolveFieldActions(
  FieldCard fieldCard,
  SelectWindowState select,
  DuelFieldState board,
) {
  final actions = _resolveFieldActions(
    fieldCard.controller,
    fieldCard.zone,
    fieldCard.sequence,
    fieldCard.code,
    select,
    board,
  );
  if (actions.isEmpty &&
      select.hasIdleCommandWindow &&
      select.ownsCurrentWindow(board.myController)) {
    final candidateDebug = !kDebugMode
        ? ''
        : select.selectedIdleActions
              .map(
                (action) =>
                    '${action.type}:${action.sequence}:code=${action.code}:c=${action.controller}:z=${action.location}:s=${action.locationSequence}',
              )
              .join(', ');
    if (kDebugMode) {
      console.log(
        'fieldActionsForCard: no match for code=${fieldCard.code} c=${fieldCard.controller} z=${fieldCard.zone} s=${fieldCard.sequence}; '
        'idleActions=[$candidateDebug]',
      );
    }
  }
  return actions;
}

/// 菜单条目 onTap 的共享「已解析动作 → 回包并清选中态」逻辑。
void _dispatchResolvedAction(
  PlaymatResolvedAction action, {
  required SelectWindowNotifier selectN,
  required FieldOverlayNotifier overlayN,
  bool closeZoneBrowser = false,
}) {
  if (kDebugMode) {
    console.log('dispatchResolvedAction: ${action.kind} ${action.label}');
  }
  if (!selectN.respondCurrentCommand(action.response)) {
    return;
  }
  overlayN.clearAfterResolvedAction(closeZoneBrowser: closeZoneBrowser);
}

// ──────────────────────────────────────────
// 派生 Provider（手写 + 显式 dependencies，见文件头维护约定第 1 条）
// ──────────────────────────────────────────

/// 当前窗口的阶段动作（进入战斗/结束回合/进 M2）。
final phaseActionsProvider = Provider<List<PlaymatResolvedAction>>(
  (ref) => _phaseActions(ref),
  dependencies: [duelFieldProvider, selectWindowProvider],
);

/// 手牌选中卡的操作菜单条目。
final handActionMenuProvider = Provider<List<ActionMenuEntry>>(
  (ref) => _handActionMenu(ref),
  dependencies: [
    duelFieldProvider,
    selectWindowProvider,
    fieldOverlayProvider,
  ],
);

/// 阶段菜单条目（阶段灯点击后的弹层内容）。
final phaseActionMenuProvider = Provider<List<ActionMenuEntry>>(
  (ref) => _phaseActionMenu(ref),
  dependencies: [
    phaseActionsProvider,
    selectWindowProvider,
    fieldOverlayProvider,
  ],
);

/// 场上选中卡的操作菜单条目。
final fieldActionMenuProvider = Provider<List<ActionMenuEntry>>(
  (ref) => _fieldActionMenu(ref),
  dependencies: [
    duelFieldProvider,
    selectWindowProvider,
    fieldOverlayProvider,
  ],
);

/// 区域浏览器（墓地/除外/额外）内展示的卡列表。
final zoneBrowserEntriesProvider =
    Provider.family<List<ZoneBrowserCardEntry>, String>(
  (ref, zoneKey) => _zoneBrowserEntries(ref, zoneKey),
  dependencies: [duelFieldProvider, selectWindowProvider],
);

/// 区域浏览器内选中卡的操作菜单条目。
final zoneBrowserActionsProvider =
    Provider.family<List<ActionMenuEntry>, String>(
  (ref, zoneKey) => _zoneBrowserActions(ref, zoneKey),
  dependencies: [
    duelFieldProvider,
    selectWindowProvider,
    fieldOverlayProvider,
    zoneBrowserEntriesProvider,
  ],
);

/// 区域浏览器的「隐藏数量」展示值。
final zoneHiddenCountProvider = Provider.family<int, String>(
  (ref, zoneKey) => _zoneHiddenCount(ref, zoneKey),
  dependencies: [duelFieldProvider],
);

/// 区域浏览器内「有可发动/可召唤动作」的卡位 sequence 集合
/// （墓地/除外/额外），驱动 tile 上的「可发动」标记。
///
/// 生效条件与可发动卡合并进列表的条件一致（idle 窗口 + 己方窗口），
/// sequence 口径与 [zoneBrowserActionsProvider] 的匹配口径一致——
/// 被标记的 tile 点开后一定有可执行动作。
final zoneBrowserActivatableSequencesProvider =
    Provider.family<Set<int>, String>(
  (ref, zoneKey) => _zoneBrowserActivatableSequences(ref, zoneKey),
  dependencies: [duelFieldProvider, selectWindowProvider],
);

/// 出现更高优先级选择窗口（非阶段指令）时，本地弹层是否应当让位。
final needsHigherPriorityDismissProvider = Provider<bool>(
  (ref) => _needsHigherPriorityDismiss(ref),
  dependencies: [selectWindowProvider, fieldOverlayProvider],
);

/// 当前窗口下，墓地/除外/额外中「有可发动/可召唤卡」的区域 key 集合，
/// 用于场地上的可发动区域高亮提醒（智能打牌反馈：墓效/额外召唤提示）。
final activatableZoneKeysProvider = Provider<Set<String>>(
  (ref) => _activatableZoneKeys(ref),
  dependencies: [duelFieldProvider, selectWindowProvider],
);

/// 选择提示呈现方式（跨 selectWindow+duelField 派生）。
/// 页面按区域订阅本 provider，替代整页 watch 后的 notifier 读取。
final selectPromptModeProvider = Provider<SelectPromptMode>(
  (ref) => _selectPromptMode(ref),
  dependencies: [selectWindowProvider, duelFieldProvider],
);

/// 当前窗口的阶段动作（进入战斗/结束回合/进 M2）。
List<PlaymatResolvedAction> _phaseActions(Ref ref) {
  final board = ref.watch(duelFieldProvider);
  final select = ref.watch(selectWindowProvider);
  return _resolvePhaseActions(select, board);
}

List<ActionMenuEntry> _handActionMenu(Ref ref) {
  final board = ref.watch(duelFieldProvider);
  final select = ref.watch(selectWindowProvider);
  final overlay = ref.watch(fieldOverlayProvider);
  final boardN = ref.read(duelFieldProvider.notifier);
  final selectN = ref.read(selectWindowProvider.notifier);
  final overlayN = ref.read(fieldOverlayProvider.notifier);

  final selectedSequence = overlay.selectedHandSequence;
  if (selectedSequence == null ||
      selectedSequence < 0 ||
      selectedSequence >= board.selfHand.length) {
    return const [];
  }
  final cardInfo = _cardInfoForHandSequence(selectedSequence, board, boardN);
  final actions = _handActionsForSequence(selectedSequence, select, board);
  final labels = disambiguateActionLabels(actions, cardInfo);
  return [
    for (var i = 0; i < actions.length; i++)
      ActionMenuEntry(
        label: labels[i],
        onTap: () {
          overlayN.clearHandSelectionAndClosePhaseMenu();
          selectN.respondCurrentCommand(actions[i].response);
        },
      ),
  ];
}

List<ActionMenuEntry> _phaseActionMenu(Ref ref) {
  final selectN = ref.read(selectWindowProvider.notifier);
  final overlayN = ref.read(fieldOverlayProvider.notifier);
  return ref
      .watch(phaseActionsProvider)
      .map(
        (action) => ActionMenuEntry(
          label: action.label,
          onTap: () {
            overlayN.closePhaseMenu();
            selectN.respondCurrentCommand(action.response);
          },
        ),
      )
      .toList(growable: false);
}

List<ActionMenuEntry> _fieldActionMenu(Ref ref) {
  final board = ref.watch(duelFieldProvider);
  final select = ref.watch(selectWindowProvider);
  final overlay = ref.watch(fieldOverlayProvider);
  final boardN = ref.read(duelFieldProvider.notifier);
  final selectN = ref.read(selectWindowProvider.notifier);
  final overlayN = ref.read(fieldOverlayProvider.notifier);

  final fieldCard = overlay.selectedFieldCard;
  if (fieldCard == null) {
    return const [];
  }
  final cardInfo = boardN.getCardInfo(fieldCard.code);
  if (kDebugMode) {
    console.log(
      'buildFieldActionEntries: code=${fieldCard.code} '
      'cardInfo=${cardInfo?.name ?? cardInfo}',
    );
  }
  final actions = resolveFieldActions(fieldCard, select, board);
  final labels = disambiguateActionLabels(actions, cardInfo);
  return [
    for (var i = 0; i < actions.length; i++)
      ActionMenuEntry(
        label: labels[i],
        onTap: () => _dispatchResolvedAction(
          actions[i],
          selectN: selectN,
          overlayN: overlayN,
        ),
      ),
  ];
}

List<ZoneBrowserCardEntry> _zoneBrowserEntries(Ref ref, String zoneKey) {
  final board = ref.watch(duelFieldProvider);
  final select = ref.watch(selectWindowProvider);

  final sequenceToCode = <int, int>{};
  final codes = board.getZoneCodes(zoneKey);
  for (var sequence = 0; sequence < codes.length; sequence++) {
    final code = codes[sequence];
    if (code > 0) {
      sequenceToCode[sequence] = code;
    }
  }

  final controller = _controllerForZoneKey(zoneKey, board.myController);
  final location = _locationForZoneKey(zoneKey);
  // 仅在当前确实持有 idle 响应窗口时，才把可发动卡合并进列表；
  // 否则 selectedIdleActions 是上一次窗口的残留，会注入已离开区域的幽灵卡。
  if (controller != null &&
      location != null &&
      select.hasIdleCommandWindow &&
      select.ownsCurrentWindow(board.myController)) {
    for (final action in select.selectedIdleActions) {
      if (action.controller != controller ||
          action.location != location ||
          action.code <= 0) {
        continue;
      }
      sequenceToCode[action.locationSequence] = action.code;
    }
  }

  final sequences = sequenceToCode.keys.toList()..sort();
  return [
    for (final sequence in sequences)
      ZoneBrowserCardEntry(sequence: sequence, code: sequenceToCode[sequence]!),
  ];
}

List<ActionMenuEntry> _zoneBrowserActions(Ref ref, String zoneKey) {
  final board = ref.watch(duelFieldProvider);
  final select = ref.watch(selectWindowProvider);
  final overlay = ref.watch(fieldOverlayProvider);
  final boardN = ref.read(duelFieldProvider.notifier);
  final selectN = ref.read(selectWindowProvider.notifier);
  final overlayN = ref.read(fieldOverlayProvider.notifier);

  final entries = ref.watch(zoneBrowserEntriesProvider(zoneKey));
  final selectedSequence = overlay.selectedZoneBrowserSequence;
  if (selectedSequence == null) {
    return const [];
  }

  ZoneBrowserCardEntry? selectedEntry;
  for (final entry in entries) {
    if (entry.sequence == selectedSequence) {
      selectedEntry = entry;
      break;
    }
  }
  final entry = selectedEntry;
  if (entry == null || entry.code <= 0) {
    return const [];
  }

  final location = _locationForZoneKey(zoneKey);
  final controller = _controllerForZoneKey(zoneKey, board.myController);
  if (location == null || controller == null) {
    return const [];
  }

  final cardInfo = boardN.getCardInfo(entry.code);
  final actions = _resolveZoneActions(
    controller,
    location,
    entry.code,
    selectedSequence,
    select,
    board,
  );
  final labels = disambiguateActionLabels(actions, cardInfo);
  return [
    for (var i = 0; i < actions.length; i++)
      ActionMenuEntry(
        label: labels[i],
        onTap: () => _dispatchResolvedAction(
          actions[i],
          selectN: selectN,
          overlayN: overlayN,
          closeZoneBrowser: true,
        ),
      ),
  ];
}

Set<int> _zoneBrowserActivatableSequences(Ref ref, String zoneKey) {
  final board = ref.watch(duelFieldProvider);
  final select = ref.watch(selectWindowProvider);
  final controller = _controllerForZoneKey(zoneKey, board.myController);
  final location = _locationForZoneKey(zoneKey);
  if (controller == null ||
      location == null ||
      !select.hasIdleCommandWindow ||
      !select.ownsCurrentWindow(board.myController)) {
    return const {};
  }
  return {
    for (final action in select.selectedIdleActions)
      if (action.controller == controller && action.location == location)
        action.locationSequence,
  };
}

int _zoneHiddenCount(Ref ref, String zoneKey) {
  final board = ref.watch(duelFieldProvider);
  switch (zoneKey) {
    case 'self_grave':
      return board.selfGrave;
    case 'opp_grave':
      return board.oppGrave;
    case 'self_removed':
      return board.selfRemoved;
    case 'opp_removed':
      return board.oppRemoved;
    case 'self_extra':
      return board.selfExtra;
    case 'opp_extra':
      return board.oppExtra;
    default:
      return 0;
  }
}

bool _needsHigherPriorityDismiss(Ref ref) {
  final select = ref.watch(selectWindowProvider);
  final overlay = ref.watch(fieldOverlayProvider);
  final hasHigherPriorityOverlay =
      select.currentSelect != null && !select.hasPhaseCommandWindow;
  if (!hasHigherPriorityOverlay) {
    return false;
  }
  return overlay.hasAnyOverlayOpen;
}

/// 当前窗口下，墓地/除外/额外中「有可发动/可召唤卡」的区域 key 集合，
/// 用于场地上的可发动区域高亮提醒（智能打牌反馈：墓效/额外召唤提示）。
///
/// 仅覆盖主阶段 idle 指令窗口：战斗指令窗口（MSG_SELECT_BATTLE_CMD）的
/// action 是攻击，attacker 均在场上，不涉及墓地/除外/额外发动；
/// 战斗中的快速效果走 MSG_SELECT_CHAIN，属另一套交互，不在此处理。
Set<String> _activatableZoneKeys(Ref ref) {
  final board = ref.watch(duelFieldProvider);
  final select = ref.watch(selectWindowProvider);
  if (!select.hasIdleCommandWindow ||
      !select.ownsCurrentWindow(board.myController)) {
    return const {};
  }
  final result = <String>{};
  for (final action in select.selectedIdleActions) {
    final prefix = _locationToZonePrefix(action.location);
    if (prefix == null) continue;
    final owner = action.controller == board.myController ? 'self' : 'opp';
    result.add('${owner}_$prefix');
  }
  return result;
}

// ── 页面细粒度订阅切片（duel_room1 DuelFieldPage 用） ──────────────
//
// 切片为 record：Dart record 自带结构判等，Riverpod Provider/select
// 仅在切片内容变化时通知下游，替代整页 watch 四子状态的全量重建。
// List 字段按实例判等——biz 状态为不可变 copyWith 纪律，内容未变时
// 复用实例，恰好等价"内容未变不重建"。

/// 顶部 HUD（双状态卡 + 阶段条）订阅切片。
typedef DuelHudSlice = ({
  int myController,
  int currentPlayer,
  int selfLp,
  int opponentLp,
  int selfLpDelta,
  int opponentLpDelta,
  int selfLpEventId,
  int opponentLpEventId,
  int selfHandCount,
  int opponentHandCount,
  int selfDeck,
  int oppDeck,
  int selfExtra,
  int oppExtra,
  int selfGrave,
  int oppGrave,
  int selfRemoved,
  int oppRemoved,
  int turnCount,
  int selfTimeLeft,
  int opponentTimeLeft,
});

/// 连锁叠层切片。
typedef ChainSlice = ({List<ChainLink> chains, bool chainSealed});

DuelHudSlice selectHudSlice(DuelFieldState s) => (
  myController: s.myController,
  currentPlayer: s.currentPlayer,
  selfLp: s.selfLp,
  opponentLp: s.opponentLp,
  selfLpDelta: s.selfLpDelta,
  opponentLpDelta: s.opponentLpDelta,
  selfLpEventId: s.selfLpEventId,
  opponentLpEventId: s.opponentLpEventId,
  selfHandCount: s.selfHand.length,
  opponentHandCount: s.opponentHand.length,
  selfDeck: s.selfDeck,
  oppDeck: s.oppDeck,
  selfExtra: s.selfExtra,
  oppExtra: s.oppExtra,
  selfGrave: s.selfGrave,
  oppGrave: s.oppGrave,
  selfRemoved: s.selfRemoved,
  oppRemoved: s.oppRemoved,
  turnCount: s.turnCount,
  selfTimeLeft: s.selfTimeLeft,
  opponentTimeLeft: s.opponentTimeLeft,
);

ChainSlice selectChainSlice(DuelFieldState s) =>
    (chains: s.chains, chainSealed: s.chainSealed);

List<String> selectLogSlice(DuelFieldState s) => s.duelLogs;

/// 选择提示呈现方式（跨 selectWindow+duelField 派生）。
/// 页面按区域订阅本 provider，替代整页 watch 后的 notifier 读取。
SelectPromptMode _selectPromptMode(Ref ref) => resolveSelectPromptMode(
  ref.watch(selectWindowProvider),
  ref.watch(duelFieldProvider),
);
