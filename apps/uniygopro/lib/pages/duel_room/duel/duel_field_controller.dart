import 'dart:async';
import 'dart:ui';

import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter/foundation.dart';
import 'package:ygo_data/card_info.dart';

import '../../../models/FieldCard.dart';
import '../../../widgets/duel_room/menus/hand_action_menu.dart';
import '../../../widgets/duel_room/inspector/zone_browser_modal.dart';
import 'playmat_action_resolver.dart';
import 'duel_field_store.dart';

/// 决斗场地页的本地交互状态：手牌/场地/区域浏览选择、检视面板、
/// 阶段菜单，以及对应的动作解析与菜单条目构建。
///
/// 页面本地状态，生命周期跟随页面（不走全局 Provider）；
/// 所有状态变更通过 [ChangeNotifier] 通知页面重建；
/// 指令响应直接走 [DuelFieldStore.respondCurrentCommand]。
class DuelFieldController extends ChangeNotifier {
  DuelFieldController({required this.duelStore});

  final DuelFieldStore duelStore;

  int? _inspectedCardCode;
  CardInfo? _inspectedCardInfo;
  int? _selectedHandSequence;
  Rect? _selectedHandCardRect;
  int? _selectedZoneBrowserSequence;
  FieldCard? _selectedFieldCard;
  String? _openZoneBrowserKey;
  bool _showInspector = true;
  bool _showPhaseMenu = false;

  int? get inspectedCardCode => _inspectedCardCode;
  CardInfo? get inspectedCardInfo => _inspectedCardInfo;
  int? get selectedHandSequence => _selectedHandSequence;
  Rect? get selectedHandCardRect => _selectedHandCardRect;
  int? get selectedZoneBrowserSequence => _selectedZoneBrowserSequence;
  FieldCard? get selectedFieldCard => _selectedFieldCard;
  String? get openZoneBrowserKey => _openZoneBrowserKey;
  bool get showInspector => _showInspector;
  bool get showPhaseMenu => _showPhaseMenu;

  // ---- 检视面板 ----

  /// 仅修改状态不通知，供各 handler 组合后统一 notify。
  void _inspectCardMut(
    int? code, {
    bool preserveHandSelection = false,
    bool preserveZoneBrowser = false,
  }) {
    if (code == null || code <= 0) return;
    // 主动触发卡信息加载，避免非常规路径（连锁确认等）得知 code 的卡
    // 一直停留在 Card #xxxx 占位。
    unawaited(duelStore.ensureCardInfo(code));
    _inspectedCardCode = code;
    _inspectedCardInfo = duelStore.getCardInfo(code);
    if (!preserveHandSelection) {
      _selectedHandSequence = null;
      _selectedHandCardRect = null;
    }
    if (!preserveZoneBrowser) {
      _openZoneBrowserKey = null;
      _selectedZoneBrowserSequence = null;
    }
    _showInspector = true;
  }

  void dismissInspector() {
    if (!_showInspector) return;
    _showInspector = false;
    notifyListeners();
  }

  // ---- 手牌 ----

  void handleHandCardTap(int sequence, int code) {
    _selectedHandSequence = sequence;
    _selectedHandCardRect = null;
    _openZoneBrowserKey = null;
    _selectedZoneBrowserSequence = null;
    _selectedFieldCard = null;
    _showPhaseMenu = false;
    _inspectCardMut(code, preserveHandSelection: true);
    notifyListeners();
  }

  void handleHandCardDoubleTap(int sequence, int code) {
    final action = defaultHandActionFor(sequence);
    if (action == null) {
      handleHandCardTap(sequence, code);
      return;
    }
    _selectedHandSequence = null;
    _selectedHandCardRect = null;
    _openZoneBrowserKey = null;
    _selectedZoneBrowserSequence = null;
    _selectedFieldCard = null;
    _showPhaseMenu = false;
    duelStore.respondCurrentCommand(action.response);
    notifyListeners();
  }

  void handleHandCardRectChanged(Rect? rect) {
    if (_selectedHandCardRect == rect) return;
    _selectedHandCardRect = rect;
    notifyListeners();
  }

  // ---- 场地卡 ----

  void handleFieldCardTap(FieldCard? fieldCard, int? code) {
    final effectiveCode = code ?? fieldCard?.code;
    if (effectiveCode != null) {
      _inspectCardMut(effectiveCode);
    }
    _selectedFieldCard =
        fieldCard == null || fieldActionsForCard(fieldCard).isEmpty
        ? null
        : fieldCard;
    _selectedHandSequence = null;
    _selectedHandCardRect = null;
    _selectedZoneBrowserSequence = null;
    _showPhaseMenu = false;
    notifyListeners();
  }

  // ---- 区域浏览 ----

  static bool isBrowsableZone(String zoneKey) {
    switch (zoneKey) {
      case 'self_grave':
      case 'opp_grave':
      case 'self_removed':
      case 'opp_removed':
      case 'self_extra':
      case 'opp_extra':
        return true;
      default:
        return false;
    }
  }

  void handleZoneInspect(String zoneKey) {
    if (isBrowsableZone(zoneKey)) {
      openZoneBrowser(zoneKey);
    }
  }

  void openZoneBrowser(String zoneKey) {
    _selectedHandSequence = null;
    _selectedHandCardRect = null;
    _openZoneBrowserKey = zoneKey;
    _selectedZoneBrowserSequence = null;
    _selectedFieldCard = null;
    _showPhaseMenu = false;
    _showInspector = true;
    notifyListeners();
  }

  void closeZoneBrowser() {
    if (_openZoneBrowserKey == null && _selectedZoneBrowserSequence == null) {
      return;
    }
    _openZoneBrowserKey = null;
    _selectedZoneBrowserSequence = null;
    notifyListeners();
  }

  void inspectZoneBrowserCard(int sequence, int code) {
    _selectedZoneBrowserSequence = sequence;
    _selectedFieldCard = null;
    _inspectCardMut(code, preserveZoneBrowser: true);
    notifyListeners();
  }

  // ---- 阶段菜单 ----

  void togglePhaseMenu() {
    if (phaseActionsForCurrentWindow().isEmpty) {
      return;
    }
    _showPhaseMenu = !_showPhaseMenu;
    _selectedHandSequence = null;
    _selectedHandCardRect = null;
    _selectedFieldCard = null;
    notifyListeners();
  }

  // ---- 高优先级覆盖层 ----

  /// 当出现更高优先级的选择窗口（非阶段指令）时，本地弹层应当让位。
  bool get needsHigherPriorityDismiss {
    final hasHigherPriorityOverlay =
        duelStore.currentSelect != null && !duelStore.hasPhaseCommandWindow;
    if (!hasHigherPriorityOverlay) {
      return false;
    }
    return _selectedHandSequence != null ||
        _selectedZoneBrowserSequence != null ||
        _selectedFieldCard != null ||
        _openZoneBrowserKey != null ||
        _showPhaseMenu;
  }

  void clearLocalUi() {
    _selectedHandSequence = null;
    _selectedHandCardRect = null;
    _selectedZoneBrowserSequence = null;
    _selectedFieldCard = null;
    _openZoneBrowserKey = null;
    _showPhaseMenu = false;
    notifyListeners();
  }

  // ---- 动作解析 ----

  List<PlaymatResolvedAction> handActionsForCurrentSelection() {
    final selectedSequence = _selectedHandSequence;
    if (selectedSequence == null ||
        selectedSequence < 0 ||
        selectedSequence >= duelStore.selfHand.length) {
      return const [];
    }
    return _handActionsForSequence(selectedSequence);
  }

  PlaymatResolvedAction? defaultHandActionFor(int sequence) {
    final actions = _handActionsForSequence(sequence);
    if (actions.isEmpty) return null;

    final cardInfo = cardInfoForHandSequence(sequence);
    final priorities = cardInfo?.isMonster == true
        ? const [
            PlaymatResolvedActionKind.summon,
            PlaymatResolvedActionKind.specialSummon,
            PlaymatResolvedActionKind.monsterSet,
          ]
        : const [
            PlaymatResolvedActionKind.activate,
            PlaymatResolvedActionKind.spellSet,
          ];

    for (final kind in priorities) {
      for (final action in actions) {
        if (action.kind == kind) {
          return action;
        }
      }
    }
    return actions.first;
  }

  List<PlaymatResolvedAction> _handActionsForSequence(int sequence) {
    return PlaymatActionResolver.resolveHandActions(
      duelStore,
      duelStore.myController,
      sequence,
    );
  }

  CardInfo? cardInfoForHandSequence(int sequence) {
    if (sequence < 0 || sequence >= duelStore.selfHand.length) {
      return null;
    }
    return duelStore.getCardInfo(duelStore.selfHand[sequence]);
  }

  List<PlaymatResolvedAction> phaseActionsForCurrentWindow() {
    return PlaymatActionResolver.resolvePhaseActions(
      duelStore,
      duelStore.myController,
    );
  }

  List<PlaymatResolvedAction> fieldActionsForCard(FieldCard fieldCard) {
    return PlaymatActionResolver.resolveFieldActions(
      duelStore,
      duelStore.myController,
      fieldCard.controller,
      fieldCard.zone,
      fieldCard.sequence,
    );
  }

  String _resolvedActionLabel(
    PlaymatResolvedAction action,
    CardInfo? cardInfo,
  ) {
    final isSpellTrap = cardInfo?.isSpell == true || cardInfo?.isTrap == true;
    switch (action.kind) {
      case PlaymatResolvedActionKind.activate:
        return isSpellTrap ? '发动' : action.label;
      default:
        return action.label;
    }
  }

  // ---- 菜单条目构建 ----

  List<HandActionMenuEntry> buildHandActionMenuEntries() {
    final selectedSequence = _selectedHandSequence;
    final cardInfo = selectedSequence == null
        ? null
        : cardInfoForHandSequence(selectedSequence);
    return handActionsForCurrentSelection()
        .map(
          (action) => HandActionMenuEntry(
            label: _resolvedActionLabel(action, cardInfo),
            onTap: () {
              _selectedHandSequence = null;
              _selectedHandCardRect = null;
              _showPhaseMenu = false;
              duelStore.respondCurrentCommand(action.response);
              notifyListeners();
            },
          ),
        )
        .toList();
  }

  List<HandActionMenuEntry> buildPhaseActionMenuEntries() {
    return phaseActionsForCurrentWindow()
        .map(
          (action) => HandActionMenuEntry(
            label: action.label,
            onTap: () {
              _showPhaseMenu = false;
              duelStore.respondCurrentCommand(action.response);
              notifyListeners();
            },
          ),
        )
        .toList(growable: false);
  }

  List<HandActionMenuEntry> buildFieldActionEntries() {
    final fieldCard = _selectedFieldCard;
    if (fieldCard == null) {
      return const [];
    }
    final cardInfo = duelStore.getCardInfo(fieldCard.code);
    return fieldActionsForCard(fieldCard)
        .map(
          (action) => HandActionMenuEntry(
            label: _resolvedActionLabel(action, cardInfo),
            onTap: () => dispatchResolvedAction(action),
          ),
        )
        .toList(growable: false);
  }

  void dispatchResolvedAction(
    PlaymatResolvedAction action, {
    bool closeZoneBrowser = false,
  }) {
    if (!duelStore.respondCurrentCommand(action.response)) {
      return;
    }
    _selectedHandSequence = null;
    _selectedHandCardRect = null;
    _selectedFieldCard = null;
    _showPhaseMenu = false;
    if (closeZoneBrowser) {
      _openZoneBrowserKey = null;
      _selectedZoneBrowserSequence = null;
    }
    notifyListeners();
  }

  // ---- 区域浏览数据 ----

  List<ZoneBrowserCardEntry> zoneBrowserEntriesFor(String zoneKey) {
    final sequenceToCode = <int, int>{};
    final codes = duelStore.getZoneCodes(zoneKey);
    for (var sequence = 0; sequence < codes.length; sequence++) {
      final code = codes[sequence];
      if (code > 0) {
        sequenceToCode[sequence] = code;
      }
    }

    final controller = _controllerForZoneKey(zoneKey);
    final location = _locationForZoneKey(zoneKey);
    // 仅在当前确实持有 idle 响应窗口时，才把可发动卡合并进列表；
    // 否则 selectedIdleActions 是上一次窗口的残留，会注入已离开区域的幽灵卡。
    if (controller != null &&
        location != null &&
        duelStore.hasIdleCommandWindow &&
        duelStore.ownsCurrentWindow(duelStore.myController)) {
      for (final action in duelStore.selectedIdleActions) {
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
  }

  List<ZoneBrowserActionEntry> zoneBrowserActionsForSelection(
    String zoneKey,
    List<ZoneBrowserCardEntry> entries,
  ) {
    final selectedSequence = _selectedZoneBrowserSequence;
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
    final controller = _controllerForZoneKey(zoneKey);
    if (location == null || controller == null) {
      return const [];
    }

    return PlaymatActionResolver.resolveZoneActions(
          duelStore,
          duelStore.myController,
          controller,
          location,
          entry.code,
          selectedSequence,
        )
        .map((action) {
          final cardInfo = duelStore.getCardInfo(entry.code);
          return ZoneBrowserActionEntry(
            label: _resolvedActionLabel(action, cardInfo),
            onTap: () => dispatchResolvedAction(action, closeZoneBrowser: true),
          );
        })
        .toList(growable: false);
  }

  int hiddenCountForZoneKey(String zoneKey) {
    switch (zoneKey) {
      case 'self_grave':
        return duelStore.selfGrave;
      case 'opp_grave':
        return duelStore.oppGrave;
      case 'self_removed':
        return duelStore.selfRemoved;
      case 'opp_removed':
        return duelStore.oppRemoved;
      case 'self_extra':
        return duelStore.selfExtra;
      case 'opp_extra':
        return duelStore.oppExtra;
      default:
        return 0;
    }
  }

  int? _controllerForZoneKey(String zoneKey) {
    if (zoneKey.startsWith('self_')) return duelStore.myController;
    if (zoneKey.startsWith('opp_')) return 1 - duelStore.myController;
    return null;
  }

  int? _locationForZoneKey(String zoneKey) {
    if (zoneKey.endsWith('_grave')) return CARD_ZONE_GRAVE;
    if (zoneKey.endsWith('_removed')) return CARD_ZONE_REMOVED;
    if (zoneKey.endsWith('_extra')) return CARD_ZONE_EXTRA;
    return null;
  }
}
