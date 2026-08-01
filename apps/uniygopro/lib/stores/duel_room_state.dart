import 'dart:async';
import 'dart:developer' as console;
import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import '../models/deck_model.dart';
import '../service_singleton.dart';
import '../services/deck_service.dart';
import 'package:ygo_card/card_info.dart' as pkg;
// ── ChatMessage (from room_store.dart) ──

class ChatMessage {
  final int playerIndex;
  final String name;
  final String message;
  final DateTime time;

  const ChatMessage({
    required this.playerIndex,
    required this.name,
    required this.message,
    required this.time,
  });
}

// ── Duel types (from duel_store.dart) ──

enum DuelPhase {
  idle,
  dp,
  sp,
  m1,
  bp,
  m2,
  ep,
}

class IdleAction {
  final int type;
  final int sequence;
  final int code;
  final int controller;
  final int location;
  final int locationSequence;
  final int position;

  const IdleAction({
    required this.type,
    required this.sequence,
    required this.code,
    required this.controller,
    required this.location,
    this.locationSequence = 0,
    required this.position,
  });
}

class BattleAction {
  final int type;
  final int sequence;
  final int attackerController;
  final int attackerLocation;
  final int attackerSequence;
  final int attackerPosition;
  final bool directAttack;
  final int targetController;
  final int targetLocation;
  final int targetSequence;
  final int targetPosition;

  const BattleAction({
    required this.type,
    required this.sequence,
    required this.attackerController,
    required this.attackerLocation,
    required this.attackerSequence,
    required this.attackerPosition,
    required this.directAttack,
    this.targetController = 0,
    this.targetLocation = 0,
    this.targetSequence = 0,
    this.targetPosition = 0,
  });
}

enum SelectType {
  idleCmd,
  card,
  chain,
  option,
  position,
  effectYn,
  yesNo,
  battleCmd,
  place,
  tribute,
  sum,
  counter,
  sort,
}

class SelectOption {
  final int code;
  final int controller;
  final int zone;
  final int sequence;
  final int? level;
  final int? position;
  final String? label;

  const SelectOption({
    required this.code,
    this.controller = 0,
    this.zone = 0,
    this.sequence = 0,
    this.level,
    this.position,
    this.label,
  });
}

class SelectState {
  final SelectType type;
  final int player;
  final List<SelectOption> options;
  final int min;
  final int max;
  final bool cancelable;
  final int? effectDescription;

  const SelectState({
    required this.type,
    required this.player,
    this.options = const [],
    this.min = 1,
    this.max = 1,
    this.cancelable = false,
    this.effectDescription,
  });
}

class FieldCard {
  final int code;
  final int controller;
  final int zone;
  final int sequence;
  final int position;
  final int overlayCount;
  final int? attack;
  final int? defense;
  final String? name;

  const FieldCard({
    required this.code,
    required this.controller,
    required this.zone,
    required this.sequence,
    this.position = 0,
    this.overlayCount = 0,
    this.attack,
    this.defense,
    this.name,
  });

  String get key => '${controller}_${zone}_$sequence';
}

class ChainLink {
  final int code;
  final int controller;
  final int zone;
  final int sequence;

  const ChainLink({
    required this.code,
    required this.controller,
    required this.zone,
    required this.sequence,
  });
}

// ── DuelRoomState ──

class DuelRoomState extends ChangeNotifier {
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

  // === 决斗字段 (from DuelStore) ===
  final Map<String, FieldCard> fieldCards = {};
  final List<int> selfHand = [];
  final List<int> opponentHand = [];
  int selfDeck = 0, selfExtra = 0, selfGrave = 0, selfRemoved = 0;
  int oppDeck = 0, oppExtra = 0, oppGrave = 0, oppRemoved = 0;
  int selfLp = 8000, opponentLp = 8000;
  int currentPlayer = 0;
  int phase = 0;
  int turnCount = 0;
  int myController = 0;

  /// 卡片信息缓存：code → CardInfo（从本地 SQLite 查询）
  final Map<int, pkg.CardInfo> _cardInfoCache = {};
  List<DuelPhase> phases = [];
  List<IdleAction> selectedIdleActions = [];
  List<BattleAction> selectedBattleActions = [];
  bool enableBp = false;
  bool enableM2 = false;
  bool enableEp = false;
  SelectState? currentSelect;
  bool get isWaitingForInput => currentSelect != null;
  String? lastSummonKey;
  String? lastAttackFrom;
  String? lastAttackTo;
  List<ChainLink> chains = [];

  // === 共享 ===
  IDuelService? _service;
  StreamSubscription<YgoStocMsg>? _msgSub;

  bool get isInDuel => stage is RoomInDuel;

  // ══════════════════════════════════════════
  // 等待房间方法 (from RoomStore)
  // ══════════════════════════════════════════

  void updateFromDuelink(RoomStage stage) {
    this.stage = stage;
    players = stage.players;
    observerCount = stage.observerCount;
    switch (stage) {
      case RoomNotJoined():
        //游戏结束或者离开房间后，重置房间状态
        break;
      case RoomInLobby():
        selfType = stage.selfType;
        isHost = stage.isHost;
        roomOptions = stage.options;
        break;
      case RoomSelectingHand():
        break;
      case RoomHandResult():
        myHandResult = stage.myHand;
        opponentHandResult = stage.opponentHand;
        break;
      case RoomInDuel():
        myHandResult = 0;
        opponentHandResult = 0;
        isFirstTurn = stage.isFirstTurn;
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void addChat(int playerIndex, String name, String message) {
    chatMessages.add(ChatMessage(
      playerIndex: playerIndex,
      name: name,
      message: message,
      time: DateTime.now(),
    ));
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
    console.log('Loaded ${decks.length} decks: ${decks.map((d) => d.deckName).join(', ')}');
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
    _service?.playGameResponse(CtosGameMsgResponse.selectPlace(CtosSelectPlace(
      player: player,
      zone: zone,
      sequence: sequence,
    )));
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
    currentSelect = select;
    notifyListeners();
  }

  void clearSelect() {
    currentSelect = null;
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
    fieldCards.clear();
    selfHand.clear();
    opponentHand.clear();
    selfDeck = selfExtra = selfGrave = selfRemoved = 0;
    oppDeck = oppExtra = oppGrave = oppRemoved = 0;
    selfLp = opponentLp = 8000;
    currentPlayer = 0;
    phase = 0;
    turnCount = 0;
    currentSelect = null;
    lastSummonKey = lastAttackFrom = lastAttackTo = null;
    chains.clear();
    myController = 0;
    phases = [];
    selectedIdleActions = [];
    selectedBattleActions = [];
    enableBp = false;
    enableM2 = false;
    enableEp = false;

    notifyListeners();
  }

  // ══════════════════════════════════════════
  // 消息处理 (from DuelStore)
  // ══════════════════════════════════════════

  void _onMessage(YgoStocMsg msg) {
    final gameMsg = msg.gameMsg;
    if (gameMsg == null) return;

    switch (gameMsg.func) {
      case MSG_START:
        _handleStart(gameMsg.innerMsg);
        break;
      case MSG_NEW_TURN:
        _handleNewTurn(gameMsg.innerMsg);
        break;
      case MSG_NEW_PHASE:
        _handleNewPhase(gameMsg.innerMsg);
        break;
      case MSG_DRAW:
        _handleDraw(gameMsg.innerMsg);
        break;
      case MSG_MOVE:
        _handleMove(gameMsg.innerMsg);
        break;
      case MSG_ATTACK:
        _handleAttack(gameMsg.innerMsg);
        break;
      case MSG_DAMAGE:
        _handleDamage(gameMsg.innerMsg);
        break;
      case MSG_PAY_LP_COST:
        _handlePayLife(gameMsg.innerMsg);
        break;
      case MSG_SELECT_IDLE_CMD:
        _handleSelectIdleCmd(gameMsg.innerMsg);
        break;
      case MSG_SELECT_BATTLE_CMD:
        _handleSelectBattleCmd(gameMsg.innerMsg);
        break;
      case MSG_SELECT_CARD:
      case MSG_SELECT_CHAIN:
      case MSG_SELECT_EFFECTYN:
      case MSG_SELECT_YES_NO:
      case MSG_SELECT_PLACE:
        _handleSelectGeneric(gameMsg.func, gameMsg.innerMsg);
        break;
      case MSG_SELECT_POSITION:
        _handleSelectPosition(gameMsg.innerMsg as MsgSelectPosition);
        break;
      case MSG_SELECT_TRIBUTE:
        _handleSelectTribute(gameMsg.innerMsg as MsgSelectTribute);
        break;
      case MSG_SELECT_COUNTER:
        _handleSelectCounter(gameMsg.innerMsg as MsgSelectCounter);
        break;
      case MSG_SELECT_SUM:
        _handleSelectSum(gameMsg.innerMsg as MsgSelectSum);
        break;
      case MSG_SORT_CARD:
        _handleSortCard(gameMsg.innerMsg as MsgSortCard);
        break;
      case MSG_CHAINING:
        _handleChaining(gameMsg.innerMsg);
        break;
      case MSG_CHAIN_END:
        _handleChainEnd(gameMsg.innerMsg);
        break;
      case MSG_SUMMONING:
        _handleSummoning(gameMsg.innerMsg);
        break;
      case MSG_POS_CHANGE:
        _handlePosChange(gameMsg.innerMsg);
        break;
      case MSG_SHUFFLE_HAND:
        _handleShuffleHand(gameMsg.innerMsg);
        break;
      case MSG_SELECT_OPTION:
        _handleSelectOption(gameMsg.innerMsg);
        break;
      case MSG_SELECT_UNSELECT_CARD:
        _handleSelectUnselectCard(gameMsg.innerMsg);
        break;
      case MSG_SELECT_DISFIELD:
        _handleSelectDisfield(gameMsg.innerMsg);
        break;
      default:
        console.log('Unhandled game message: ${gameMsg.func}');
    }
    notifyListeners();
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
    final name = players.firstWhere((p) => p.pos == msg.player, orElse: () => RoomPlayer(name: '玩家${msg.player}', pos: msg.player)).name;
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
    final isMyDraw = msg.player == myController;

    for (final cardCode in msg.cards) {
      if (isMyDraw) {
        selfHand.add(cardCode);
      } else {
        opponentHand.add(cardCode);
      }
    }

    if (isMyDraw) {
      selfDeck -= msg.count;
    } else {
      oppDeck -= msg.count;
    }
    final name = players.firstWhere((p) => p.pos == msg.player, orElse: () => RoomPlayer(name: '玩家${msg.player}', pos: msg.player)).name;
    addLog('$name 抽了 ${msg.count} 张卡。');
  }

  void _handleMove(dynamic data) {
    final msg = data as MsgMove;
    final from = msg.from;
    final to = msg.to;

    _removeCardFromLocation(from.controller, from.location, from.sequence);
    _addCardToLocation(msg.code, to.controller, to.location, to.sequence, to.position);
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

  void _addCardToLocation(int code, int controller, int location, int sequence, int position) {
    if (location & CARD_ZONE_HAND != 0) {
      if (controller == myController) {
        selfHand.add(code);
      } else {
        opponentHand.add(code);
      }
    } else if (location & CARD_ZONE_ONFIELD != 0) {
      // 先用 code 创建 FieldCard，再异步查 DB 补全 name/atk/def
      setFieldCard(FieldCard(
        code: code,
        controller: controller,
        zone: location,
        sequence: sequence,
        position: position,
      ));
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
  Future<void> _enrichFieldCard(int code, int controller, int location, int sequence) async {
    await _ensureCardInfo(code);
    final info = _cardInfoCache[code];
    if (info == null) return;
    final key = '${controller}_${location}_$sequence';
    final card = fieldCards[key];
    if (card == null || card.name != null) return;
    fieldCards[key] = FieldCard(
      code: card.code,
      controller: card.controller,
      zone: card.zone,
      sequence: card.sequence,
      position: card.position,
      overlayCount: card.overlayCount,
      attack: info.attack >= 0 ? info.attack : null,
      defense: info.defense >= 0 ? info.defense : null,
      name: info.name,
    );
    notifyListeners();
  }

  void _handleAttack(dynamic data) {
    final msg = data as MsgAttack;
    lastAttackFrom = '${msg.attacker.controller}_${msg.attacker.location}_${msg.attacker.sequence}';

    if (msg.target != null) {
      lastAttackTo = '${msg.target!.controller}_${msg.target!.location}_${msg.target!.sequence}';
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
    final name = players.firstWhere((p) => p.pos == msg.player, orElse: () => RoomPlayer(name: '玩家${msg.player}', pos: msg.player)).name;
    addLog('$name 受到 ${msg.value} 点伤害。');
  }

  void _handlePayLife(dynamic data) {
    final msg = data as MsgPayLpCost;
    if (msg.player == myController) {
      selfLp -= msg.value;
    } else {
      opponentLp -= msg.value;
    }
    final name = players.firstWhere((p) => p.pos == msg.player, orElse: () => RoomPlayer(name: '玩家${msg.player}', pos: msg.player)).name;
    addLog('$name 支付了 ${msg.value} 点生命值。');
  }

  void _handleSelectIdleCmd(dynamic data) {
    final msg = data as MsgSelectIdleCmd;
    final actions = <IdleAction>[];

    for (final group in msg.commandGroups) {
      final type = group.type.index;
      for (final option in group.options) {
        actions.add(IdleAction(
          type: type,
          sequence: option.response,
          code: option.cardInfo.code,
          controller: option.cardInfo.controller,
          location: option.cardInfo.location,
          locationSequence: option.cardInfo.sequence,
          position: 0,
        ));
      }
    }

    selectedIdleActions = actions;
    enableBp = msg.enableBp;
    enableEp = msg.enableEp;
    setSelect(SelectState(
      type: SelectType.idleCmd,
      player: msg.player,
      min: 1,
      max: 1,
    ));
  }

  void _handleSelectBattleCmd(dynamic data) {
    final msg = data as MsgSelectBattleCmd;
    final actions = <BattleAction>[];

    for (final group in msg.commandGroups) {
      final type = group.type.index;
      for (final option in group.options) {
        actions.add(BattleAction(
          type: type,
          sequence: option.response,
          attackerController: option.cardInfo.controller,
          attackerLocation: option.cardInfo.location,
          attackerSequence: option.cardInfo.sequence,
          attackerPosition: 0,
          directAttack: option.directAttackable,
        ));
      }
    }

    selectedBattleActions = actions;
    enableM2 = msg.enableM2;
    enableEp = msg.enableEp;
    setSelect(SelectState(
      type: SelectType.battleCmd,
      player: msg.player,
      min: 1,
      max: 1,
    ));
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
    setSelect(SelectState(
      type: SelectType.place,
      player: msg.player,
      min: msg.count,
      max: msg.count,
      cancelable: false,
    ));
  }

  void _handleSelectCard(MsgSelectCard msg) {
    final options = <SelectOption>[];
    for (int i = 0; i < msg.count; i++) {
      options.add(SelectOption(
        code: msg.codes[i],
        controller: msg.locations[i].controller,
        zone: msg.locations[i].location,
        sequence: msg.locations[i].sequence,
      ));
    }

    setSelect(SelectState(
      type: SelectType.card,
      player: msg.player,
      options: options,
      min: msg.min,
      max: msg.max,
      cancelable: msg.cancelable != 0,
    ));
  }

  void _handleSelectChain(MsgSelectChain msg) {
    final options = <SelectOption>[];
    for (final chain in msg.chains) {
      options.add(SelectOption(
        code: chain.code,
        controller: chain.location.controller,
        zone: chain.location.location,
        sequence: chain.location.sequence,
        label: '连锁${chain.effectDescription}',
      ));
    }

    setSelect(SelectState(
      type: SelectType.chain,
      player: msg.player,
      options: options,
      min: msg.forced ? 1 : 0,
      max: 1,
      cancelable: !msg.forced,
    ));
  }

  void _handleSelectEffectYn(MsgSelectEffectYn msg) {
    setSelect(SelectState(
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
    ));
  }

  void _handleSelectYesNo(MsgSelectYesNo msg) {
    setSelect(SelectState(
      type: SelectType.yesNo,
      player: msg.player,
      min: 1,
      max: 1,
      effectDescription: msg.effectDescription,
    ));
  }

  void _handleSelectPosition(MsgSelectPosition msg) {
    final options = <SelectOption>[];

    if (msg.positions & 0x01 != 0) {
      options.add(SelectOption(code: msg.code, position: 0x01, label: '攻击表示'));
    }
    if (msg.positions & 0x02 != 0) {
      options.add(SelectOption(code: msg.code, position: 0x02, label: '守备表示'));
    }
    if (msg.positions & 0x04 != 0) {
      options.add(SelectOption(code: msg.code, position: 0x04, label: '里侧守备'));
    }
    if (msg.positions & 0x08 != 0) {
      options.add(SelectOption(code: msg.code, position: 0x08, label: '表侧攻击'));
    }

    setSelect(SelectState(
      type: SelectType.position,
      player: msg.player,
      options: options,
      min: 1,
      max: 1,
    ));
  }

  void _handleSelectTribute(MsgSelectTribute msg) {
    final options = <SelectOption>[];
    for (int i = 0; i < msg.count; i++) {
      options.add(SelectOption(
        code: msg.codes[i],
        controller: msg.locations[i].controller,
        zone: msg.locations[i].location,
        sequence: msg.locations[i].sequence,
        level: msg.levels[i],
      ));
    }

    setSelect(SelectState(
      type: SelectType.tribute,
      player: msg.player,
      options: options,
      min: msg.min,
      max: msg.max,
      cancelable: msg.cancelable != 0,
    ));
  }

  void _handleSelectCounter(MsgSelectCounter msg) {
    final options = <SelectOption>[];
    for (int i = 0; i < msg.count; i++) {
      options.add(SelectOption(
        code: msg.codes[i],
        controller: msg.locations[i].controller,
        zone: msg.locations[i].location,
        sequence: msg.locations[i].sequence,
        level: msg.counterCounts[i],
      ));
    }

    setSelect(SelectState(
      type: SelectType.counter,
      player: msg.player,
      options: options,
      min: msg.min,
      max: msg.min,
    ));
  }

  void _handleSelectSum(MsgSelectSum msg) {
    final options = <SelectOption>[];
    for (final card in [...msg.mustSelectCards, ...msg.selectableCards]) {
      options.add(SelectOption(
        code: card.code,
        controller: card.location.controller,
        zone: card.location.location,
        sequence: card.location.sequence,
        level: card.level1,
      ));
    }

    setSelect(SelectState(
      type: SelectType.sum,
      player: msg.player,
      options: options,
      min: msg.min,
      max: msg.max,
    ));
  }

  void _handleSortCard(MsgSortCard msg) {
    final options = <SelectOption>[];
    for (int i = 0; i < msg.count; i++) {
      options.add(SelectOption(
        code: msg.codes[i],
        controller: msg.locations[i].controller,
        zone: msg.locations[i].location,
        sequence: msg.locations[i].sequence,
      ));
    }

    setSelect(SelectState(
      type: SelectType.sort,
      player: msg.player,
      options: options,
      min: msg.count,
      max: msg.count,
    ));
  }

  void _handleChaining(dynamic data) {
    final msg = data as MsgChaining;
    chains.add(ChainLink(
      code: msg.code,
      controller: msg.location.controller,
      zone: msg.location.location,
      sequence: msg.location.sequence,
    ));
    final name = _cardInfoCache[msg.code]?.name ?? '卡片';
    addLog('连锁发动 $name。');
  }

  void _handleChainEnd(dynamic data) {
    chains.clear();
  }

  void _handleSummoning(dynamic data) {
    final msg = data as MsgSummoning;
    lastSummonKey = '${msg.location.controller}_${msg.location.location}_${msg.location.sequence}';
    unawaited(_ensureCardInfo(msg.code));
    final name = _cardInfoCache[msg.code]?.name ?? '怪兽';
    addLog('正在召唤 $name。');
  }

  void _handlePosChange(dynamic data) {
    final msg = data as MsgPosChange;
    final key = '${msg.cardInfo.controller}_${msg.cardInfo.location}_${msg.cardInfo.sequence}';
    final card = fieldCards[key];
    if (card != null) {
      fieldCards[key] = FieldCard(
        code: card.code,
        controller: card.controller,
        zone: card.zone,
        sequence: card.sequence,
        position: msg.curPosition,
        overlayCount: card.overlayCount,
        attack: card.attack,
        defense: card.defense,
        name: card.name,
      );
      addLog('${card.name} 表示形式变更。');
    }
  }

  void _handleShuffleHand(dynamic data) {
    final msg = data as MsgShuffleHand;
    if (msg.player == myController) {
      selfHand.clear();
      selfHand.addAll(msg.cards);
    } else {
      opponentHand.clear();
      opponentHand.addAll(List.filled(msg.count, 0));
    }
  }

  void _handleSelectOption(dynamic data) {
    final msg = data as MsgSelectOption;
    final options = <SelectOption>[];
    for (final code in msg.codes) {
      options.add(SelectOption(code: code));
    }

    setSelect(SelectState(
      type: SelectType.option,
      player: msg.player,
      options: options,
      min: 1,
      max: 1,
    ));
  }

  void _handleSelectUnselectCard(dynamic data) {
    final msg = data as MsgSelectUnselectCard;
    final options = <SelectOption>[];
    for (final card in msg.selectableCards) {
      options.add(SelectOption(
        code: card.code,
        controller: card.location.controller,
        zone: card.location.location,
        sequence: card.location.sequence,
      ));
    }

    setSelect(SelectState(
      type: SelectType.card,
      player: msg.player,
      options: options,
      min: msg.min,
      max: msg.max,
      cancelable: msg.cancelable,
    ));
  }

  void _handleSelectDisfield(dynamic data) {
    final msg = data as MsgSelectPlace;
    final options = <SelectOption>[];
    for (int bit = 0; bit < 32; bit++) {
      if ((msg.field & (1 << bit)) == 0) continue;
      options.add(SelectOption(
        code: 0,
        controller: bit >= 16 ? 1 : 0,
        zone: bit < 8 || (bit >= 16 && bit < 24) ? CARD_ZONE_MZONE : CARD_ZONE_SZONE,
        sequence: bit % 8,
      ));
    }

    setSelect(SelectState(
      type: SelectType.place,
      player: msg.player,
      options: options,
      min: msg.count,
      max: msg.count,
      cancelable: false,
    ));
  }
}
