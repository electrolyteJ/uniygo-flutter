import 'dart:async';
import 'dart:developer' as console;
import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/BattleAction.dart';
import '../models/ChainLink.dart';
import '../models/ChatMessage.dart';
import '../models/duel_board_state.dart';
import '../models/duel_event.dart';
import '../models/DuelPhase.dart';
import '../models/FieldCard.dart';
import '../models/IdleAction.dart';
import '../models/duel_selection_state.dart';
import '../models/SelectState.dart';
import '../models/deck_model.dart';
import '../service_singleton.dart';
import '../services/deck_service.dart';
import 'duel_board_controller.dart';
import '../eventbus/duel_event_mapper.dart';
import 'duel_selection_controller.dart';
import 'package:ygo_card/card_info.dart' as pkg;
// ── DuelRoomState ──

class DuelRoomState extends ChangeNotifier {
  static const _autoHandPrefKey = 'duel.auto_hand_enabled';
  static const _autoTurnOrderPrefKey = 'duel.auto_turn_order_enabled';

  // === 等待房间字段 (from RoomStore) ===
  RoomStage stage = const RoomNotJoined();
  SelfType selfType = SelfType.unknown;
  bool isHost = false;
  List<RoomPlayer> players = [];
  int observerCount = 0;
  int? myHandResult;
  int? opponentHandResult;
  bool? isFirstTurn;
  RoomOptions? roomOptions;
  List<ChatMessage> chatMessages = [];
  List<String> duelLogs = []; // 添加决斗日志
  String? errorMessage;
  String? selectedDeckName;
  List<DeckMeta> availableDecks = [];
  bool autoHandEnabled = false;
  bool autoTurnOrderEnabled = false;
  // === 决斗字段 ===
  final DuelBoardState board = DuelBoardState();

  /// 卡片信息缓存：code → CardInfo（从本地 SQLite 查询）
  final Map<int, pkg.CardInfo> _cardInfoCache = {};
  final DuelSelectionState selection = DuelSelectionState();

  Map<String, FieldCard> get fieldCards => board.fieldCards;
  List<int> get selfHand => board.selfHand;
  List<int> get opponentHand => board.opponentHand;
  List<int> get selfGraveCodes => board.selfGraveCodes;
  List<int> get opponentGraveCodes => board.opponentGraveCodes;
  List<int> get selfRemovedCodes => board.selfRemovedCodes;
  List<int> get opponentRemovedCodes => board.opponentRemovedCodes;
  List<int> get selfExtraCodes => board.selfExtraCodes;
  List<int> get opponentExtraCodes => board.opponentExtraCodes;
  int get selfDeck => board.selfDeck;
  set selfDeck(int value) => board.selfDeck = value;
  int get selfExtra => board.selfExtra;
  set selfExtra(int value) => board.selfExtra = value;
  int get selfGrave => board.selfGrave;
  set selfGrave(int value) => board.selfGrave = value;
  int get selfRemoved => board.selfRemoved;
  set selfRemoved(int value) => board.selfRemoved = value;
  int get oppDeck => board.oppDeck;
  set oppDeck(int value) => board.oppDeck = value;
  int get oppExtra => board.oppExtra;
  set oppExtra(int value) => board.oppExtra = value;
  int get oppGrave => board.oppGrave;
  set oppGrave(int value) => board.oppGrave = value;
  int get oppRemoved => board.oppRemoved;
  set oppRemoved(int value) => board.oppRemoved = value;
  int get selfLp => board.selfLp;
  set selfLp(int value) => board.selfLp = value;
  int get opponentLp => board.opponentLp;
  set opponentLp(int value) => board.opponentLp = value;
  int get currentPlayer => board.currentPlayer;
  set currentPlayer(int value) => board.currentPlayer = value;
  int get phase => board.phase;
  set phase(int value) => board.phase = value;
  int get turnCount => board.turnCount;
  set turnCount(int value) => board.turnCount = value;
  int get myController => board.myController;
  set myController(int value) => board.myController = value;
  List<DuelPhase> get phases => board.phases;
  set phases(List<DuelPhase> value) => board.phases = value;
  String? get lastSummonKey => board.lastSummonKey;
  set lastSummonKey(String? value) => board.lastSummonKey = value;
  String? get lastAttackFrom => board.lastAttackFrom;
  set lastAttackFrom(String? value) => board.lastAttackFrom = value;
  String? get lastAttackTo => board.lastAttackTo;
  set lastAttackTo(String? value) => board.lastAttackTo = value;
  List<ChainLink> get chains => board.chains;
  set chains(List<ChainLink> value) => board.chains = value;
  String? get inspectedZoneKey => board.inspectedZoneKey;
  set inspectedZoneKey(String? value) => board.inspectedZoneKey = value;

  List<IdleAction> get selectedIdleActions => selection.selectedIdleActions;
  set selectedIdleActions(List<IdleAction> value) => selection.selectedIdleActions = value;
  List<BattleAction> get selectedBattleActions => selection.selectedBattleActions;
  set selectedBattleActions(List<BattleAction> value) => selection.selectedBattleActions = value;
  bool get enableBp => selection.enableBp;
  set enableBp(bool value) => selection.enableBp = value;
  bool get enableM2 => selection.enableM2;
  set enableM2(bool value) => selection.enableM2 = value;
  bool get enableEp => selection.enableEp;
  set enableEp(bool value) => selection.enableEp = value;
  SelectState? get currentSelect => selection.currentSelect;
  set currentSelect(SelectState? value) => selection.currentSelect = value;
  bool get isWaitingForInput => selection.isWaitingForInput;

  // === 共享 ===
  IDuelService? _service;
  StreamSubscription<YgoStocMsg>? _msgSub;
  late final DuelBoardController _boardController = DuelBoardController(
    board: board,
    ensureCardInfo: _ensureCardInfo,
    getCardInfo: getCardInfo,
  );
  late final DuelSelectionController _selectionController =
      DuelSelectionController(selection: selection);
  final DuelEventMapper _eventMapper = const DuelEventMapper();

  // ══════════════════════════════════════════
  // 等待房间方法 (from RoomStore)
  // ══════════════════════════════════════════

  DuelRoomState() {
    unawaited(_loadPreferences());
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    autoHandEnabled = prefs.getBool(_autoHandPrefKey) ?? false;
    autoTurnOrderEnabled = prefs.getBool(_autoTurnOrderPrefKey) ?? false;
    notifyListeners();
  }

  bool get isSelfReady {
    final mySlot = selfType.slot;
    if (mySlot < 0 || mySlot > 1) {
      return false;
    }
    return players.any((player) => player.pos == mySlot && player.ready);
  }

  Future<void> setAutoHandEnabled(bool value) async {
    if (isSelfReady && value != autoHandEnabled) {
      return;
    }
    autoHandEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoHandPrefKey, value);
    notifyListeners();
  }

  Future<void> setAutoTurnOrderEnabled(bool value) async {
    if (isSelfReady && value != autoTurnOrderEnabled) {
      return;
    }
    autoTurnOrderEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoTurnOrderPrefKey, value);
    notifyListeners();
  }

  void addChat(int playerIndex, String name, String message) {
    chatMessages.add(
      ChatMessage(
        playerIndex: playerIndex,
        name: name,
        message: message,
        time: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void addLog(String log) {
    duelLogs.add(log);
    notifyListeners();
  }

  void setError(String message) {
    errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void ready(int handValue) {
    stage = RoomReady();
    notifyListeners();
  }

  void unready(int handValue) {
    stage = RoomUnready();
    notifyListeners();
  }

  void setHandResult(int handValue) {
    stage = RoomSelectingHand();
    myHandResult = handValue;
    notifyListeners();
  }

  void setTpResult(bool first) {
    stage = RoomInDuel(isFirstTurn: first);
    isFirstTurn = first;
    notifyListeners();
  }

  void enableTurnOrderSelection() {
    // if (stage is RoomSelectingHand) {
    //   stage = RoomSelectingTurn(myHand: myHandResult, opponentHand: opponentHandResult);
    // }
    notifyListeners();
  }

  Future<void> loadDecks() async {
    final deckService = DeckService();
    final builtinDecks = await deckService.loadBuiltinDecks();
    final userDecks = await deckService.loadDeckList();
    final decks = [...builtinDecks, ...userDecks];
    availableDecks = decks;
    console.log(
      'Loaded ${decks.length} decks: ${decks.map((d) => d.deckName).join(', ')}',
    );
    if (selectedDeckName == null && decks.isNotEmpty) {
      selectedDeckName = decks.first.deckName;
    }
    notifyListeners();
  }

  void selectDeck(String deckName) {
    selectedDeckName = deckName;
    notifyListeners();
  }

  // ══════════════════════════════════════════
  // 决斗方法 (from DuelStore)
  // ══════════════════════════════════════════

  void bind(IDuelService service) {
    _service = service;
    _msgSub?.cancel();
    _msgSub = service.onServerMessage.listen(_onMessage);
  }

  void unbind() {
    _msgSub?.cancel();
    _msgSub = null;
    _service = null;
  }

  void respondIdleCmd(int sequence) {
    _service?.playGameResponse(CtosGameMsgResponse.selectIdleCmd(sequence));
    clearSelect();
  }

  void respondBattleCmd(int sequence) {
    _service?.playGameResponse(CtosGameMsgResponse.selectBattleCmd(sequence));
    clearSelect();
  }

  void respondSelectCard(List<int> sequences) {
    _service?.playGameResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSelectChain(int sequence) {
    _service?.playGameResponse(CtosGameMsgResponse.selectSingle(sequence));
    clearSelect();
  }

  void respondSelectEffectYn(bool yes) {
    _service?.playGameResponse(CtosGameMsgResponse.selectEffectYn(yes ? 1 : 0));
    clearSelect();
  }

  void respondSelectYesNo(bool yes) {
    _service?.playGameResponse(CtosGameMsgResponse.selectEffectYn(yes ? 1 : 0));
    clearSelect();
  }

  void respondSelectPosition(int position) {
    _service?.playGameResponse(CtosGameMsgResponse.selectPosition(position));
    clearSelect();
  }

  void respondSelectOption(int sequence) {
    _service?.playGameResponse(CtosGameMsgResponse.selectOption(sequence));
    clearSelect();
  }

  void respondSelectPlace(int player, int zone, int sequence) {
    _service?.playGameResponse(
      CtosGameMsgResponse.selectPlace(
        CtosSelectPlace(player: player, zone: zone, sequence: sequence),
      ),
    );
    clearSelect();
  }

  void respondSelectTribute(List<int> sequences) {
    _service?.playGameResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSelectCounter(List<int> values) {
    _service?.playGameResponse(CtosGameMsgResponse.selectCounter(values));
    clearSelect();
  }

  void respondSelectSum(List<int> sequences) {
    _service?.playGameResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSortCard(List<int> indices) {
    _service?.playGameResponse(CtosGameMsgResponse.sortCard(indices));
    clearSelect();
  }

  void setFieldCard(FieldCard card) {
    fieldCards[card.key] = card;
    notifyListeners();
  }

  /// 获取卡片信息（优先从缓存读取，未命中则异步查 DB 并缓存）
  pkg.CardInfo? getCardInfo(int code) => _cardInfoCache[code];

  /// 异步预加载卡片信息到缓存
  Future<void> _ensureCardInfo(int code) async {
    if (_cardInfoCache.containsKey(code)) return;
    try {
      final info = await ServiceSingleton.instance.cardService.getCard(code);
      if (info != null) {
        _cardInfoCache[code] = info;
      }
    } catch (e) {
      console.log('Failed to load card info for $code: $e');
    }
  }

  void removeFieldCard(int controller, int zone, int sequence) {
    fieldCards.remove('${controller}_${zone}_$sequence');
    notifyListeners();
  }

  void setSelect(SelectState select) {
    _selectionController.setSelect(select);
    notifyListeners();
  }

  void clearSelect() {
    _selectionController.clearSelect();
    notifyListeners();
  }

  List<int> getZoneCodes(String zoneKey) {
    switch (zoneKey) {
      case 'self_grave':
        return selfGraveCodes;
      case 'opp_grave':
        return opponentGraveCodes;
      case 'self_removed':
        return selfRemovedCodes;
      case 'opp_removed':
        return opponentRemovedCodes;
      case 'self_extra':
        return selfExtraCodes;
      case 'opp_extra':
        return opponentExtraCodes;
      default:
        return const [];
    }
  }

  void inspectZone(String zoneKey) {
    inspectedZoneKey = zoneKey;
    notifyListeners();
  }

  void clearInspectedZone() {
    inspectedZoneKey = null;
    notifyListeners();
  }

  void updateFromStart({
    required int selfLp,
    required int opponentLp,
    required int selfDeck,
    required int selfExtra,
    required int oppDeck,
    required int oppExtra,
  }) {
    this.selfLp = selfLp;
    this.opponentLp = opponentLp;
    this.selfDeck = selfDeck;
    this.selfExtra = selfExtra;
    this.oppDeck = oppDeck;
    this.oppExtra = oppExtra;
    notifyListeners();
  }

  void reset() {
    // 等待房间重置
    stage = const RoomNotJoined();
    selfType = SelfType.unknown;
    isHost = false;
    players = [];
    observerCount = 0;
    myHandResult = null;
    opponentHandResult = null;
    isFirstTurn = null;
    roomOptions = null;
    chatMessages = [];
    duelLogs = [];
    errorMessage = null;
    selectedDeckName = null;
    availableDecks = [];

    // 决斗重置
    unbind();
    board.reset();
    selection.reset();

    notifyListeners();
  }

  // ══════════════════════════════════════════
  // 消息处理 (from DuelStore)
  // ══════════════════════════════════════════

  void _onMessage(YgoStocMsg msg) {
    switch (msg.protoId) {
      case MSG_SHUFFLE_DECK:
        console.log('Received shuffle deck message: $msg');
        return;
      default:
        break;
    }
    final event = _eventMapper.map(msg);
    if (event == null) return;
    _onEvent(event);
    notifyListeners();
  }

  void _onEvent(DuelEvent event) {
    switch (event) {
      case DuelIgnoredEvent():
        return;
      case DuelFlowMessageEvent(:final func, :final innerMsg):
        switch (func) {
          case MSG_START:
            _handleStart(innerMsg);
            break;
          case MSG_NEW_TURN:
            _handleNewTurn(innerMsg);
            break;
          case MSG_NEW_PHASE:
            _handleNewPhase(innerMsg);
            break;
          case MSG_WAITING:
            _handleWaiting(innerMsg as MsgWait);
            break;
          case MSG_ATTACK:
            _handleAttack(innerMsg);
            break;
          case MSG_DAMAGE:
            _handleDamage(innerMsg);
            break;
          case MSG_PAY_LP_COST:
            _handlePayLife(innerMsg);
            break;
          case MSG_CHAINING:
            _handleChaining(innerMsg);
            break;
          case MSG_CHAIN_END:
            _handleChainEnd(innerMsg);
            break;
          case MSG_SUMMONING:
            _handleSummoning(innerMsg);
            break;
          case MSG_BATTLE:
            _handleBattle(innerMsg as MsgBattle);
            break;
          case MSG_HINT:
            final msg = innerMsg as MsgHint;
            console.log(
              'MSG_HINT received, but no handler implemented yet. $msg',
            );
            break;
          case MSG_WIN:
            final msg = innerMsg as MsgWin;
            console.log(
              'MSG_WIN received, but no handler implemented yet. $msg',
            );
            break;
          default:
            console.log('Unhandled flow event: $func');
        }
        return;
      case DuelBoardMessageEvent(:final func, :final innerMsg):
        switch (func) {
          case MSG_DRAW:
            _handleDraw(innerMsg);
            break;
          case MSG_UPDATE_DATA:
            _handleUpdateData(innerMsg as MsgUpdateData);
            break;
          case MSG_UPDATE_CARD:
            _handleUpdateCard(innerMsg as MsgUpdateCard);
            break;
          case MSG_RELOAD_FIELD:
            _handleReloadField(innerMsg as MsgReloadField);
            break;
          case MSG_MOVE:
            _handleMove(innerMsg);
            break;
          case MSG_FIELD_DISABLED:
            _handleFieldDisabled(innerMsg as MsgFieldDisabled);
            break;
          case MSG_POS_CHANGE:
            _handlePosChange(innerMsg);
            break;
          case MSG_SHUFFLE_HAND:
            _handleShuffleHand(innerMsg);
            break;
          case MSG_SET:
            final msg = innerMsg as MsgSet;
            console.log(
              'MSG_SET received, but no handler implemented yet. $msg',
            );
            break;
          default:
            console.log('Unhandled board event: $func');
        }
        return;
      case DuelSelectionMessageEvent(:final func, :final innerMsg):
        switch (func) {
          case MSG_SELECT_IDLE_CMD:
            _handleSelectIdleCmd(innerMsg);
            break;
          case MSG_SELECT_BATTLE_CMD:
            _handleSelectBattleCmd(innerMsg);
            break;
          case MSG_SELECT_CARD:
          case MSG_SELECT_CHAIN:
          case MSG_SELECT_EFFECTYN:
          case MSG_SELECT_YES_NO:
          case MSG_SELECT_PLACE:
            _handleSelectGeneric(func, innerMsg);
            break;
          case MSG_SELECT_POSITION:
            _handleSelectPosition(innerMsg as MsgSelectPosition);
            break;
          case MSG_SELECT_TRIBUTE:
            _handleSelectTribute(innerMsg as MsgSelectTribute);
            break;
          case MSG_SELECT_COUNTER:
            _handleSelectCounter(innerMsg as MsgSelectCounter);
            break;
          case MSG_SELECT_SUM:
            _handleSelectSum(innerMsg as MsgSelectSum);
            break;
          case MSG_SORT_CARD:
            _handleSortCard(innerMsg as MsgSortCard);
            break;
          case MSG_SELECT_OPTION:
            _handleSelectOption(innerMsg);
            break;
          case MSG_SELECT_UNSELECT_CARD:
            _handleSelectUnselectCard(innerMsg);
            break;
          case MSG_SELECT_DISFIELD:
            _handleSelectDisfield(innerMsg);
            break;
          default:
            console.log('Unhandled selection event: $func');
        }
    }
  }

  void _handleStart(dynamic data) {
    final msg = data as MsgStart;
    final isFirst = msg.isFirst;
    myController = isFirst ? 0 : 1;

    selfLp = isFirst ? msg.life1 : msg.life2;
    opponentLp = isFirst ? msg.life2 : msg.life1;

    selfDeck = isFirst ? msg.deckSize1 : msg.deckSize2;
    selfExtra = isFirst ? msg.extraSize1 : msg.extraSize2;
    oppDeck = isFirst ? msg.deckSize2 : msg.deckSize1;
    oppExtra = isFirst ? msg.extraSize2 : msg.extraSize1;

    selfHand.clear();
    opponentHand.clear();
    fieldCards.clear();

    turnCount = 1;
    phases = [];
    addLog('决斗开始。');
  }

  void _handleNewTurn(dynamic data) {
    final msg = data as MsgNewTurn;
    currentPlayer = msg.player;
    turnCount++;
    phases = [];
    final name = players
        .firstWhere(
          (p) => p.pos == msg.player,
          orElse: () => RoomPlayer(name: '玩家${msg.player}', pos: msg.player),
        )
        .name;
    addLog('$name 的回合。');
  }

  void _handleNewPhase(dynamic data) {
    final msg = data as MsgNewPhase;
    phase = msg.phase;

    String phaseName = '';
    DuelPhase duelPhase;
    switch (msg.phase) {
      case PHASE_DRAW:
        duelPhase = DuelPhase.dp;
        phaseName = '抽卡阶段';
        break;
      case PHASE_STANDBY:
        duelPhase = DuelPhase.sp;
        phaseName = '准备阶段';
        break;
      case PHASE_MAIN1:
        duelPhase = DuelPhase.m1;
        phaseName = '主要阶段 1';
        enableBp = true;
        enableM2 = false;
        enableEp = true;
        break;
      case PHASE_BATTLE_START:
      case PHASE_BATTLE_STEP:
      case PHASE_DAMAGE:
      case PHASE_DAMAGE_CAL:
      case PHASE_BATTLE:
        duelPhase = DuelPhase.bp;
        phaseName = '战斗阶段';
        break;
      case PHASE_MAIN2:
        duelPhase = DuelPhase.m2;
        phaseName = '主要阶段 2';
        enableBp = false;
        enableM2 = false;
        enableEp = true;
        break;
      case PHASE_END:
        duelPhase = DuelPhase.ep;
        phaseName = '结束阶段';
        break;
      default:
        duelPhase = DuelPhase.idle;
    }
    phases.add(duelPhase);
    if (phaseName.isNotEmpty) addLog('$phaseName 开始。');
  }

  void _handleDraw(dynamic data) {
    final msg = data as MsgDraw;
    _boardController.applyDraw(msg);
    final name = players
        .firstWhere(
          (p) => p.pos == msg.player,
          orElse: () => RoomPlayer(name: '玩家${msg.player}', pos: msg.player),
        )
        .name;
    addLog('$name 抽了 ${msg.count} 张卡。');
  }

  void _handleUpdateData(MsgUpdateData msg) {
    _boardController.applyUpdateData(msg);
  }

  void _handleUpdateCard(MsgUpdateCard msg) {
    _boardController.applyUpdateCard(msg);
  }

  void _applyUpdateAction({
    required int controller,
    required int zone,
    required int sequence,
    required int position,
    required int code,
    required MsgUpdateAction action,
  }) {
    if (zone & CARD_ZONE_HAND != 0) {
      final hand = controller == myController ? selfHand : opponentHand;
      while (hand.length <= sequence) {
        hand.add(0);
      }
      if (code > 0) {
        hand[sequence] = code;
        if (controller == myController) {
          unawaited(_ensureCardInfo(code));
        }
      }
      return;
    }

    if (zone & CARD_ZONE_DECK != 0) {
      _syncZoneCount(controller, zone, sequence);
      return;
    }

    if (zone & CARD_ZONE_EXTRA != 0) {
      _syncZoneCount(controller, zone, sequence, code: code);
      return;
    }

    if (zone & CARD_ZONE_GRAVE != 0) {
      _syncZoneCount(controller, zone, sequence, code: code);
      return;
    }

    if (zone & CARD_ZONE_REMOVED != 0) {
      _syncZoneCount(controller, zone, sequence, code: code);
      return;
    }

    if (zone & CARD_ZONE_ONFIELD != 0) {
      final key = '${controller}_${zone}_$sequence';
      final current = fieldCards[key];
      final effectiveCode = code > 0 ? code : (current?.code ?? 0);
      final overlayCount = action.overlayCards.isNotEmpty
          ? action.overlayCards.length
          : (current?.overlayCount ?? 0);
      fieldCards[key] = FieldCard(
        code: effectiveCode,
        controller: controller,
        zone: zone,
        sequence: sequence,
        position: position != 0 ? position : (current?.position ?? 0),
        overlayCount: overlayCount,
        disabled: current?.disabled ?? false,
        attack: action.attack ?? current?.attack,
        defense: action.defense ?? current?.defense,
        name: current?.name,
      );
      if (effectiveCode > 0) {
        unawaited(_enrichFieldCard(effectiveCode, controller, zone, sequence));
      }
    }
  }

  void _syncZoneCount(int controller, int zone, int sequence, {int? code}) {
    final nextCount = sequence + 1;
    final isSelf = controller == myController;
    if (zone & CARD_ZONE_DECK != 0) {
      if (isSelf) {
        selfDeck = selfDeck < nextCount ? nextCount : selfDeck;
      } else {
        oppDeck = oppDeck < nextCount ? nextCount : oppDeck;
      }
      return;
    }
    if (zone & CARD_ZONE_EXTRA != 0) {
      _upsertZoneCode(
        isSelf ? selfExtraCodes : opponentExtraCodes,
        sequence,
        code,
      );
      if (isSelf) {
        selfExtra = selfExtra < nextCount ? nextCount : selfExtra;
      } else {
        oppExtra = oppExtra < nextCount ? nextCount : oppExtra;
      }
      if (code != null && code > 0) {
        unawaited(_ensureCardInfo(code));
      }
      return;
    }
    if (zone & CARD_ZONE_GRAVE != 0) {
      _upsertZoneCode(
        isSelf ? selfGraveCodes : opponentGraveCodes,
        sequence,
        code,
      );
      if (isSelf) {
        selfGrave = selfGrave < nextCount ? nextCount : selfGrave;
      } else {
        oppGrave = oppGrave < nextCount ? nextCount : oppGrave;
      }
      if (code != null && code > 0) {
        unawaited(_ensureCardInfo(code));
      }
      return;
    }
    if (zone & CARD_ZONE_REMOVED != 0) {
      _upsertZoneCode(
        isSelf ? selfRemovedCodes : opponentRemovedCodes,
        sequence,
        code,
      );
      if (isSelf) {
        selfRemoved = selfRemoved < nextCount ? nextCount : selfRemoved;
      } else {
        oppRemoved = oppRemoved < nextCount ? nextCount : oppRemoved;
      }
      if (code != null && code > 0) {
        unawaited(_ensureCardInfo(code));
      }
    }
  }

  void _upsertZoneCode(List<int> list, int sequence, int? code) {
    while (list.length <= sequence) {
      list.add(0);
    }
    if (code != null && code > 0) {
      list[sequence] = code;
    }
  }

  void _handleReloadField(MsgReloadField msg) {
    _boardController.applyReloadField(msg);
  }

  void _handleWaiting(MsgWait msg) {
    addLog('等待对手操作。');
  }

  void _handleMove(dynamic data) {
    _boardController.applyMove(data as MsgMove);
  }

  void _removeCardFromLocation(int controller, int location, int sequence) {
    if (location & CARD_ZONE_HAND != 0) {
      if (controller == myController) {
        if (sequence < selfHand.length) {
          selfHand.removeAt(sequence);
        }
      } else {
        if (sequence < opponentHand.length) {
          opponentHand.removeAt(sequence);
        }
      }
    } else if (location & CARD_ZONE_ONFIELD != 0) {
      removeFieldCard(controller, location, sequence);
    } else if (location & CARD_ZONE_GRAVE != 0) {
      if (controller == myController) {
        selfGrave--;
      } else {
        oppGrave--;
      }
    } else if (location & CARD_ZONE_REMOVED != 0) {
      if (controller == myController) {
        selfRemoved--;
      } else {
        oppRemoved--;
      }
    } else if (location & CARD_ZONE_DECK != 0) {
      if (controller == myController) {
        selfDeck--;
      } else {
        oppDeck--;
      }
    } else if (location & CARD_ZONE_EXTRA != 0) {
      if (controller == myController) {
        selfExtra--;
      } else {
        oppExtra--;
      }
    }
  }

  void _addCardToLocation(
    int code,
    int controller,
    int location,
    int sequence,
    int position,
  ) {
    if (location & CARD_ZONE_HAND != 0) {
      if (controller == myController) {
        selfHand.add(code);
      } else {
        opponentHand.add(code);
      }
    } else if (location & CARD_ZONE_ONFIELD != 0) {
      // 先用 code 创建 FieldCard，再异步查 DB 补全 name/atk/def
      setFieldCard(
        FieldCard(
          code: code,
          controller: controller,
          zone: location,
          sequence: sequence,
          position: position,
          disabled: false,
        ),
      );
      unawaited(_enrichFieldCard(code, controller, location, sequence));
    } else if (location & CARD_ZONE_GRAVE != 0) {
      if (controller == myController) {
        selfGrave++;
      } else {
        oppGrave++;
      }
    } else if (location & CARD_ZONE_REMOVED != 0) {
      if (controller == myController) {
        selfRemoved++;
      } else {
        oppRemoved++;
      }
    } else if (location & CARD_ZONE_DECK != 0) {
      if (controller == myController) {
        selfDeck++;
      } else {
        oppDeck++;
      }
    } else if (location & CARD_ZONE_EXTRA != 0) {
      if (controller == myController) {
        selfExtra++;
      } else {
        oppExtra++;
      }
    }
  }

  /// 异步从 DB 查询卡片信息，补全 FieldCard 的 name/attack/defense
  Future<void> _enrichFieldCard(
    int code,
    int controller,
    int location,
    int sequence,
  ) async {
    await _ensureCardInfo(code);
    _boardController.enrichFieldCard(code, controller, location, sequence);
    notifyListeners();
  }

  void _handleAttack(dynamic data) {
    final msg = data as MsgAttack;
    lastAttackFrom =
        '${msg.attacker.controller}_${msg.attacker.location}_${msg.attacker.sequence}';

    if (msg.target != null) {
      lastAttackTo =
          '${msg.target!.controller}_${msg.target!.location}_${msg.target!.sequence}';
    } else {
      lastAttackTo = null;
    }
    final attackerName = fieldCards[lastAttackFrom]?.name ?? '怪兽';
    if (lastAttackTo != null) {
      final targetName = fieldCards[lastAttackTo]?.name ?? '怪兽';
      addLog('$attackerName 攻击 $targetName。');
    } else {
      addLog('$attackerName 发动直接攻击。');
    }
  }

  void _handleDamage(dynamic data) {
    final msg = data as MsgDamage;
    if (msg.player == myController) {
      selfLp -= msg.value;
    } else {
      opponentLp -= msg.value;
    }
    final name = players
        .firstWhere(
          (p) => p.pos == msg.player,
          orElse: () => RoomPlayer(name: '玩家${msg.player}', pos: msg.player),
        )
        .name;
    addLog('$name 受到 ${msg.value} 点伤害。');
  }

  void _handlePayLife(dynamic data) {
    final msg = data as MsgPayLpCost;
    if (msg.player == myController) {
      selfLp -= msg.value;
    } else {
      opponentLp -= msg.value;
    }
    final name = players
        .firstWhere(
          (p) => p.pos == msg.player,
          orElse: () => RoomPlayer(name: '玩家${msg.player}', pos: msg.player),
        )
        .name;
    addLog('$name 支付了 ${msg.value} 点生命值。');
  }

  void _handleSelectIdleCmd(dynamic data) {
    _selectionController.applyIdleCmd(data as MsgSelectIdleCmd);
  }

  void _handleSelectBattleCmd(dynamic data) {
    _selectionController.applyBattleCmd(data as MsgSelectBattleCmd);
  }

  void _handleSelectGeneric(int func, dynamic data) {
    switch (func) {
      case MSG_SELECT_CARD:
        _handleSelectCard(data as MsgSelectCard);
        break;
      case MSG_SELECT_CHAIN:
        _handleSelectChain(data as MsgSelectChain);
        break;
      case MSG_SELECT_EFFECTYN:
        _handleSelectEffectYn(data as MsgSelectEffectYn);
        break;
      case MSG_SELECT_YES_NO:
        _handleSelectYesNo(data as MsgSelectYesNo);
        break;
      case MSG_SELECT_PLACE:
        _handleSelectPlace(data as MsgSelectPlace);
        break;
      default:
        console.log('Unhandled select message: $func');
    }
  }

  void _handleSelectPlace(MsgSelectPlace msg) {
    _selectionController.applySelectPlace(msg);
  }

  void _handleSelectCard(MsgSelectCard msg) {
    _selectionController.applySelectCard(msg);
  }

  void _handleSelectChain(MsgSelectChain msg) {
    _selectionController.applySelectChain(msg);
  }

  void _handleSelectEffectYn(MsgSelectEffectYn msg) {
    _selectionController.applySelectEffectYn(msg);
  }

  void _handleSelectYesNo(MsgSelectYesNo msg) {
    _selectionController.applySelectYesNo(msg);
  }

  void _handleSelectPosition(MsgSelectPosition msg) {
    _selectionController.applySelectPosition(msg);
  }

  void _handleFieldDisabled(MsgFieldDisabled msg) {
    _boardController.applyFieldDisabled(msg);
    addLog('区域禁用状态已更新。');
  }

  void _handleSelectTribute(MsgSelectTribute msg) {
    _selectionController.applySelectTribute(msg);
  }

  void _handleSelectCounter(MsgSelectCounter msg) {
    _selectionController.applySelectCounter(msg);
  }

  void _handleSelectSum(MsgSelectSum msg) {
    _selectionController.applySelectSum(msg);
  }

  void _handleSortCard(MsgSortCard msg) {
    _selectionController.applySortCard(msg);
  }

  void _handleChaining(dynamic data) {
    final msg = data as MsgChaining;
    chains.add(
      ChainLink(
        code: msg.code,
        controller: msg.location.controller,
        zone: msg.location.location,
        sequence: msg.location.sequence,
      ),
    );
    final name = _cardInfoCache[msg.code]?.name ?? '卡片';
    addLog('连锁发动 $name。');
  }

  void _handleBattle(MsgBattle msg) {
    _boardController.applyBattle(msg);
    addLog('战斗结算。');
  }

  void _handleChainEnd(dynamic data) {
    chains.clear();
  }

  void _handleSummoning(dynamic data) {
    final msg = data as MsgSummoning;
    lastSummonKey =
        '${msg.location.controller}_${msg.location.location}_${msg.location.sequence}';
    unawaited(_ensureCardInfo(msg.code));
    final name = _cardInfoCache[msg.code]?.name ?? '怪兽';
    addLog('正在召唤 $name。');
  }

  void _handlePosChange(dynamic data) {
    final msg = data as MsgPosChange;
    _boardController.applyPosChange(msg);
    final key =
        '${msg.cardInfo.controller}_${msg.cardInfo.location}_${msg.cardInfo.sequence}';
    final card = fieldCards[key];
    if (card != null) {
      addLog('${card.name} 表示形式变更。');
    }
  }

  void _handleShuffleHand(dynamic data) {
    _boardController.applyShuffleHand(data as MsgShuffleHand);
  }

  void _handleSelectOption(dynamic data) {
    _selectionController.applySelectOption(data as MsgSelectOption);
  }

  void _handleSelectUnselectCard(dynamic data) {
    _selectionController.applySelectUnselectCard(data as MsgSelectUnselectCard);
  }

  void _handleSelectDisfield(dynamic data) {
    _selectionController.applySelectDisfield(data as MsgSelectPlace);
  }

  @override
  void dispose() {
    super.dispose();
    console.log('DuelRoomStore disposed');
  }
}
