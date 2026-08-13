import 'package:duelink/duelink.dart';
import 'package:ygo_data/card_info.dart' as pkg;

import '../../../../models/battle_action.dart';
import '../../../../models/battle_presentation.dart';
import '../../../../models/chain_link.dart';
import '../../../../models/confirm_cards.dart';
import '../../../../models/duel_menu.dart';
import '../../../../models/duel_result_summary.dart';
import '../../../../models/field_card.dart';
import '../../../../models/idle_action.dart';
import '../../../../models/select_state.dart';
import '../duel_field_store.dart';

/// 决斗场景对 UI 暴露的状态快照。
///
/// 过渡设计：标量与计算属性按需代理给 Bloc 内部的可变核心
/// （[DuelFieldStore]），保证 `context.select` / `buildWhen` 按值
/// 比较的语义正确。后续核心逻辑纯函数化后，本类可平滑切换为
/// 全量不可变快照。
class DuelState {
  DuelState._(this._core, {required this.revision, required this.isTimerTick});

  factory DuelState.fromCore(
    DuelFieldStore core,
    int revision, {
    bool isTimerTick = false,
  }) => DuelState._(core, revision: revision, isTimerTick: isTimerTick);

  final DuelFieldStore _core;

  /// 单调递增的发射序号，便于调试与 buildWhen 比较。
  final int revision;

  /// 本次发射是否仅由回合计时器心跳触发（仅 timeLeft 变化）。
  /// 页面级订阅可用 `buildWhen: (_, s) => !s.isTimerTick` 跳过每秒
  /// 一次的整页重建，时间显示组件自行订阅。
  final bool isTimerTick;

  // ── 战场状态 ──────────────────────────────────────────────

  int get selfDeck => _core.selfDeck;
  int get selfExtra => _core.selfExtra;
  int get selfGrave => _core.selfGrave;
  int get selfRemoved => _core.selfRemoved;
  int get oppDeck => _core.oppDeck;
  int get oppExtra => _core.oppExtra;
  int get oppGrave => _core.oppGrave;
  int get oppRemoved => _core.oppRemoved;
  int get selfLp => _core.selfLp;
  int get opponentLp => _core.opponentLp;
  int get selfLpDelta => _core.selfLpDelta;
  int get opponentLpDelta => _core.opponentLpDelta;
  int get selfLpEventId => _core.selfLpEventId;
  int get opponentLpEventId => _core.opponentLpEventId;
  int get currentPlayer => _core.currentPlayer;
  DuelPhase get phase => _core.phase;
  int get turnCount => _core.turnCount;
  int get selfTimeLeft => _core.selfTimeLeft;
  int get opponentTimeLeft => _core.opponentTimeLeft;
  int get myController => _core.myController;
  List<ChainLink> get chains => _core.chains;
  bool get chainSealed => _core.chainSealed;
  BattlePresentation? get battlePresentation => _core.battlePresentation;
  bool get inDamageStep => _core.inDamageStep;
  int get deckShuffleTick => _core.deckShuffleTick;
  int get deckShufflePlayer => _core.deckShufflePlayer;
  List<String> get duelLogs => _core.duelLogs;
  DuelResultSummary? get duelResult => _core.duelResult;

  Map<String, FieldCard> get fieldCards => _core.fieldCards;
  List<int> get selfHand => _core.selfHand;
  List<int> get opponentHand => _core.opponentHand;

  // ── 选择态 ────────────────────────────────────────────────

  SelectState? get currentSelect => _core.currentSelect;
  List<IdleAction> get selectedIdleActions => _core.selectedIdleActions;
  List<BattleAction> get selectedBattleActions =>
      _core.selectedBattleActions;
  bool get enableBp => _core.enableBp;
  bool get enableM2 => _core.enableM2;
  bool get enableEp => _core.enableEp;
  bool get isWaitingForInput => _core.isWaitingForInput;
  bool get hasIdleCommandWindow => _core.hasIdleCommandWindow;
  bool get hasBattleCommandWindow => _core.hasBattleCommandWindow;
  bool get hasPhaseCommandWindow => _core.hasPhaseCommandWindow;
  SelectPromptMode get selectPromptMode => _core.selectPromptMode;

  bool ownsCurrentWindow(int player) => _core.ownsCurrentWindow(player);
  bool canOpenPhaseMenuFor(int player) => _core.canOpenPhaseMenuFor(player);

  // ── 就地选择 ──────────────────────────────────────────────

  bool get inlineSelectActive => _core.inlineSelectActive;
  Set<int> get inlineSelectableHandSequences =>
      _core.inlineSelectableHandSequences;
  Set<int> get inlineSelectedHandSequences =>
      _core.inlineSelectedHandSequences;
  Set<String> get inlineSelectableFieldKeys =>
      _core.inlineSelectableFieldKeys;
  Set<String> get inlineSelectedFieldKeys => _core.inlineSelectedFieldKeys;
  Set<String> get placeTargetFieldKeys => _core.placeTargetFieldKeys;
  int get inlineSelectedCount => _core.inlineSelectedCount;
  bool get inlineSelectCanConfirm => _core.inlineSelectCanConfirm;
  String get inlineSelectHint => _core.inlineSelectHint;

  // ── 检视 / 确认 / 预览 ────────────────────────────────────

  int? get inspectedCardCode => _core.inspectedCardCode;
  pkg.CardInfo? get inspectedCardInfo => _core.inspectedCardInfo;
  int? get selectedHandSequence => _core.selectedHandSequence;
  int? get selectedZoneBrowserSequence => _core.selectedZoneBrowserSequence;
  FieldCard? get selectedFieldCard => _core.selectedFieldCard;
  String? get openZoneBrowserKey => _core.openZoneBrowserKey;
  bool get showInspector => _core.showInspector;
  bool get showPhaseMenu => _core.showPhaseMenu;
  bool get needsHigherPriorityDismiss => _core.needsHigherPriorityDismiss;
  ConfirmPanel? get confirmPanel => _core.confirmPanel;
  List<int> get floatPreviewCodes => _core.floatPreviewCodes;
  int get floatPreviewOwner => _core.floatPreviewOwner;
  bool get floatPreviewIsExtra => _core.floatPreviewIsExtra;
  bool get isFloatPreview => _core.isFloatPreview;
  Set<String> get confirmedFieldSlotKeys => _core.confirmedFieldSlotKeys;
  Set<int> get confirmedHandSequences => _core.confirmedHandSequences;
  int get confirmedHandOwner => _core.confirmedHandOwner;

  // ── 只读查询（动作解析、区域浏览等，纯派生数据）─────────────

  pkg.CardInfo? getCardInfo(int code) => _core.getCardInfo(code);
  List<int> getZoneCodes(String zoneKey) => _core.getZoneCodes(zoneKey);
  int hiddenCountForZoneKey(String zoneKey) =>
      _core.hiddenCountForZoneKey(zoneKey);
  List<int> get announceCardBlockedCodes => _core.announceCardBlockedCodes;
  List<ZoneBrowserCardEntry> zoneBrowserEntriesFor(String zoneKey) =>
      _core.zoneBrowserEntriesFor(zoneKey);
  List<ActionMenuEntry> zoneBrowserActionsForSelection(
    String zoneKey,
    List<ZoneBrowserCardEntry> entries,
  ) =>
      _core.zoneBrowserActionsForSelection(zoneKey, entries);
  List<ActionMenuEntry> buildHandActionMenuEntries() =>
      _core.buildHandActionMenuEntries();
  List<ActionMenuEntry> buildPhaseActionMenuEntries() =>
      _core.buildPhaseActionMenuEntries();
  List<ActionMenuEntry> buildFieldActionEntries() =>
      _core.buildFieldActionEntries();
  List<PlaymatResolvedAction> phaseActionsForCurrentWindow() =>
      _core.phaseActionsForCurrentWindow();
  Future<List<pkg.CardInfo>> searchAnnounceCards(String query) =>
      _core.searchAnnounceCards(query);
}
