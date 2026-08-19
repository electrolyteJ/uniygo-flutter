import 'dart:developer' as console;

import 'package:duelink/duelink.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ygo_data/card_info.dart' as pkg;

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
/// 1. 每个 Provider 的 `dependencies:` 必须列出它所有 `ref.watch` 的对象
///    （含中间派生 Provider，如 phaseActionsProvider / zoneBrowserEntriesProvider）。
///    漏列不会在编译期报错，只会在运行时触发 Riverpod 的 scoped-dependency
///    断言——有 derived_provider_scoping_test.dart 兜底。
/// 2. onTap 闭包通过 `ref.read(xxxProvider.notifier)` 捕获 Notifier 实例；
///    依赖「四个子状态 Provider 在房间 scope 内实例稳定」这一前提。
///    若将来改成 autoDispose / family，闭包可能持有 stale notifier。

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
    final candidateDebug = select.selectedIdleActions
        .map(
          (action) =>
              '${action.type}:${action.sequence}:code=${action.code}:c=${action.controller}:z=${action.location}:s=${action.locationSequence}',
        )
        .join(', ');
    console.log(
      'fieldActionsForCard: no match for code=${fieldCard.code} c=${fieldCard.controller} z=${fieldCard.zone} s=${fieldCard.sequence}; '
      'idleActions=[$candidateDebug]',
    );
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
  console.log('dispatchResolvedAction: ${action.kind} ${action.label}');
  if (!selectN.respondCurrentCommand(action.response)) {
    return;
  }
  overlayN.clearAfterResolvedAction(closeZoneBrowser: closeZoneBrowser);
}

// ──────────────────────────────────────────
// 派生 Provider
// ──────────────────────────────────────────

/// 当前窗口的阶段动作（进入战斗/结束回合/进 M2）。
final phaseActionsProvider = Provider<List<PlaymatResolvedAction>>((ref) {
  final board = ref.watch(duelFieldProvider);
  final select = ref.watch(selectWindowProvider);
  return _resolvePhaseActions(select, board);
}, dependencies: [duelFieldProvider, selectWindowProvider]);

/// 手牌选中卡的操作菜单条目。
final handActionMenuProvider = Provider<List<ActionMenuEntry>>(
  (ref) {
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
    return _handActionsForSequence(selectedSequence, select, board)
        .map(
          (action) => ActionMenuEntry(
            label: _resolvedActionLabel(action, cardInfo),
            onTap: () {
              overlayN.clearHandSelectionAndClosePhaseMenu();
              selectN.respondCurrentCommand(action.response);
            },
          ),
        )
        .toList();
  },
  dependencies: [duelFieldProvider, selectWindowProvider, fieldOverlayProvider],
);

/// 阶段菜单条目（阶段灯点击后的弹层内容）。
final phaseActionMenuProvider = Provider<List<ActionMenuEntry>>((ref) {
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
}, dependencies: [phaseActionsProvider]);

/// 场上选中卡的操作菜单条目。
final fieldActionMenuProvider = Provider<List<ActionMenuEntry>>(
  (ref) {
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
    console.log(
      'buildFieldActionEntries: code=${fieldCard.code} '
      'cardInfo=${cardInfo?.name ?? cardInfo}',
    );
    return resolveFieldActions(fieldCard, select, board)
        .map(
          (action) => ActionMenuEntry(
            label: _resolvedActionLabel(action, cardInfo),
            onTap: () => _dispatchResolvedAction(
              action,
              selectN: selectN,
              overlayN: overlayN,
            ),
          ),
        )
        .toList(growable: false);
  },
  dependencies: [duelFieldProvider, selectWindowProvider, fieldOverlayProvider],
);

/// 区域浏览器（墓地/除外/额外）内展示的卡列表。
final zoneBrowserEntriesProvider =
    Provider.family<List<ZoneBrowserCardEntry>, String>((ref, zoneKey) {
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
          ZoneBrowserCardEntry(
            sequence: sequence,
            code: sequenceToCode[sequence]!,
          ),
      ];
    }, dependencies: [duelFieldProvider, selectWindowProvider]);

/// 区域浏览器内选中卡的操作菜单条目。
final zoneBrowserActionsProvider =
    Provider.family<List<ActionMenuEntry>, String>(
      (ref, zoneKey) {
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

        return _resolveZoneActions(
              controller,
              location,
              entry.code,
              selectedSequence,
              select,
              board,
            )
            .map((action) {
              final cardInfo = boardN.getCardInfo(entry.code);
              return ActionMenuEntry(
                label: _resolvedActionLabel(action, cardInfo),
                onTap: () => _dispatchResolvedAction(
                  action,
                  selectN: selectN,
                  overlayN: overlayN,
                  closeZoneBrowser: true,
                ),
              );
            })
            .toList(growable: false);
      },
      dependencies: [
        duelFieldProvider,
        selectWindowProvider,
        fieldOverlayProvider,
        zoneBrowserEntriesProvider,
      ],
    );

/// 区域浏览器的「隐藏数量」展示值。
final zoneHiddenCountProvider = Provider.family<int, String>((ref, zoneKey) {
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
}, dependencies: [duelFieldProvider]);

/// 出现更高优先级选择窗口（非阶段指令）时，本地弹层是否应当让位。
final needsHigherPriorityDismissProvider = Provider<bool>((ref) {
  final select = ref.watch(selectWindowProvider);
  final overlay = ref.watch(fieldOverlayProvider);
  final hasHigherPriorityOverlay =
      select.currentSelect != null && !select.hasPhaseCommandWindow;
  if (!hasHigherPriorityOverlay) {
    return false;
  }
  return overlay.hasAnyOverlayOpen;
}, dependencies: [selectWindowProvider, fieldOverlayProvider]);

/// 当前窗口下，墓地/除外/额外中「有可发动/可召唤卡」的区域 key 集合，
/// 用于场地上的可发动区域高亮提醒（智能打牌反馈：墓效/额外召唤提示）。
///
/// 仅覆盖主阶段 idle 指令窗口：战斗指令窗口（MSG_SELECT_BATTLE_CMD）的
/// action 是攻击，attacker 均在场上，不涉及墓地/除外/额外发动；
/// 战斗中的快速效果走 MSG_SELECT_CHAIN，属另一套交互，不在此处理。
final activatableZoneKeysProvider = Provider<Set<String>>((ref) {
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
}, dependencies: [duelFieldProvider, selectWindowProvider]);

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

/// 己方手牌栏切片（手牌列表实例 + 己方控制器编号）。
typedef SelfHandSlice = ({List<int> selfHand, int myController});

/// 对手手牌栏切片。
typedef OppHandSlice = ({List<int> opponentHand, int myController});

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

SelfHandSlice selectSelfHandSlice(DuelFieldState s) =>
    (selfHand: s.selfHand, myController: s.myController);

OppHandSlice selectOppHandSlice(DuelFieldState s) =>
    (opponentHand: s.opponentHand, myController: s.myController);

ChainSlice selectChainSlice(DuelFieldState s) =>
    (chains: s.chains, chainSealed: s.chainSealed);

List<String> selectLogSlice(DuelFieldState s) => s.duelLogs;

/// 选择提示呈现方式（跨 selectWindow+duelField 派生）。
/// 页面按区域订阅本 provider，替代整页 watch 后的 notifier 读取。
final selectPromptModeProvider = Provider<SelectPromptMode>(
  (ref) => resolveSelectPromptMode(
    ref.watch(selectWindowProvider),
    ref.watch(duelFieldProvider),
  ),
  dependencies: [selectWindowProvider, duelFieldProvider],
);
