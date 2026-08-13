import 'dart:async';
import 'dart:developer' as console;

import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ygo_data/card_info.dart' as pkg;

import '../../providers/service_providers.dart';
import '../../models/battle_action.dart';
import '../../models/battle_presentation.dart';
import '../../models/chain_link.dart';
import '../../models/confirm_cards.dart';
import '../../models/duel_menu.dart';
import '../../models/duel_result_summary.dart';
import '../../models/field_card.dart';
import '../../models/idle_action.dart';
import '../../models/select_state.dart';
import 'card_confirm_state.dart';
import 'duel_field_state.dart';
import 'field_overlay_state.dart';
import 'select_window_state.dart';

class PlaymatResolvedAction {
  final String label;
  final int response;
  final PlaymatResolvedActionKind kind;
  final int? code;
  final int? controller;
  final int? location;
  final int? sequence;

  const PlaymatResolvedAction({
    required this.label,
    required this.response,
    this.kind = PlaymatResolvedActionKind.unknown,
    this.code,
    this.controller,
    this.location,
    this.sequence,
  });
}

/// 对局状态协调器 + 门面（服务器驱动），按房间 ProviderScope 隔离。
///
/// 状态按「数据来源 / 协议角色」拆成四个 Notifier 状态：
/// - [DuelFieldState]：服务器写入的对局事实（场面/手牌/LP/连锁/战报）；
/// - [SelectWindowState]：必须回包的选择窗口（MSG_SELECT_* 与响应编码）；
/// - [CardConfirmState]：只展示不回包的卡片确认（高亮/面板/浮动预览）；
/// - [FieldOverlayState]：玩家自己打开的本地查看浮层（检视/浏览器/菜单）。
///
/// 本类只做跨状态编排：MSG_* 消息分发 switch、音效、确认消息的多态
/// 呈现分发、手牌/场上/浏览器的交互入口、菜单动作派生，以及对外的
/// 统一门面（消费方 API 与原 ChangeNotifier 版保持一致）。
/// 全部消息应用逻辑与 duel_room1 保持逐字节一致。
class DuelFieldStore {
  DuelFieldStore(this.ref) {
    ref
        .read(selectWindowProvider)
        .bindBoardReader(() => ref.read(duelFieldProvider));
  }

  final Ref ref;

  DuelFieldState get _board => ref.read(duelFieldProvider);
  SelectWindowState get _select => ref.read(selectWindowProvider);
  CardConfirmState get _confirm => ref.read(cardConfirmProvider);
  FieldOverlayState get _overlay => ref.read(fieldOverlayProvider);
  YgoSoundService get _sound => ref.read(ygoSoundServiceProvider);

  IDuelService? _duelService;
  StreamSubscription<YgoStocMsg>? _msgSub;
  StreamSubscription<DuelPhase>? _phaseSub;

  // ──────────────────────────────────────────
  // 门面：对局事实（DuelFieldState）
  // ──────────────────────────────────────────

  YgoDataService get dataService => _board.dataService;
  YgoSoundService get ygoSoundService => _sound;
  Map<String, FieldCard> get fieldCards => _board.fieldCards;
  List<int> get selfHand => _board.selfHand;
  List<int> get opponentHand => _board.opponentHand;
  List<int> get selfGraveCodes => _board.selfGraveCodes;
  List<int> get opponentGraveCodes => _board.opponentGraveCodes;
  List<int> get selfRemovedCodes => _board.selfRemovedCodes;
  List<int> get opponentRemovedCodes => _board.opponentRemovedCodes;
  List<int> get selfExtraCodes => _board.selfExtraCodes;
  List<int> get opponentExtraCodes => _board.opponentExtraCodes;
  int get selfDeck => _board.selfDeck;
  int get selfExtra => _board.selfExtra;
  int get selfGrave => _board.selfGrave;
  int get selfRemoved => _board.selfRemoved;
  int get oppDeck => _board.oppDeck;
  int get oppExtra => _board.oppExtra;
  int get oppGrave => _board.oppGrave;
  int get oppRemoved => _board.oppRemoved;
  int get selfLp => _board.selfLp;
  int get opponentLp => _board.opponentLp;
  int get currentPlayer => _board.currentPlayer;
  DuelPhase get phase => _board.phase;
  int get turnCount => _board.turnCount;
  int get selfTimeLeft => _board.selfTimeLeft;
  int get opponentTimeLeft => _board.opponentTimeLeft;
  int get myController => _board.myController;
  List<ChainLink> get chains => _board.chains;
  bool get chainSealed => _board.chainSealed;
  String? get lastSummonKey => _board.lastSummonKey;
  String? get lastAttackFrom => _board.lastAttackFrom;
  String? get lastAttackTo => _board.lastAttackTo;
  BattlePresentation? get battlePresentation => _board.battlePresentation;
  bool get inDamageStep => _board.inDamageStep;
  int get selfLpDelta => _board.selfLpDelta;
  int get opponentLpDelta => _board.opponentLpDelta;
  int get selfLpEventId => _board.selfLpEventId;
  int get opponentLpEventId => _board.opponentLpEventId;
  int get deckShuffleTick => _board.deckShuffleTick;
  int get deckShufflePlayer => _board.deckShufflePlayer;
  List<String> get duelLogs => _board.duelLogs;
  List<PlayerInfo> get players => _board.players;
  DuelResultSummary? get duelResult => _board.duelResult;

  pkg.CardInfo? getCardInfo(int code) => _board.getCardInfo(code);
  Future<void> ensureCardInfo(int code) => _board.ensureCardInfo(code);
  String getCardImageUrl(int code) => _board.getCardImageUrl(code);
  void addLog(String log) => _board.addLog(log);
  void syncPlayers(List<PlayerInfo> players) => _board.syncPlayers(players);
  void setKnownSelfExtraDeckCodes(List<int> codes) =>
      _board.setKnownSelfExtraDeckCodes(codes);
  List<int> getZoneCodes(String zoneKey) => _board.getZoneCodes(zoneKey);

  // ──────────────────────────────────────────
  // 门面：选择窗口（SelectWindowState）
  // ──────────────────────────────────────────

  List<IdleAction> get selectedIdleActions => _select.selectedIdleActions;
  List<BattleAction> get selectedBattleActions =>
      _select.selectedBattleActions;
  bool get enableBp => _select.enableBp;
  bool get enableM2 => _select.enableM2;
  bool get enableEp => _select.enableEp;
  SelectState? get currentSelect => _select.currentSelect;
  bool get isWaitingForInput => _select.isWaitingForInput;
  bool get hasIdleCommandWindow => _select.hasIdleCommandWindow;
  bool get hasBattleCommandWindow => _select.hasBattleCommandWindow;
  bool get hasPhaseCommandWindow => _select.hasPhaseCommandWindow;
  List<int> get announceCardBlockedCodes => _select.announceCardBlockedCodes;
  bool ownsCurrentWindow(int player) => _select.ownsCurrentWindow(player);
  bool canOpenPhaseMenuFor(int player) =>
      _select.canOpenPhaseMenuFor(player);

  void setSelect(SelectState select) => _select.setSelect(select);
  void clearSelect() => _select.clearSelect();
  void respondIdleCmd(int sequence) => _select.respondIdleCmd(sequence);
  void respondBattleCmd(int sequence) => _select.respondBattleCmd(sequence);
  bool respondCurrentCommand(int sequence) =>
      _select.respondCurrentCommand(sequence);
  void respondSelectCard(List<int> sequences) =>
      _select.respondSelectCard(sequences);
  void respondSelectChain(int sequence) => _select.respondSelectChain(sequence);
  void respondSelectEffectYn(bool yes) => _select.respondSelectEffectYn(yes);
  void respondSelectYesNo(bool yes) => _select.respondSelectYesNo(yes);
  void respondSelectPosition(int position) =>
      _select.respondSelectPosition(position);
  void respondSelectOption(int sequence) =>
      _select.respondSelectOption(sequence);
  void respondSelectPlace(int player, int zone, int sequence) =>
      _select.respondSelectPlace(player, zone, sequence);
  void respondSelectTribute(List<int> sequences) =>
      _select.respondSelectTribute(sequences);
  void respondSelectUnselectCard(int? sequence) =>
      _select.respondSelectUnselectCard(sequence);
  void respondSelectCounter(List<int> values) =>
      _select.respondSelectCounter(values);
  void respondSelectSum(List<int> sequences) =>
      _select.respondSelectSum(sequences);
  void respondSortCard(List<int> indices) => _select.respondSortCard(indices);
  void respondAnnounceCard(int code) => _select.respondAnnounceCard(code);
  Future<List<pkg.CardInfo>> searchAnnounceCards(String keyword) =>
      _select.searchAnnounceCards(keyword);

  bool get inlineSelectActive => _select.inlineSelectActive;
  Set<int> get inlineSelectableHandSequences =>
      _select.inlineSelectableHandSequences;
  Set<String> get inlineSelectableFieldKeys =>
      _select.inlineSelectableFieldKeys;
  Set<int> get inlineSelectedHandSequences =>
      _select.inlineSelectedHandSequences;
  Set<String> get inlineSelectedFieldKeys => _select.inlineSelectedFieldKeys;
  int get inlineSelectedCount => _select.inlineSelectedCount;
  Set<String> get placeTargetFieldKeys => _select.placeTargetFieldKeys;
  void respondSelectPlaceKey(String key) => _select.respondSelectPlaceKey(key);
  bool get inlineSelectCanConfirm => _select.inlineSelectCanConfirm;
  SelectPromptMode get selectPromptMode => _select.selectPromptMode;
  String get inlineSelectHint => _select.inlineSelectHint;
  void confirmInlineSelect() => _select.confirmInlineSelect();
  void finishInlineUnselect() => _select.finishInlineUnselect();
  void cancelInlineSelect() => _select.cancelInlineSelect();

  // ──────────────────────────────────────────
  // 门面：卡片确认（CardConfirmState）
  // ──────────────────────────────────────────

  ConfirmPanel? get confirmPanel => _confirm.confirmPanel;
  List<int> get floatPreviewCodes => _confirm.floatPreviewCodes;
  int get floatPreviewOwner => _confirm.floatPreviewOwner;
  bool get floatPreviewIsExtra => _confirm.floatPreviewIsExtra;
  Set<String> get confirmedFieldSlotKeys => _confirm.confirmedFieldSlotKeys;
  Set<int> get confirmedHandSequences => _confirm.confirmedHandSequences;
  int get confirmedHandOwner => _confirm.confirmedHandOwner;
  bool get isFloatPreview => _confirm.isFloatPreview;
  void dismissConfirmPanel() => _confirm.dismissConfirmPanel();

  // ──────────────────────────────────────────
  // 门面：场地浮层（FieldOverlayState）
  // ──────────────────────────────────────────

  int? get inspectedCardCode => _overlay.inspectedCardCode;
  pkg.CardInfo? get inspectedCardInfo => _overlay.inspectedCardInfo;
  int? get selectedHandSequence => _overlay.selectedHandSequence;
  int? get selectedZoneBrowserSequence => _overlay.selectedZoneBrowserSequence;
  FieldCard? get selectedFieldCard => _overlay.selectedFieldCard;
  String? get openZoneBrowserKey => _overlay.openZoneBrowserKey;
  bool get showInspector => _overlay.showInspector;
  bool get showPhaseMenu => _overlay.showPhaseMenu;
  void dismissInspector() => _overlay.dismissInspector();
  void clearLocalUi() => _overlay.clearLocalUi();

  // ──────────────────────────────────────────
  // 生命周期
  // ──────────────────────────────────────────

  void bind(IDuelService duelService) {
    _duelService = duelService;
    _select.bind(duelService);
  }

  /// Provider 销毁时（离开房间）兜底取消流订阅；各状态内的定时器
  /// 由各自 Notifier 的 ref.onDispose 回收。
  void dispose() {
    _msgSub?.cancel();
    _phaseSub?.cancel();
  }

  /// 清空当前对局状态，供离开房间或新对局开始时使用。
  void reset() {
    _board.reset();
    _select.reset();
    _confirm.reset();
    _overlay.reset();
    _phaseSub?.cancel();
    _msgSub?.cancel();
    _select.emit();
    _confirm.emit();
    _overlay.emit();
  }

  /// 供页面在批量字段赋值后显式触发刷新。
  void markChanged() {
    _board.emit();
    _select.emit();
    _confirm.emit();
    _overlay.emit();
  }

  // ──────────────────────────────────────────
  // 服务器消息分发
  // ──────────────────────────────────────────

  /// 服务器原始消息入口：解码为对局事件后分发到对应状态。
  void handleServerMessage(YgoStocMsg msg) {
    // STOC_TIME_LIMIT 不在 GameMsg 内，单独处理
    final timeLimit = msg.timeLimit;
    if (timeLimit != null) {
      _board.handleTimeLimit(timeLimit);
      return;
    }
    final gameMsg = msg.gameMsg;
    if (gameMsg == null || gameMsg.innerMsg == null) {
      console.log('No game message payload $msg');
      return;
    }
    final innerMsg = gameMsg.innerMsg as Object;
    if (innerMsg is MsgUnimplemented) {
      console.log(
        'Ignoring unsupported event: ${gameMsg.func} (${innerMsg.data.length} bytes)',
      );
      return;
    }
    switch (gameMsg.func) {
      // 决斗事件 start
      case MSG_START:
        _board.handleStart(innerMsg);
        _sound.playDuelStart();
        break;
      case MSG_NEW_TURN:
        _board.handleNewTurn(innerMsg);
        _sound.playNewTurn();
        break;
      case MSG_NEW_PHASE:
        // 已通过 onDuelPhaseMessage 单独派发，避免这里重复记日志。
        _sound.playNewPhase();
        break;
      case MSG_WAITING:
        _board.handleWaiting(innerMsg as MsgWait);
        break;
      case MSG_ATTACK:
        _board.handleAttack(innerMsg);
        _sound.playAttack();
        break;
      case MSG_DAMAGE:
        _board.handleDamage(innerMsg);
        _sound.playDamage();
        break;
      case MSG_RECOVER:
        _board.handleRecover(innerMsg);
        _sound.playRecover();
        break;
      case MSG_LP_UPDATE:
        _board.handleLpUpdate(innerMsg);
        break;
      case MSG_PAY_LP_COST:
        _board.handlePayLife(innerMsg);
        _sound.playDamage();
        break;
      case MSG_CONFIRM_CARDS:
      case MSG_CONFIRM_DECKTOP:
      case MSG_CONFIRM_EXTRATOP:
        _handleConfirmCards(gameMsg.func, innerMsg as MsgConfirmCards);
        break;
      case MSG_CHAINING:
        _board.chainSealed = false;
        final name = _board.handleChaining(innerMsg);
        _board.addLog('连锁发动 $name。');
        _sound.playChain();
        break;
      case MSG_CHAINED:
        _board.handleChained(innerMsg as MsgChained);
        break;
      case MSG_CHAIN_SOLVING:
        _board.chainSealed = true;
        _board.handleChainSolving(innerMsg as MsgChainSolving);
        break;
      case MSG_CHAIN_SOLVED:
        _board.handleChainSolved(innerMsg as MsgChainSolved);
        break;
      case MSG_CHAIN_END:
        _board.handleChainEnd(innerMsg);
        _sound.playChainEnd();
        break;
      case MSG_SUMMONING:
        final name = _board.handleSummoning(innerMsg);
        _board.addLog('正在召唤 $name。');
        _sound.playSummon();
        break;
      case MSG_SUMMONED:
        _board.handleSummonFinished('召唤');
        break;
      case MSG_SP_SUMMONING:
        final msg = innerMsg as MsgSpSummoning;
        _board.handleSummonPreparing(
          msg.code,
          msg.location,
          actionLabel: '特殊召唤',
        );
        _sound.playSpecialSummon();
        break;
      case MSG_SP_SUMMONED:
        _board.handleSummonFinished('特殊召唤');
        break;
      case MSG_FLIP_SUMMONING:
        final msg = innerMsg as MsgFlipSummoning;
        _board.handleSummonPreparing(
          msg.code,
          msg.location,
          actionLabel: '反转召唤',
        );
        _sound.playFlipSummon();
        break;
      case MSG_FLIP_SUMMONED:
        _board.handleSummonFinished('反转召唤');
        break;
      case MSG_BATTLE:
        _board.handleBattle(innerMsg as MsgBattle);
        _sound.playBattle();
        break;
      case MSG_HINT:
        _board.handleHint(innerMsg as MsgHint);
        break;
      case MSG_WIN:
        _board.handleWin(innerMsg as MsgWin);
        _sound.playDuelWin();
        break;
      case MSG_RETRY:
        _board.addLog('操作无效，请重新选择。');
        break;
      case MSG_SHUFFLE_DECK:
        _board.handleShuffleDeck(innerMsg);
        _sound.playShuffleDeck();
        break;
      case MSG_BECOME_TARGET:
        _board.handleBecomeTarget(innerMsg as MsgBecomeTarget);
        break;
      case MSG_ATTACK_DISABLE:
        _board.handleAttackDisabled();
        break;
      case MSG_DAMAGE_STEP_START:
        _board.handleDamageStepStart();
        _sound.playDamageStep();
        break;
      case MSG_DAMAGE_STEP_END:
        _board.handleDamageStepEnd();
        break;
      // 决斗事件 end
      // 决斗场地  start
      case MSG_DRAW:
        {
          final msg = innerMsg as MsgDraw;
          _board.applyDraw(msg);
          _board.addLog('${_board.playerNameOf(msg.player)} 抽了 ${msg.count} 张卡。');
        }
        _sound.playCardDraw();
        break;
      case MSG_UPDATE_DATA:
        _board.applyUpdateData(innerMsg as MsgUpdateData);
        break;
      case MSG_UPDATE_CARD:
        _board.applyUpdateCard(innerMsg as MsgUpdateCard);
        break;
      case MSG_RELOAD_FIELD:
        _board.applyReloadField(innerMsg as MsgReloadField);
        break;
      case MSG_MOVE:
        _board.applyMove(innerMsg as MsgMove);
        _sound.playCardDestroy();
        break;
      case MSG_FIELD_DISABLED:
        {
          final msg = innerMsg as MsgFieldDisabled;
          _board.applyFieldDisabled(msg);
          _board.addLog('区域禁用状态已更新。');
        }
        break;
      case MSG_POS_CHANGE:
        final card = _board.handlePosChange(innerMsg);
        _board.addLog('${card?.name} 表示形式变更。');
        _sound.playPosChange();
        break;
      case MSG_SHUFFLE_HAND:
        _board.applyShuffleHand(innerMsg as MsgShuffleHand);
        break;
      case MSG_SET:
        _board.handleSet(innerMsg as MsgSet);
        _sound.playSetCard();
        break;
      // 决斗场地  end
      // 选择事件  start
      case MSG_SELECT_IDLE_CMD:
        _select.applyIdleCmd(innerMsg as MsgSelectIdleCmd);
        break;
      case MSG_SELECT_BATTLE_CMD:
        _select.applyBattleCmd(innerMsg as MsgSelectBattleCmd);
        break;
      case MSG_SELECT_CARD:
        _select.applySelectCard(innerMsg as MsgSelectCard);
        break;
      case MSG_SELECT_CHAIN:
        _select.applySelectChain(innerMsg as MsgSelectChain);
        break;
      case MSG_SELECT_EFFECTYN:
        _select.applySelectEffectYn(innerMsg as MsgSelectEffectYn);
        break;
      case MSG_SELECT_YES_NO:
        _select.applySelectYesNo(innerMsg as MsgSelectYesNo);
        break;
      case MSG_SELECT_PLACE:
        _select.applySelectPlace(innerMsg as MsgSelectPlace);
        break;
      case MSG_SELECT_POSITION:
        _select.applySelectPosition(innerMsg as MsgSelectPosition);
        break;
      case MSG_SELECT_TRIBUTE:
        _select.applySelectTribute(innerMsg as MsgSelectTribute);
        break;
      case MSG_SELECT_COUNTER:
        _select.applySelectCounter(innerMsg as MsgSelectCounter);
        break;
      case MSG_SELECT_SUM:
        _select.applySelectSum(innerMsg as MsgSelectSum);
        break;
      case MSG_SORT_CARD:
        _select.applySortCard(innerMsg as MsgSortCard);
        break;
      case MSG_SELECT_OPTION:
        _select.applySelectOption(innerMsg as MsgSelectOption);
        break;
      case MSG_ANNOUNCE_CARD:
        _select.applyAnnounceCard(innerMsg as MsgAnnounceCard);
        break;
      case MSG_SELECT_UNSELECT_CARD:
        _select.applySelectUnselectCard(innerMsg as MsgSelectUnselectCard);
        break;
      case MSG_SELECT_DISFIELD:
        _select.applySelectDisfield(innerMsg as MsgSelectPlace);
        break;
      // 选择事件  end
      case MSG_TOSS_COIN:
        _sound.playCoinToss();
        break;
      case MSG_TOSS_DICE:
        _sound.playDice();
        break;
      default:
        console.log('Unhandled  event: ${gameMsg.func}');
    }
    _board.emit();
    _select.emit();
    _confirm.emit();
  }

  /// MSG_CONFIRM_* 的呈现分发：先同步卡数据与战报（对局事实），
  /// 再按消息类型与卡所在区域选择高亮/浮动预览/确认面板。
  void _handleConfirmCards(int func, MsgConfirmCards msg) {
    _board.preloadCardInfos(msg.cards.map((card) => card.code));
    for (final card in msg.cards) {
      _board.syncConfirmedCard(card);
    }
    final owner = msg.player == _board.myController ? '我方' : '对方';
    final zoneLabel = switch (func) {
      MSG_CONFIRM_DECKTOP => '卡组顶部卡片',
      MSG_CONFIRM_EXTRATOP => '额外卡组顶部卡片',
      _ => '卡片',
    };
    _board.addLog('$owner 确认了 $zoneLabel 的 ${msg.count} 张卡。');
    if (msg.skipPanel == 1) {
      return;
    }

    _confirm.cancelTimer();

    if (func == MSG_CONFIRM_DECKTOP) {
      _confirm.showFloatPreview(
        msg.cards.map((card) => card.code).toList(),
        msg.player,
        isExtra: false,
      );
      return;
    }

    if (func == MSG_CONFIRM_EXTRATOP) {
      _confirm.showFloatPreview(
        msg.cards.map((card) => card.code).toList(),
        msg.player,
        isExtra: true,
      );
      return;
    }

    final fieldSlotKeys = <String>{};
    final handSequences = <int>{};
    final panelCodes = <int>{};

    for (final card in msg.cards) {
      final location = card.location;
      final controller = card.controller;
      final sequence = card.sequence;

      if ((location & (CARD_ZONE_DECK | CARD_ZONE_EXTRA)) != 0) {
        final isDeck = (location & CARD_ZONE_DECK) != 0;
        if (msg.count == 1) {
          _confirm.showFloatPreview(
            msg.cards.map((card) => card.code).toList(),
            msg.player,
            isExtra: !isDeck,
          );
          return;
        }
        panelCodes.add(card.code);
      } else if (_board.isOnFieldLocation(location)) {
        final key = _board.fieldCardKey(controller, location, sequence);
        final current = _board.fieldCards[key];
        if (current != null && (current.position & POS_FACEUP) == 0) {
          fieldSlotKeys.add(key);
        }
      } else if ((location & CARD_ZONE_HAND) != 0) {
        handSequences.add(sequence);
      }
    }

    if (fieldSlotKeys.isNotEmpty || handSequences.isNotEmpty) {
      _confirm.scheduleConfirmedReveal(
        fieldSlotKeys: fieldSlotKeys,
        handSequences: handSequences,
        handOwner: msg.player,
        panelCodes: panelCodes,
        title: '$owner 展示的卡片',
      );
    } else if (panelCodes.isNotEmpty) {
      _confirm.showConfirmPanel(
        title: '$owner 展示的卡片',
        codes: panelCodes.toList(),
      );
    }
  }

  // ---- 本地交互（跨状态编排） ----

  /// 检视卡片：触发卡信息加载并打开详情抽屉。
  /// 主动加载避免非常规路径（连锁确认等）得知 code 的卡
  /// 一直停留在 Card #xxxx 占位。
  void _inspectCardMut(
    int? code, {
    bool preserveHandSelection = false,
    bool preserveZoneBrowser = false,
  }) {
    if (code == null || code <= 0) return;
    unawaited(_board.ensureCardInfo(code));
    _overlay.applyInspect(
      code,
      _board.getCardInfo(code),
      preserveHandSelection: preserveHandSelection,
      preserveZoneBrowser: preserveZoneBrowser,
    );
    console.log(
      'inspectCard: code=$code, info=${_overlay.inspectedCardInfo?.name}',
    );
  }

  void inspectCard(int code) {
    if (code <= 0) return;
    _sound.playDialogOpen();
    _inspectCardMut(code);
  }

  /// 就地选择模式下点击手牌：可选中则按当前选择语义处理，
  /// 否则仅检视卡片详情。
  void handleInlineHandCardTap(int sequence, int code) {
    final index = _select.inlineOptionIndexForHand(sequence);
    if (index == null) {
      _inspectCardMut(code, preserveHandSelection: true);
      _overlay.emit();
      return;
    }
    _applyInlineOptionTap(index, code);
  }

  /// 就地选择模式下点击场上卡：可选中则按当前选择语义处理，
  /// 否则仅检视卡片详情。
  void handleInlineFieldCardTap(FieldCard card) {
    final index = _select.inlineOptionIndexForField(card);
    if (index == null) {
      _inspectCardMut(card.code);
      _overlay.emit();
      return;
    }
    _applyInlineOptionTap(index, card.code);
  }

  void _applyInlineOptionTap(int index, int code) {
    final select = _select.currentSelect;
    if (select == null) return;
    _inspectCardMut(code);
    switch (select.type) {
      case SelectType.chain:
        // 连锁：点卡即发动，响应为选项下标（与 response 一一对应）。
        _select.respondSelectChain(index);
        return;
      case SelectType.unselect:
        // 解除选择：点卡即向服务端切换勾选状态。
        _select.respondSelectUnselectCard(index);
        return;
      default:
        break;
    }
    // 单选：点卡即提交；多选：本地勾选后由确认按钮提交。
    if (select.min == 1 && select.max == 1) {
      _select.respondInlineMulti([index]);
      return;
    }
    _select.toggleInlineOption(index);
  }

  // ---- 手牌 ----

  void handleHandCardTap(int sequence, int code) {
    // 就地选择窗口优先：高亮卡点击即选择/连锁，其余卡仅检视。
    if (_select.inlineSelectActive) {
      handleInlineHandCardTap(sequence, code);
      return;
    }
    unawaited(_board.ensureCardInfo(code));
    _overlay.applyHandCardTap(sequence, code, _board.getCardInfo(code));
  }

  void handleHandCardDoubleTap(int sequence, int code) {
    final action = quickHandActionFor(sequence);
    if (action == null) {
      handleHandCardTap(sequence, code);
      return;
    }
    _overlay.clearSelectionsForHandDoubleTap();
    _select.respondCurrentCommand(action.response);
  }

  void handleFieldCardTap(FieldCard? fieldCard, int? code) {
    // 就地选择窗口优先：高亮卡点击即选择/连锁，其余卡仅检视。
    if (fieldCard != null && _select.inlineSelectActive) {
      handleInlineFieldCardTap(fieldCard);
      return;
    }
    final effectiveCode = code ?? fieldCard?.code;
    if (effectiveCode != null) {
      _inspectCardMut(effectiveCode);
    }
    final actions = fieldCard == null
        ? const <PlaymatResolvedAction>[]
        : fieldActionsForCard(fieldCard);
    console.log(
      'handleFieldCardTap: card='
      '${fieldCard == null ? 'null' : 'code=${fieldCard.code} c=${fieldCard.controller} z=${fieldCard.zone} s=${fieldCard.sequence} pos=${fieldCard.position}'} '
      'actions=[${actions.map((action) => '${action.kind.name}:${action.response}:c=${action.controller}:z=${action.location}:s=${action.sequence}:code=${action.code}').join(', ')}]',
    );
    _overlay.applyFieldCardSelection(
      fieldCard == null || actions.isEmpty ? null : fieldCard,
    );
  }

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
    _sound.playZoneOpen();
    _overlay.openZoneBrowser(zoneKey);
  }

  void closeZoneBrowser() {
    if (!_overlay.closeZoneBrowser()) return;
    _sound.playZoneClose();
  }

  void inspectZoneBrowserCard(int sequence, int code) {
    unawaited(_board.ensureCardInfo(code));
    _overlay.applyZoneBrowserCardInspect(
      sequence,
      code,
      _board.getCardInfo(code),
    );
  }

  void togglePhaseMenu() {
    if (phaseActionsForCurrentWindow().isEmpty) {
      return;
    }
    final next = !_overlay.showPhaseMenu;
    if (next) {
      _sound.playMenuOpen();
    } else {
      _sound.playMenuClose();
    }
    _overlay.setPhaseMenuVisible(next);
  }

  /// 当出现更高优先级的选择窗口（非阶段指令）时，本地弹层应当让位。
  bool get needsHigherPriorityDismiss {
    final hasHigherPriorityOverlay =
        _select.currentSelect != null && !_select.hasPhaseCommandWindow;
    if (!hasHigherPriorityOverlay) {
      return false;
    }
    return _overlay.hasAnyOverlayOpen;
  }

  List<PlaymatResolvedAction> handActionsForCurrentSelection() {
    final selectedSequence = _overlay.selectedHandSequence;
    if (selectedSequence == null ||
        selectedSequence < 0 ||
        selectedSequence >= _board.selfHand.length) {
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

  PlaymatResolvedAction? quickHandActionFor(int sequence) {
    final actions = _handActionsForSequence(sequence);
    if (actions.length != 1) {
      return null;
    }
    return actions.first;
  }

  List<PlaymatResolvedAction> _handActionsForSequence(int sequence) {
    final actions = _resolveHandActions(sequence);
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

  pkg.CardInfo? cardInfoForHandSequence(int sequence) {
    if (sequence < 0 || sequence >= _board.selfHand.length) {
      return null;
    }
    return _board.getCardInfo(_board.selfHand[sequence]);
  }

  List<PlaymatResolvedAction> phaseActionsForCurrentWindow() {
    return _resolvePhaseActions();
  }

  List<PlaymatResolvedAction> fieldActionsForCard(FieldCard fieldCard) {
    final actions = _resolveFieldActions(
      fieldCard.controller,
      fieldCard.zone,
      fieldCard.sequence,
      fieldCard.code,
    );
    if (actions.isEmpty &&
        _select.hasIdleCommandWindow &&
        _select.ownsCurrentWindow(_board.myController)) {
      final candidateDebug = _select.selectedIdleActions
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

  List<PlaymatResolvedAction> _resolveHandActions(int sequence) {
    if (!_select.hasIdleCommandWindow ||
        !_select.ownsCurrentWindow(_board.myController)) {
      return const [];
    }

    return _select.selectedIdleActions
        .where(
          (action) =>
              action.controller == _board.myController &&
              action.location == CARD_ZONE_HAND &&
              action.locationSequence == sequence,
        )
        .map(_resolveIdleAction)
        .toList(growable: false);
  }

  List<PlaymatResolvedAction> _resolveFieldActions(
    int controller,
    int location,
    int sequence,
    int? code,
  ) {
    if (!_select.ownsCurrentWindow(_board.myController)) {
      return const [];
    }

    final actions = <PlaymatResolvedAction>[];
    if (_select.hasIdleCommandWindow) {
      final idleActions = _select.selectedIdleActions
          .where(
            (action) =>
                action.controller == controller && action.location == location,
          )
          .toList(growable: false);
      final exactIdleActions = idleActions
          .where((action) => action.locationSequence == sequence)
          .map(_resolveIdleAction);
      actions.addAll(exactIdleActions);
      if (actions.isEmpty && code != null && code > 0) {
        final codeMatchedActions = idleActions
            .where((action) => action.code == code)
            .map(_resolveIdleAction)
            .toList(growable: false);
        if (codeMatchedActions.length == 1) {
          actions.addAll(codeMatchedActions);
        }
      }
    }
    if (_select.hasBattleCommandWindow) {
      actions.addAll(
        _select.selectedBattleActions
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
  ) {
    if (!_select.ownsCurrentWindow(_board.myController) ||
        !_isBrowserZone(location)) {
      return const [];
    }

    final actions = <PlaymatResolvedAction>[];
    if (_select.hasIdleCommandWindow) {
      actions.addAll(
        _select.selectedIdleActions
            .where(
              (action) =>
                  action.code == code &&
                  action.controller == controller &&
                  action.location == location &&
                  (sequence == null || action.locationSequence == sequence),
            )
            .map(_resolveIdleAction),
      );
    }
    if (_select.hasBattleCommandWindow) {
      actions.addAll(
        _select.selectedBattleActions
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

  List<PlaymatResolvedAction> _resolvePhaseActions() {
    if (!_select.ownsCurrentWindow(_board.myController)) {
      return const [];
    }

    if (_select.hasIdleCommandWindow) {
      return [
        if (_select.enableBp)
          const PlaymatResolvedAction(
            label: '进入战斗阶段',
            response: 6,
            kind: PlaymatResolvedActionKind.toBattlePhase,
          ),
        if (_select.enableEp)
          const PlaymatResolvedAction(
            label: '结束回合',
            response: 7,
            kind: PlaymatResolvedActionKind.toEndPhase,
          ),
      ];
    }

    if (_select.hasBattleCommandWindow) {
      return [
        if (_select.enableM2)
          const PlaymatResolvedAction(
            label: '进入主要阶段2',
            response: 2,
            kind: PlaymatResolvedActionKind.toMainPhase2,
          ),
        if (_select.enableEp)
          const PlaymatResolvedAction(
            label: '结束回合',
            response: 3,
            kind: PlaymatResolvedActionKind.toEndPhase,
          ),
      ];
    }

    return const [];
  }

  PlaymatResolvedAction _resolveIdleAction(IdleAction action) {
    return PlaymatResolvedAction(
      label: action.label(_board.myController),
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

  static bool _isBrowserZone(int location) {
    return location == CARD_ZONE_GRAVE ||
        location == CARD_ZONE_REMOVED ||
        location == CARD_ZONE_EXTRA;
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

  // ---- 菜单条目构建 ----

  List<ActionMenuEntry> buildHandActionMenuEntries() {
    final selectedSequence = _overlay.selectedHandSequence;
    final cardInfo = selectedSequence == null
        ? null
        : cardInfoForHandSequence(selectedSequence);
    return handActionsForCurrentSelection()
        .map(
          (action) => ActionMenuEntry(
            label: _resolvedActionLabel(action, cardInfo),
            onTap: () {
              _overlay.clearHandSelectionAndClosePhaseMenu();
              _select.respondCurrentCommand(action.response);
            },
          ),
        )
        .toList();
  }

  List<ActionMenuEntry> buildPhaseActionMenuEntries() {
    return phaseActionsForCurrentWindow()
        .map(
          (action) => ActionMenuEntry(
            label: action.label,
            onTap: () {
              _overlay.closePhaseMenu();
              _select.respondCurrentCommand(action.response);
            },
          ),
        )
        .toList(growable: false);
  }

  List<ActionMenuEntry> buildFieldActionEntries() {
    final fieldCard = _overlay.selectedFieldCard;
    if (fieldCard == null) {
      return const [];
    }
    final cardInfo = _board.getCardInfo(fieldCard.code);
    console.log('dispatchResolvedAction: $cardInfo}');
    return fieldActionsForCard(fieldCard)
        .map(
          (action) => ActionMenuEntry(
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
    console.log('dispatchResolvedAction: ${action.kind} ${action.label}');
    if (!_select.respondCurrentCommand(action.response)) {
      return;
    }
    _overlay.clearAfterResolvedAction(closeZoneBrowser: closeZoneBrowser);
  }

  List<ZoneBrowserCardEntry> zoneBrowserEntriesFor(String zoneKey) {
    final sequenceToCode = <int, int>{};
    final codes = _board.getZoneCodes(zoneKey);
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
        _select.hasIdleCommandWindow &&
        _select.ownsCurrentWindow(_board.myController)) {
      for (final action in _select.selectedIdleActions) {
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

  List<ActionMenuEntry> zoneBrowserActionsForSelection(
    String zoneKey,
    List<ZoneBrowserCardEntry> entries,
  ) {
    final selectedSequence = _overlay.selectedZoneBrowserSequence;
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

    return _resolveZoneActions(
          controller,
          location,
          entry.code,
          selectedSequence,
        )
        .map((action) {
          final cardInfo = _board.getCardInfo(entry.code);
          return ActionMenuEntry(
            label: _resolvedActionLabel(action, cardInfo),
            onTap: () => dispatchResolvedAction(action, closeZoneBrowser: true),
          );
        })
        .toList(growable: false);
  }

  int hiddenCountForZoneKey(String zoneKey) {
    switch (zoneKey) {
      case 'self_grave':
        return _board.selfGrave;
      case 'opp_grave':
        return _board.oppGrave;
      case 'self_removed':
        return _board.selfRemoved;
      case 'opp_removed':
        return _board.oppRemoved;
      case 'self_extra':
        return _board.selfExtra;
      case 'opp_extra':
        return _board.oppExtra;
      default:
        return 0;
    }
  }

  int? _controllerForZoneKey(String zoneKey) {
    if (zoneKey.startsWith('self_')) return _board.myController;
    if (zoneKey.startsWith('opp_')) return 1 - _board.myController;
    return null;
  }

  int? _locationForZoneKey(String zoneKey) {
    if (zoneKey.endsWith('_grave')) return CARD_ZONE_GRAVE;
    if (zoneKey.endsWith('_removed')) return CARD_ZONE_REMOVED;
    if (zoneKey.endsWith('_extra')) return CARD_ZONE_EXTRA;
    return null;
  }

  // ──────────────────────────────────────────
  // 流订阅
  // ──────────────────────────────────────────

  /// 订阅对局消息流。
  ///
  /// [phaseLabel] 把阶段枚举本地化（l10n 依赖 BuildContext，由页面侧注入），
  /// 用于「xx 开始。」的战报文案；不传则跳过阶段日志。
  void bindServerMessage({String? Function(DuelPhase phase)? phaseLabel}) {
    _phaseSub = _duelService?.onDuelPhaseMessage.listen((phase) {
      // 阶段合法性（enableBp/enableM2/enableEp）只由服务端下发的
      // MSG_SELECT_IDLE_CMD / MSG_SELECT_BATTLE_CMD 驱动，这里不做本地推断。
      _board.setPhaseFromStream(phase, phaseLabel?.call(phase));
    });
    _msgSub = _duelService?.onServerMessage.listen((msg) {
      handleServerMessage(msg);
    });
  }
}

/// 对局战场协调器的 provider。
///
/// 四个子状态 provider（duelFieldProvider / selectWindowProvider /
/// cardConfirmProvider / fieldOverlayProvider）在房间 ProviderScope 内
/// override 后，本 provider 以 `Provider<DuelFieldStore>` 持有 [Ref]，
/// 读取全部子状态并做跨状态编排；`ref.onDispose` 负责离开房间时
/// 取消流订阅，子状态内定时器由各自 Notifier 的 onDispose 回收。
final duelFieldStoreProvider = Provider<DuelFieldStore>(createDuelFieldStore);

/// 供房间 ProviderScope override 复用的创建函数。
DuelFieldStore createDuelFieldStore(Ref ref) {
  final store = DuelFieldStore(ref)..bind(ref.read(duelServiceProvider));
  ref.onDispose(store.dispose);
  return store;
}
