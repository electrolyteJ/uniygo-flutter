import 'dart:async';
import 'dart:developer' as console;

import 'package:duelink/duelink.dart';
import 'package:flutter/cupertino.dart';
import 'package:uniygopro/service_singleton.dart';
import 'package:ygo_data/card_info.dart' as pkg;

import '../../../constants.dart';
import '../../../models/BattleAction.dart';
import '../../../models/BattlePresentation.dart';
import '../../../models/ChainLink.dart';
import '../../../models/DuelResultSummary.dart';
import '../../../models/confirm_cards.dart';
import '../../../models/FieldCard.dart';
import '../../../models/IdleAction.dart';
import '../../../models/SelectState.dart';
import '../../../models/duel_event.dart';
import '../../../services/duel_sound_service.dart';
import '../../../widgets/duel_room/inspector/zone_browser_modal.dart';
import '../../../widgets/duel_room/menus/hand_action_menu.dart';
import 'playmat_action_resolver.dart';
/// 对局状态仓库（服务器驱动），全局唯一。
///
/// 战场部分：场上卡片、手牌、墓地/除外/额外卡组数量、LP、阶段、连锁，
/// 以及对局渲染需要的卡片信息（缓存收敛在 dataService）。
/// 选择部分：服务端下发的当前选择题、可执行行动，并把 UI 的选择
/// 重新编码成对应的对局响应消息发回服务端。
class DuelFieldStore extends ChangeNotifier {
  // ──────────────────────────────────────────
  // 战场状态
  // ──────────────────────────────────────────

  /// 当前场上可见卡片，key 格式为 `controller_zone_sequence`。
  final Map<String, FieldCard> fieldCards = {};
  final List<int> selfHand = [];
  final List<int> opponentHand = [];
  final List<int> selfGraveCodes = [];
  final List<int> opponentGraveCodes = [];
  final List<int> selfRemovedCodes = [];
  final List<int> opponentRemovedCodes = [];
  final List<int> selfExtraCodes = [];
  final List<int> opponentExtraCodes = [];
  final List<int> _knownSelfExtraDeckCodes = [];
  int selfDeck = 0;
  int selfExtra = 0;
  int selfGrave = 0;
  int selfRemoved = 0;
  int oppDeck = 0;
  int oppExtra = 0;
  int oppGrave = 0;
  int oppRemoved = 0;
  int selfLp = 8000;
  int opponentLp = 8000;
  int currentPlayer = 0;
  DuelPhase phase = DuelPhase.idle;
  int turnCount = 0;

  /// 己方引擎玩家编号（0/1），由 MSG_START 的 playerType 确定
  /// （低 nibble 0 = 引擎 0 号玩家 = 惯例先攻方）。房间座位号 ≠ 引擎编号，
  /// 不能从 selfPlayer.pos 推断。
  int myController = 0;

  List<ChainLink> chains = [];
  String? lastSummonKey;
  String? lastAttackFrom;
  String? lastAttackTo;
  BattlePresentation? battlePresentation;
  bool inDamageStep = false;
  Timer? _battlePresentationTimer;
  int selfLpDelta = 0;
  int opponentLpDelta = 0;
  int selfLpEventId = 0;
  int opponentLpEventId = 0;
  final dataService = ServiceSingleton.instance.dataService;
  final soundService = DuelSoundService();
  final uiSound = ServiceSingleton.instance.uiSoundService;

  /// 卡组洗切信号：每次 MSG_SHUFFLE_DECK 自增，驱动场地洗牌动效。
  int deckShuffleTick = 0;
  int deckShufflePlayer = 0;

  /// 对局日志（战报），供日志抽屉展示。
  final List<String> duelLogs = [];

  /// 玩家名解析所需的房间玩家列表，由页面在房间阶段变化时同步。
  List<PlayerInfo> players = [];

  // ──────────────────────────────────────────
  // 选择态
  // ──────────────────────────────────────────

  List<IdleAction> selectedIdleActions = [];
  List<BattleAction> selectedBattleActions = [];
  bool enableBp = false;
  bool enableM2 = false;
  bool enableEp = false;
  SelectState? currentSelect;

  int? _inspectedCardCode;
  pkg.CardInfo? _inspectedCardInfo;
  int? _selectedHandSequence;
  int? _selectedZoneBrowserSequence;
  FieldCard? _selectedFieldCard;
  String? _openZoneBrowserKey;
  bool _showInspector = false;
  bool _showPhaseMenu = false;

  /// 服务端要求展示的卡牌弹窗（MSG_CONFIRM_CARDS 等）。
  /// 非 null 时场地页居中弹窗展示，[Timer] 到期自动关闭。
  ConfirmCards? confirmCards;
  Timer? _confirmCardsTimer;
  DuelResultSummary? duelResult;
  final List<int> _announceCardBlockedCodes = [];

  /// 最近一次等待用户处理的交互消息，供 MSG_RETRY 时恢复选择 UI。
  int? _lastInteractiveFunc;
  dynamic _lastInteractiveMsg;

  bool get isWaitingForInput => currentSelect != null;
  bool get hasIdleCommandWindow => currentSelect?.type == SelectType.idleCmd;
  bool get hasBattleCommandWindow =>
      currentSelect?.type == SelectType.battleCmd;
  bool get hasPhaseCommandWindow =>
      hasIdleCommandWindow || hasBattleCommandWindow;
  int? get inspectedCardCode => _inspectedCardCode;
  pkg.CardInfo? get inspectedCardInfo => _inspectedCardInfo;
  int? get selectedHandSequence => _selectedHandSequence;
  int? get selectedZoneBrowserSequence => _selectedZoneBrowserSequence;
  FieldCard? get selectedFieldCard => _selectedFieldCard;
  String? get openZoneBrowserKey => _openZoneBrowserKey;
  bool get showInspector => _showInspector;
  bool get showPhaseMenu => _showPhaseMenu;
  List<int> get announceCardBlockedCodes =>
      List<int>.unmodifiable(_announceCardBlockedCodes);
  IDuelService? _duelService;

  bool ownsCurrentWindow(int player) => currentSelect?.player == player;
  bool canOpenPhaseMenuFor(int player) =>
      ownsCurrentWindow(player) && hasPhaseCommandWindow;

  // ──────────────────────────────────────────
  // 生命周期
  // ──────────────────────────────────────────

  void bind(IDuelService duelService) {
    _duelService = duelService;
  }

  /// 清空当前对局状态，供离开房间或新对局开始时使用。
  void reset() {
    fieldCards.clear();
    selfHand.clear();
    opponentHand.clear();
    selfGraveCodes.clear();
    opponentGraveCodes.clear();
    selfRemovedCodes.clear();
    opponentRemovedCodes.clear();
    selfExtraCodes.clear();
    opponentExtraCodes.clear();
    _knownSelfExtraDeckCodes.clear();
    selfDeck = selfExtra = selfGrave = selfRemoved = 0;
    oppDeck = oppExtra = oppGrave = oppRemoved = 0;
    selfLp = opponentLp = 8000;
    currentPlayer = 0;
    phase = DuelPhase.idle;
    turnCount = 0;
    myController = 0;
    chains = [];
    lastSummonKey = null;
    lastAttackFrom = null;
    lastAttackTo = null;
    battlePresentation = null;
    inDamageStep = false;
    _battlePresentationTimer?.cancel();
    _battlePresentationTimer = null;
    selfLpDelta = 0;
    opponentLpDelta = 0;
    selfLpEventId = 0;
    opponentLpEventId = 0;
    selectedIdleActions = [];
    selectedBattleActions = [];
    enableBp = false;
    enableM2 = false;
    enableEp = false;
    currentSelect = null;
    _announceCardBlockedCodes.clear();
    _resetLocalUiState();
    confirmCards = null;
    _confirmCardsTimer?.cancel();
    _confirmCardsTimer = null;
    duelResult = null;
    _lastInteractiveFunc = null;
    _lastInteractiveMsg = null;
    duelLogs.clear();
    _phaseSub?.cancel();
    _msgSub?.cancel();
    players = [];
    deckShuffleTick = 0;
    deckShufflePlayer = 0;
    notifyListeners();
  }

  /// 供页面在批量字段赋值后显式触发刷新。
  void markChanged() {
    notifyListeners();
  }

  void _resetLocalUiState() {
    _inspectedCardCode = null;
    _inspectedCardInfo = null;
    _selectedHandSequence = null;
    _selectedZoneBrowserSequence = null;
    _selectedFieldCard = null;
    _openZoneBrowserKey = null;
    _showInspector = false;
    _showPhaseMenu = false;
  }

  // ──────────────────────────────────────────
  // 卡片信息（缓存收敛在 dataService）
  // ──────────────────────────────────────────

  /// 获取卡片信息（同步读取 dataService 缓存，未命中返回 null）
  pkg.CardInfo? getCardInfo(int code) => dataService.getCardCached(code);

  /// 异步预加载卡片信息（缓存判断在 dataService.getCard 内部）
  Future<void> ensureCardInfo(int code) async {
    try {
      final info = await dataService.getCard(code);
      if (info != null) notifyListeners();
    } catch (e) {
      console.log('Failed to load card info for $code: $e');
    }
  }

  String getCardImageUrl(int code) {
    return dataService.getCardImageUrl(code);
  }

  // ──────────────────────────────────────────
  // 战场消息应用
  // ──────────────────────────────────────────

  /// 处理抽卡消息，并同步手牌与卡组剩余数量。
  void applyDraw(MsgDraw msg) {
    final isMyDraw = msg.player == myController;
    final hand = isMyDraw ? selfHand : opponentHand;
    hand.addAll(msg.cards);
    if (isMyDraw) {
      selfDeck -= msg.count;
    } else {
      oppDeck -= msg.count;
    }
  }

  /// 批量应用服务端发来的区域更新。
  void applyUpdateData(MsgUpdateData msg) {
    for (final action in msg.actions) {
      final location = action.location;
      final code = action.code;
      if (location == null || code == null) {
        continue;
      }
      applyUpdateAction(
        controller: location.controller,
        zone: location.location,
        sequence: location.sequence,
        position: location.position,
        code: code,
        action: action,
      );
    }
  }

  /// 应用单张卡片的增量更新。
  void applyUpdateCard(MsgUpdateCard msg) {
    final action = msg.action;
    if (action == null) return;
    applyUpdateAction(
      controller: msg.player,
      zone: msg.zone,
      sequence: msg.sequence,
      position: action.location?.position ?? 0,
      code: action.code ?? 0,
      action: action,
    );
  }

  /// 使用整包场面快照重建本地战场状态。
  void applyReloadField(MsgReloadField msg) {
    fieldCards.clear();
    selfHand.clear();
    opponentHand.clear();
    selfGraveCodes.clear();
    opponentGraveCodes.clear();
    selfRemovedCodes.clear();
    opponentRemovedCodes.clear();
    selfExtraCodes.clear();
    opponentExtraCodes.clear();

    for (final playerState in msg.players) {
      final isSelf = playerState.player == myController;
      if (isSelf) {
        selfLp = playerState.lp;
      } else {
        opponentLp = playerState.lp;
      }

      int deck = 0, extra = 0, grave = 0, removed = 0, hand = 0;
      for (final action in playerState.zoneActions) {
        switch (action.zone) {
          case CARD_ZONE_DECK:
            deck++;
            break;
          case CARD_ZONE_EXTRA:
            extra++;
            if (isSelf) {
              _seedKnownSelfExtraCode(action.sequence);
            } else {
              _seedZonePlaceholder(opponentExtraCodes, action.sequence);
            }
            break;
          case CARD_ZONE_GRAVE:
            grave++;
            _seedZonePlaceholder(
              isSelf ? selfGraveCodes : opponentGraveCodes,
              action.sequence,
            );
            break;
          case CARD_ZONE_REMOVED:
            removed++;
            _seedZonePlaceholder(
              isSelf ? selfRemovedCodes : opponentRemovedCodes,
              action.sequence,
            );
            break;
          case CARD_ZONE_HAND:
            hand++;
            break;
          default:
            if (_isOnFieldLocation(action.zone)) {
              final normalizedZone = _normalizeFieldZone(action.zone);
              final normalizedSequence = _normalizeFieldSequence(
                action.zone,
                action.sequence,
              );
              fieldCards[_fieldCardKey(
                playerState.player,
                action.zone,
                action.sequence,
              )] = FieldCard(
                code: 0,
                controller: playerState.player,
                zone: normalizedZone,
                sequence: normalizedSequence,
                position: action.position ?? 0,
                overlayCount: action.overlayCount,
                disabled: false,
              );
            }
        }
      }

      if (isSelf) {
        selfDeck = deck;
        selfExtra = extra;
        selfGrave = grave;
        selfRemoved = removed;
        selfHand
          ..clear()
          ..addAll(List<int>.filled(hand, 0));
      } else {
        oppDeck = deck;
        oppExtra = extra;
        oppGrave = grave;
        oppRemoved = removed;
        opponentHand
          ..clear()
          ..addAll(List<int>.filled(hand, 0));
      }
    }
  }

  /// 处理卡片移动消息，先移除旧位置，再写入新位置。
  void applyMove(MsgMove msg) {
    removeCardFromLocation(
      msg.from.controller,
      msg.from.location,
      msg.from.sequence,
    );
    addCardToLocation(
      msg.code,
      msg.to.controller,
      msg.to.location,
      msg.to.sequence,
      msg.to.position,
    );
  }

  /// 同步禁用区域状态。
  void applyFieldDisabled(MsgFieldDisabled msg) {
    for (final action in msg.actions) {
      final key = _fieldCardKey(
        action.controller,
        action.zone,
        action.sequence,
      );
      final current = fieldCards[key];
      if (current == null) continue;
      fieldCards[key] = FieldCard(
        code: current.code,
        controller: current.controller,
        zone: current.zone,
        sequence: current.sequence,
        position: current.position,
        overlayCount: current.overlayCount,
        disabled: action.disabled,
        attack: current.attack,
        defense: current.defense,
        name: current.name,
      );
    }
  }

  /// 更新战斗结算后场上怪兽的攻守信息。
  void applyBattle(MsgBattle msg) {
    updateBattleCardStats(
      msg.attacker,
      msg.attackerAttack,
      msg.attackerDefense,
    );
    if (msg.hasDefender) {
      updateBattleCardStats(
        msg.defender,
        msg.defenderAttack,
        msg.defenderDefense,
      );
    }
  }

  /// 处理表示形式变化。
  void applyPosChange(MsgPosChange msg) {
    final key = _fieldCardKey(
      msg.cardInfo.controller,
      msg.cardInfo.location,
      msg.cardInfo.sequence,
    );
    final card = fieldCards[key];
    if (card == null) return;
    fieldCards[key] = FieldCard(
      code: card.code,
      controller: card.controller,
      zone: card.zone,
      sequence: card.sequence,
      position: msg.curPosition,
      overlayCount: card.overlayCount,
      disabled: card.disabled,
      attack: card.attack,
      defense: card.defense,
      name: card.name,
    );
  }

  /// 处理洗手牌消息。
  void applyShuffleHand(MsgShuffleHand msg) {
    if (msg.player == myController) {
      selfHand
        ..clear()
        ..addAll(msg.cards);
    } else {
      opponentHand
        ..clear()
        ..addAll(List.filled(msg.count, 0));
    }
  }

  void updateBattleCardStats(CardLocation location, int attack, int defense) {
    final key = _fieldCardKey(
      location.controller,
      location.location,
      location.sequence,
    );
    final current = fieldCards[key];
    if (current == null) return;
    fieldCards[key] = FieldCard(
      code: current.code,
      controller: current.controller,
      zone: current.zone,
      sequence: current.sequence,
      position: current.position,
      overlayCount: current.overlayCount,
      disabled: current.disabled,
      attack: attack,
      defense: defense,
      name: current.name,
    );
  }

  /// 按消息内容把卡片更新写回到对应区域。
  void applyUpdateAction({
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
          unawaited(ensureCardInfo(code));
        }
      }
      return;
    }

    if (zone & CARD_ZONE_DECK != 0) {
      syncZoneCount(controller, zone, sequence);
      return;
    }

    if (zone & CARD_ZONE_EXTRA != 0) {
      syncZoneCount(controller, zone, sequence, code: code);
      return;
    }

    if (zone & CARD_ZONE_GRAVE != 0) {
      syncZoneCount(controller, zone, sequence, code: code);
      return;
    }

    if (zone & CARD_ZONE_REMOVED != 0) {
      syncZoneCount(controller, zone, sequence, code: code);
      return;
    }

    if (_isOnFieldLocation(zone)) {
      final normalizedZone = _normalizeFieldZone(zone);
      final normalizedSequence = _normalizeFieldSequence(zone, sequence);
      final key = _fieldCardKey(controller, zone, sequence);
      final current = fieldCards[key];
      final effectiveCode = code > 0 ? code : (current?.code ?? 0);
      final overlayCount = action.overlayCards.isNotEmpty
          ? action.overlayCards.length
          : (current?.overlayCount ?? 0);
      fieldCards[key] = FieldCard(
        code: effectiveCode,
        controller: controller,
        zone: normalizedZone,
        sequence: normalizedSequence,
        position: position != 0 ? position : (current?.position ?? 0),
        overlayCount: overlayCount,
        disabled: current?.disabled ?? false,
        attack: action.attack ?? current?.attack,
        defense: action.defense ?? current?.defense,
        name: current?.name,
      );
      if (effectiveCode > 0) {
        unawaited(ensureCardInfo(effectiveCode));
      }
    }
  }

  /// 根据区域序号推导该区域当前至少应有多少张卡。
  void syncZoneCount(int controller, int zone, int sequence, {int? code}) {
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
      upsertZoneCode(
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
        unawaited(ensureCardInfo(code));
      }
      return;
    }
    if (zone & CARD_ZONE_GRAVE != 0) {
      upsertZoneCode(
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
        unawaited(ensureCardInfo(code));
      }
      return;
    }
    if (zone & CARD_ZONE_REMOVED != 0) {
      upsertZoneCode(
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
        unawaited(ensureCardInfo(code));
      }
    }
  }

  void upsertZoneCode(List<int> list, int sequence, int? code) {
    while (list.length <= sequence) {
      list.add(0);
    }
    if (code != null && code > 0) {
      list[sequence] = code;
    }
  }

  void _seedZonePlaceholder(List<int> list, int sequence) {
    while (list.length <= sequence) {
      list.add(0);
    }
  }

  void _seedKnownSelfExtraCode(int sequence) {
    while (selfExtraCodes.length <= sequence) {
      final index = selfExtraCodes.length;
      selfExtraCodes.add(
        index < _knownSelfExtraDeckCodes.length
            ? _knownSelfExtraDeckCodes[index]
            : 0,
      );
    }
  }

  void setKnownSelfExtraDeckCodes(List<int> codes) {
    _knownSelfExtraDeckCodes
      ..clear()
      ..addAll(codes);
    if (selfExtraCodes.isEmpty) {
      selfExtraCodes.addAll(codes);
      selfExtra = codes.length;
      notifyListeners();
      return;
    }
    for (var i = 0; i < selfExtraCodes.length && i < codes.length; i++) {
      if (selfExtraCodes[i] <= 0) {
        selfExtraCodes[i] = codes[i];
      }
    }
    notifyListeners();
  }

  bool _isOnFieldLocation(int location) {
    return (location & CARD_ZONE_ONFIELD) != 0 ||
        (location & CARD_ZONE_FZONE) != 0;
  }

  int _normalizeFieldZone(int zone) {
    if ((zone & CARD_ZONE_FZONE) != 0) {
      return CARD_ZONE_SZONE;
    }
    return zone;
  }

  int _normalizeFieldSequence(int zone, int sequence) {
    if ((zone & CARD_ZONE_FZONE) != 0) {
      return 5;
    }
    return sequence;
  }

  String _fieldCardKey(int controller, int zone, int sequence) {
    final normalizedZone = _normalizeFieldZone(zone);
    final normalizedSequence = _normalizeFieldSequence(zone, sequence);
    return '${controller}_${normalizedZone}_$normalizedSequence';
  }

  List<int>? _zoneCodeListFor(int controller, int location) {
    final isSelf = controller == myController;
    if (location & CARD_ZONE_EXTRA != 0) {
      return isSelf ? selfExtraCodes : opponentExtraCodes;
    }
    if (location & CARD_ZONE_GRAVE != 0) {
      return isSelf ? selfGraveCodes : opponentGraveCodes;
    }
    if (location & CARD_ZONE_REMOVED != 0) {
      return isSelf ? selfRemovedCodes : opponentRemovedCodes;
    }
    return null;
  }

  /// 从指定区域移除一张卡，并维护关联计数。
  void removeCardFromLocation(int controller, int location, int sequence) {
    if (location & CARD_ZONE_HAND != 0) {
      final hand = controller == myController ? selfHand : opponentHand;
      if (sequence < hand.length) {
        hand.removeAt(sequence);
      }
    } else if (_isOnFieldLocation(location)) {
      fieldCards.remove(_fieldCardKey(controller, location, sequence));
    } else if (location & CARD_ZONE_GRAVE != 0) {
      final list = _zoneCodeListFor(controller, location);
      if (list != null && sequence < list.length) {
        list.removeAt(sequence);
      }
      if (controller == myController) {
        selfGrave = selfGrave > 0 ? selfGrave - 1 : 0;
      } else {
        oppGrave = oppGrave > 0 ? oppGrave - 1 : 0;
      }
    } else if (location & CARD_ZONE_REMOVED != 0) {
      final list = _zoneCodeListFor(controller, location);
      if (list != null && sequence < list.length) {
        list.removeAt(sequence);
      }
      if (controller == myController) {
        selfRemoved = selfRemoved > 0 ? selfRemoved - 1 : 0;
      } else {
        oppRemoved = oppRemoved > 0 ? oppRemoved - 1 : 0;
      }
    } else if (location & CARD_ZONE_DECK != 0) {
      if (controller == myController) {
        selfDeck--;
      } else {
        oppDeck--;
      }
    } else if (location & CARD_ZONE_EXTRA != 0) {
      final list = _zoneCodeListFor(controller, location);
      if (list != null && sequence < list.length) {
        list.removeAt(sequence);
      }
      if (controller == myController) {
        selfExtra = selfExtra > 0 ? selfExtra - 1 : 0;
      } else {
        oppExtra = oppExtra > 0 ? oppExtra - 1 : 0;
      }
    }
  }

  /// 向指定区域写入一张卡，并维护关联计数。
  void addCardToLocation(
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
    } else if (_isOnFieldLocation(location)) {
      final normalizedZone = _normalizeFieldZone(location);
      final normalizedSequence = _normalizeFieldSequence(location, sequence);
      fieldCards[_fieldCardKey(controller, location, sequence)] = FieldCard(
        code: code,
        controller: controller,
        zone: normalizedZone,
        sequence: normalizedSequence,
        position: position,
        disabled: false,
      );
      unawaited(ensureCardInfo(code));
    } else if (location & CARD_ZONE_GRAVE != 0) {
      final list = _zoneCodeListFor(controller, location);
      if (list != null) {
        while (list.length < sequence) {
          list.add(0);
        }
        if (sequence <= list.length) {
          list.insert(sequence, code);
        }
      }
      if (controller == myController) {
        selfGrave++;
      } else {
        oppGrave++;
      }
      if (code > 0) {
        unawaited(ensureCardInfo(code));
      }
    } else if (location & CARD_ZONE_REMOVED != 0) {
      final list = _zoneCodeListFor(controller, location);
      if (list != null) {
        while (list.length < sequence) {
          list.add(0);
        }
        if (sequence <= list.length) {
          list.insert(sequence, code);
        }
      }
      if (controller == myController) {
        selfRemoved++;
      } else {
        oppRemoved++;
      }
      if (code > 0) {
        unawaited(ensureCardInfo(code));
      }
    } else if (location & CARD_ZONE_DECK != 0) {
      if (controller == myController) {
        selfDeck++;
      } else {
        oppDeck++;
      }
    } else if (location & CARD_ZONE_EXTRA != 0) {
      final list = _zoneCodeListFor(controller, location);
      if (list != null) {
        while (list.length < sequence) {
          list.add(0);
        }
        if (sequence <= list.length) {
          list.insert(sequence, code);
        }
      }
      if (controller == myController) {
        selfExtra++;
      } else {
        oppExtra++;
      }
      if (code > 0) {
        unawaited(ensureCardInfo(code));
      }
    }
  }

  String? handleChaining(dynamic data) {
    final msg = data as MsgChaining;
    chains.add(
      ChainLink(
        code: msg.code,
        controller: msg.location.controller,
        zone: msg.location.location,
        sequence: msg.location.sequence,
      ),
    );
    final name = getCardInfo(msg.code)?.name ?? '卡片';
    return name;
  }

  String? handleSummoning(dynamic data) {
    final msg = data as MsgSummoning;
    lastSummonKey =
        '${msg.location.controller}_${msg.location.location}_${msg.location.sequence}';
    unawaited(ensureCardInfo(msg.code));
    final name = getCardInfo(msg.code)?.name ?? '怪兽';
    return name;
  }

  FieldCard? handlePosChange(dynamic data) {
    final msg = data as MsgPosChange;
    applyPosChange(msg);
    final key = _fieldCardKey(
      msg.cardInfo.controller,
      msg.cardInfo.location,
      msg.cardInfo.sequence,
    );
    final card = fieldCards[key];
    return card;
  }

  void setFieldCard(FieldCard card) {
    final normalizedZone = _normalizeFieldZone(card.zone);
    final normalizedSequence = _normalizeFieldSequence(
      card.zone,
      card.sequence,
    );
    fieldCards[_fieldCardKey(
      card.controller,
      card.zone,
      card.sequence,
    )] = FieldCard(
      code: card.code,
      controller: card.controller,
      zone: normalizedZone,
      sequence: normalizedSequence,
      position: card.position,
      overlayCount: card.overlayCount,
      disabled: card.disabled,
      attack: card.attack,
      defense: card.defense,
      name: card.name,
    );
    notifyListeners();
  }

  void removeFieldCard(int controller, int zone, int sequence) {
    fieldCards.remove(_fieldCardKey(controller, zone, sequence));
    notifyListeners();
  }

  /// 读取可被浏览的公共区域卡片代码列表。
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

  // ──────────────────────────────────────────
  // 选择响应
  // ──────────────────────────────────────────

  /// 记录当前等待玩家处理的选择请求。
  void setSelect(SelectState select) {
    currentSelect = select;
    notifyListeners();
  }

  /// 清除当前选择请求。
  void clearSelect() {
    currentSelect = null;
    _announceCardBlockedCodes.clear();
    notifyListeners();
  }

  void _sendResponse(CtosGameMsgResponse response) {
    _duelService?.playGameResponse(response);
  }

  void _rememberInteractiveMessage(int func, dynamic msg) {
    _lastInteractiveFunc = func;
    _lastInteractiveMsg = msg;
  }

  bool _restoreLastInteractiveMessage() {
    final func = _lastInteractiveFunc;
    final msg = _lastInteractiveMsg;
    if (func == null || msg == null) return false;
    switch (func) {
      case MSG_SELECT_IDLE_CMD:
        _handleSelectIdleCmd(msg as MsgSelectIdleCmd);
        return true;
      case MSG_SELECT_BATTLE_CMD:
        _handleSelectBattleCmd(msg as MsgSelectBattleCmd);
        return true;
      case MSG_SELECT_CARD:
      case MSG_SELECT_CHAIN:
      case MSG_SELECT_EFFECTYN:
      case MSG_SELECT_YES_NO:
      case MSG_SELECT_PLACE:
        _handleSelectGeneric(func, msg);
        return true;
      case MSG_SELECT_POSITION:
        _handleSelectPosition(msg as MsgSelectPosition);
        return true;
      case MSG_SELECT_TRIBUTE:
        _handleSelectTribute(msg as MsgSelectTribute);
        return true;
      case MSG_SELECT_COUNTER:
        _handleSelectCounter(msg as MsgSelectCounter);
        return true;
      case MSG_SELECT_SUM:
        _handleSelectSum(msg as MsgSelectSum);
        return true;
      case MSG_SORT_CARD:
        _handleSortCard(msg as MsgSortCard);
        return true;
      case MSG_SELECT_OPTION:
        _handleSelectOption(msg);
        return true;
      case MSG_ANNOUNCE_CARD:
        _handleAnnounceCard(msg as MsgAnnounceCard);
        return true;
      case MSG_SELECT_UNSELECT_CARD:
        _handleSelectUnselectCard(msg);
        return true;
      case MSG_SELECT_DISFIELD:
        _handleSelectDisfield(msg);
        return true;
    }
    return false;
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
    if (hasIdleCommandWindow) {
      respondIdleCmd(sequence);
      return true;
    }
    if (hasBattleCommandWindow) {
      respondBattleCmd(sequence);
      return true;
    }
    return false;
  }

  void respondSelectCard(List<int> sequences) {
    final select = currentSelect;
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
    final blockedCodes = _announceCardBlockedCodes.toSet();
    final results = await dataService.searchCards(trimmed);
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
    console.log(
      'applySelectCard: min=${msg.min} max=${msg.max} count=${msg.count} options='
      '${List.generate(msg.count, (i) => "#$i code=${msg.codes[i]} c=${msg.locations[i].controller} z=${msg.locations[i].location} s=${msg.locations[i].sequence}")}',
    );
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
          sequence: chain.response,
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
      options: _placeOptionsFromFieldMask(
        msg.field,
        selectingPlayer: msg.player,
        selectableWhenBitSet: false,
      ),
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
      options: [
        for (var index = 0; index < msg.codes.length; index++)
          SelectOption(
            code: _cardCodeFromDescriptionValue(msg.codes[index]) ?? 0,
            sequence: index,
            label: '${msg.codes[index]}',
          ),
      ],
      min: 1,
      max: 1,
    );
  }

  void applyAnnounceCard(MsgAnnounceCard msg) {
    _announceCardBlockedCodes
      ..clear()
      ..addAll(msg.codes);
    currentSelect = SelectState(
      type: SelectType.announceCard,
      player: msg.player,
      min: 1,
      max: 1,
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
    currentSelect = SelectState(
      type: SelectType.unselect,
      player: msg.player,
      options: options,
      min: msg.min,
      max: msg.max,
      cancelable: msg.cancelable,
      finishable: msg.finishable,
      immediateSingleToggle: true,
      initialSelectedIndices: initiallySelected,
    );
  }

  void applySelectDisfield(MsgSelectPlace msg) {
    currentSelect = SelectState(
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
  // 服务器消息分发
  // ──────────────────────────────────────────

  /// 记录对局日志并触发刷新。
  void addLog(String log) {
    duelLogs.add(log);
    notifyListeners();
  }

  /// 同步房间玩家列表，供日志文案解析玩家名。
  void syncPlayers(List<PlayerInfo> players) {
    this.players = players;
  }

  String _playerNameOf(int pos) {
    return players
        .firstWhere(
          (p) => p.pos == pos,
          orElse: () => PlayerInfo(name: '玩家$pos', pos: pos),
        )
        .name;
  }

  /// 服务器原始消息入口：解码为 [DuelEvent] 后分发。
  void handleServerMessage(YgoStocMsg msg) {
    final gameMsg = msg.gameMsg;
    if (gameMsg == null || gameMsg.innerMsg == null) {
      console.log('No game message payload ${msg}');
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
        _handleStart(innerMsg);
        soundService.playDuelStart();
        break;
      case MSG_NEW_TURN:
        _handleNewTurn(innerMsg);
        soundService.playNewTurn();
        break;
      case MSG_NEW_PHASE:
        // 已通过 onDuelPhaseMessage 单独派发，避免这里重复记日志。
        soundService.playNewPhase();
        break;
      case MSG_WAITING:
        _handleWaiting(innerMsg as MsgWait);
        break;
      case MSG_ATTACK:
        _handleAttack(innerMsg);
        soundService.playAttack();
        break;
      case MSG_DAMAGE:
        _handleDamage(innerMsg);
        soundService.playDamage();
        break;
      case MSG_RECOVER:
        _handleRecover(innerMsg);
        soundService.playRecover();
        break;
      case MSG_LP_UPDATE:
        _handleLpUpdate(innerMsg);
        break;
      case MSG_PAY_LP_COST:
        _handlePayLife(innerMsg);
        soundService.playDamage();
        break;
      case MSG_CONFIRM_CARDS:
      case MSG_CONFIRM_DECKTOP:
      case MSG_CONFIRM_EXTRATOP:
        _handleConfirmCards(gameMsg.func, innerMsg as MsgConfirmCards);
        break;
      case MSG_CHAINING:
        final name = handleChaining(innerMsg);
        addLog('连锁发动 $name。');
        soundService.playChain();
        break;
      case MSG_CHAINED:
        _handleChained(innerMsg as MsgChained);
        break;
      case MSG_CHAIN_SOLVING:
        _handleChainSolving(innerMsg as MsgChainSolving);
        break;
      case MSG_CHAIN_SOLVED:
        _handleChainSolved(innerMsg as MsgChainSolved);
        break;
      case MSG_CHAIN_END:
        _handleChainEnd(innerMsg);
        soundService.playChainEnd();
        break;
      case MSG_SUMMONING:
        final name = handleSummoning(innerMsg);
        addLog('正在召唤 $name。');
        soundService.playSummon();
        break;
      case MSG_SUMMONED:
        _handleSummonFinished('召唤');
        break;
      case MSG_SP_SUMMONING:
        final msg = innerMsg as MsgSpSummoning;
        _handleSummonPreparing(msg.code, msg.location, actionLabel: '特殊召唤');
        soundService.playSpecialSummon();
        break;
      case MSG_SP_SUMMONED:
        _handleSummonFinished('特殊召唤');
        break;
      case MSG_FLIP_SUMMONING:
        final msg = innerMsg as MsgFlipSummoning;
        _handleSummonPreparing(msg.code, msg.location, actionLabel: '反转召唤');
        soundService.playFlipSummon();
        break;
      case MSG_FLIP_SUMMONED:
        _handleSummonFinished('反转召唤');
        break;
      case MSG_BATTLE:
        _handleBattle(innerMsg as MsgBattle);
        soundService.playBattle();
        break;
      case MSG_HINT:
        _handleHint(innerMsg as MsgHint);
        break;
      case MSG_WIN:
        _handleWin(innerMsg as MsgWin);
        soundService.playDuelWin();
        break;
      case MSG_RETRY:
        if (_restoreLastInteractiveMessage()) {
          addLog('操作无效，请重新选择。');
        } else {
          console.log('MSG_RETRY without restorable local selection, ignored.');
        }
        break;
      case MSG_SHUFFLE_DECK:
        _handleShuffleDeck(innerMsg);
        soundService.playShuffleDeck();
        break;
      case MSG_BECOME_TARGET:
        _handleBecomeTarget(innerMsg as MsgBecomeTarget);
        break;
      case MSG_ATTACK_DISABLE:
        _handleAttackDisabled();
        break;
      case MSG_DAMAGE_STEP_START:
        _handleDamageStepStart();
        soundService.playDamageStep();
        break;
      case MSG_DAMAGE_STEP_END:
        _handleDamageStepEnd();
        break;
      // 决斗事件 end
      // 决斗场地  start
      case MSG_DRAW:
        _handleDraw(innerMsg);
        soundService.playCardDraw();
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
        soundService.playCardDestroy();
        break;
      case MSG_FIELD_DISABLED:
        _handleFieldDisabled(innerMsg as MsgFieldDisabled);
        break;
      case MSG_POS_CHANGE:
        final card = handlePosChange(innerMsg);
        addLog('${card?.name} 表示形式变更。');
        soundService.playPosChange();
        break;
      case MSG_SHUFFLE_HAND:
        _handleShuffleHand(innerMsg);
        break;
      case MSG_SET:
        _handleSet(innerMsg as MsgSet);
        soundService.playSetCard();
        break;
      // 决斗场地  end
      // 选择事件  start
      case MSG_SELECT_IDLE_CMD:
        if (!_isLocalSelectionMessage(gameMsg.func, innerMsg)) break;
        _handleSelectIdleCmd(innerMsg);
        _rememberInteractiveMessage(gameMsg.func, innerMsg);
        break;
      case MSG_SELECT_BATTLE_CMD:
        if (!_isLocalSelectionMessage(gameMsg.func, innerMsg)) break;
        _handleSelectBattleCmd(innerMsg);
        _rememberInteractiveMessage(gameMsg.func, innerMsg);
        break;
      case MSG_SELECT_CARD:
      case MSG_SELECT_CHAIN:
      case MSG_SELECT_EFFECTYN:
      case MSG_SELECT_YES_NO:
      case MSG_SELECT_PLACE:
        if (!_isLocalSelectionMessage(gameMsg.func, innerMsg)) break;
        _handleSelectGeneric(gameMsg.func, innerMsg);
        if (currentSelect?.player == myController) {
          _rememberInteractiveMessage(gameMsg.func, innerMsg);
        }
        break;
      case MSG_SELECT_POSITION:
        if (!_isLocalSelectionMessage(gameMsg.func, innerMsg)) break;
        _handleSelectPosition(innerMsg as MsgSelectPosition);
        _rememberInteractiveMessage(gameMsg.func, innerMsg);
        break;
      case MSG_SELECT_TRIBUTE:
        if (!_isLocalSelectionMessage(gameMsg.func, innerMsg)) break;
        _handleSelectTribute(innerMsg as MsgSelectTribute);
        _rememberInteractiveMessage(gameMsg.func, innerMsg);
        break;
      case MSG_SELECT_COUNTER:
        if (!_isLocalSelectionMessage(gameMsg.func, innerMsg)) break;
        _handleSelectCounter(innerMsg as MsgSelectCounter);
        _rememberInteractiveMessage(gameMsg.func, innerMsg);
        break;
      case MSG_SELECT_SUM:
        if (!_isLocalSelectionMessage(gameMsg.func, innerMsg)) break;
        _handleSelectSum(innerMsg as MsgSelectSum);
        _rememberInteractiveMessage(gameMsg.func, innerMsg);
        break;
      case MSG_SORT_CARD:
        if (!_isLocalSelectionMessage(gameMsg.func, innerMsg)) break;
        _handleSortCard(innerMsg as MsgSortCard);
        _rememberInteractiveMessage(gameMsg.func, innerMsg);
        break;
      case MSG_SELECT_OPTION:
        if (!_isLocalSelectionMessage(gameMsg.func, innerMsg)) break;
        _handleSelectOption(innerMsg);
        _rememberInteractiveMessage(gameMsg.func, innerMsg);
        break;
      case MSG_ANNOUNCE_CARD:
        if (!_isLocalSelectionMessage(gameMsg.func, innerMsg)) break;
        _handleAnnounceCard(innerMsg as MsgAnnounceCard);
        _rememberInteractiveMessage(gameMsg.func, innerMsg);
        break;
      case MSG_SELECT_UNSELECT_CARD:
        if (!_isLocalSelectionMessage(gameMsg.func, innerMsg)) break;
        _handleSelectUnselectCard(innerMsg);
        _rememberInteractiveMessage(gameMsg.func, innerMsg);
        break;
      case MSG_SELECT_DISFIELD:
        if (!_isLocalSelectionMessage(gameMsg.func, innerMsg)) break;
        _handleSelectDisfield(innerMsg);
        _rememberInteractiveMessage(gameMsg.func, innerMsg);
        break;
      // 选择事件  end
      case MSG_TOSS_COIN:
        soundService.playCoinToss();
        break;
      case MSG_TOSS_DICE:
        soundService.playDice();
        break;
      default:
        console.log('Unhandled  event: ${gameMsg.func}');
    }
    notifyListeners();
  }

  bool _isLocalSelectionMessage(int func, dynamic msg) {
    final player = _selectionPlayerOf(func, msg);
    if (player == null || player == myController) {
      return true;
    }
    console.log('Skip selection event for opponent: func=$func player=$player');
    return false;
  }

  int? _selectionPlayerOf(int func, dynamic msg) {
    switch (func) {
      case MSG_SELECT_IDLE_CMD:
        return (msg as MsgSelectIdleCmd).player;
      case MSG_SELECT_BATTLE_CMD:
        return (msg as MsgSelectBattleCmd).player;
      case MSG_SELECT_CARD:
        return (msg as MsgSelectCard).player;
      case MSG_SELECT_CHAIN:
        return (msg as MsgSelectChain).player;
      case MSG_SELECT_EFFECTYN:
        return (msg as MsgSelectEffectYn).player;
      case MSG_SELECT_YES_NO:
        return (msg as MsgSelectYesNo).player;
      case MSG_SELECT_PLACE:
      case MSG_SELECT_DISFIELD:
        return (msg as MsgSelectPlace).player;
      case MSG_SELECT_POSITION:
        return (msg as MsgSelectPosition).player;
      case MSG_SELECT_TRIBUTE:
        return (msg as MsgSelectTribute).player;
      case MSG_SELECT_COUNTER:
        return (msg as MsgSelectCounter).player;
      case MSG_SELECT_SUM:
        return (msg as MsgSelectSum).player;
      case MSG_SORT_CARD:
        return (msg as MsgSortCard).player;
      case MSG_SELECT_OPTION:
        return (msg as MsgSelectOption).player;
      case MSG_ANNOUNCE_CARD:
        return (msg as MsgAnnounceCard).player;
      case MSG_SELECT_UNSELECT_CARD:
        return (msg as MsgSelectUnselectCard).player;
    }
    return null;
  }

  void _handleStart(dynamic data) {
    final msg = data as MsgStart;
    // MSG_START 首字节是服务端按客户端单独下发的引擎玩家编号
    // （0x00 = 引擎 0 号玩家，0x01 = 引擎 1 号玩家），不是房间座位号。
    final isPlayer0 = msg.isPlayer0;
    myController = isPlayer0 ? 0 : 1;

    selfLp = isPlayer0 ? msg.life1 : msg.life2;
    opponentLp = isPlayer0 ? msg.life2 : msg.life1;

    selfDeck = isPlayer0 ? msg.deckSize1 : msg.deckSize2;
    selfExtra = isPlayer0 ? msg.extraSize1 : msg.extraSize2;
    oppDeck = isPlayer0 ? msg.deckSize2 : msg.deckSize1;
    oppExtra = isPlayer0 ? msg.extraSize2 : msg.extraSize1;

    selfHand.clear();
    opponentHand.clear();
    fieldCards.clear();

    turnCount = 1;
    addLog('决斗开始。');
  }

  void _handleNewTurn(dynamic data) {
    final msg = data as MsgNewTurn;
    currentPlayer = msg.player;
    turnCount++;
    addLog('${_playerNameOf(msg.player)} 的回合。');
  }

  void _handleDraw(dynamic data) {
    final msg = data as MsgDraw;
    applyDraw(msg);
    addLog('${_playerNameOf(msg.player)} 抽了 ${msg.count} 张卡。');
  }

  void _handleUpdateData(MsgUpdateData msg) {
    applyUpdateData(msg);
  }

  void _handleUpdateCard(MsgUpdateCard msg) {
    applyUpdateCard(msg);
  }

  void _handleReloadField(MsgReloadField msg) {
    applyReloadField(msg);
  }

  void _handleWaiting(MsgWait msg) {
    addLog('等待对手操作。');
  }

  void _handleMove(dynamic data) {
    applyMove(data as MsgMove);
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
    battlePresentation = BattlePresentation(
      attackerSlotId: lastAttackFrom!,
      defenderSlotId: lastAttackTo,
      attackerName: attackerName,
      defenderName: lastAttackTo == null
          ? null
          : fieldCards[lastAttackTo!]?.name ?? '怪兽',
    );
    _battlePresentationTimer?.cancel();
    if (lastAttackTo != null) {
      final targetName = fieldCards[lastAttackTo]?.name ?? '怪兽';
      addLog('$attackerName 攻击 $targetName。');
    } else {
      addLog('$attackerName 发动直接攻击。');
    }
  }

  void _handleDamage(dynamic data) {
    final msg = data as MsgDamage;
    _applyLpChange(msg.player, -msg.value);
    addLog('${_playerNameOf(msg.player)} 受到 ${msg.value} 点伤害。');
  }

  void _handleRecover(dynamic data) {
    final msg = data as MsgRecover;
    _applyLpChange(msg.player, msg.value);
    addLog('${_playerNameOf(msg.player)} 回复了 ${msg.value} 点生命值。');
  }

  void _handleLpUpdate(dynamic data) {
    final msg = data as MsgLpUpdate;
    final oldLp = msg.player == myController ? selfLp : opponentLp;
    final delta = msg.newLp - oldLp;
    if (msg.player == myController) {
      selfLp = msg.newLp;
      selfLpDelta = delta;
      selfLpEventId++;
    } else {
      opponentLp = msg.newLp;
      opponentLpDelta = delta;
      opponentLpEventId++;
    }
    console.log(
      'MSG_LP_UPDATE: player=${msg.player} old=$oldLp new=${msg.newLp} delta=$delta',
    );
  }

  void _handlePayLife(dynamic data) {
    final msg = data as MsgPayLpCost;
    _applyLpChange(msg.player, -msg.value);
    addLog('${_playerNameOf(msg.player)} 支付了 ${msg.value} 点生命值。');
  }

  void _handleConfirmCards(int func, MsgConfirmCards msg) {
    _preloadCardInfos(msg.cards.map((card) => card.code));
    for (final card in msg.cards) {
      _syncConfirmedCard(card);
    }
    final owner = msg.player == myController ? '我方' : '对方';
    final zoneLabel = switch (func) {
      MSG_CONFIRM_DECKTOP => '卡组顶部卡片',
      MSG_CONFIRM_EXTRATOP => '额外卡组顶部卡片',
      _ => '卡片',
    };
    addLog('$owner 确认了 $zoneLabel 的 ${msg.count} 张卡。');
    if (msg.skipPanel == 1) {
      // 服务端要求跳过确认弹窗（卡片已通过其他途径展示过），仅记录日志。
      console.log('跳过确认弹窗，直接记录日志。');
      return;
    }
    confirmCards = ConfirmCards(
      title: '$owner 展示的 $zoneLabel',
      codes: msg.cards.map((card) => card.code).toList(),
    );
    _confirmCardsTimer?.cancel();
    _confirmCardsTimer = Timer(const Duration(seconds: 1), () {
      confirmCards = null;
      _confirmCardsTimer = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void _syncConfirmedCard(CardInfo card) {
    final code = card.code;
    if (code <= 0) {
      return;
    }

    final controller = card.controller;
    final location = card.location;
    final sequence = card.sequence;

    if (location & CARD_ZONE_HAND != 0) {
      final hand = controller == myController ? selfHand : opponentHand;
      while (hand.length <= sequence) {
        hand.add(0);
      }
      hand[sequence] = code;
      return;
    }

    if (location & CARD_ZONE_GRAVE != 0 ||
        location & CARD_ZONE_REMOVED != 0 ||
        location & CARD_ZONE_EXTRA != 0) {
      final list = _zoneCodeListFor(controller, location);
      if (list != null) {
        upsertZoneCode(list, sequence, code);
      }
      return;
    }

    if (_isOnFieldLocation(location)) {
      final key = _fieldCardKey(controller, location, sequence);
      final current = fieldCards[key];
      fieldCards[key] = FieldCard(
        code: code,
        controller: controller,
        zone: _normalizeFieldZone(location),
        sequence: _normalizeFieldSequence(location, sequence),
        position: current?.position ?? 0,
        overlayCount: current?.overlayCount ?? 0,
        disabled: current?.disabled ?? false,
        attack: current?.attack,
        defense: current?.defense,
        name: current?.name,
      );
    }
  }

  /// 关闭确认弹窗（服务端已在收到消息时自动确认）。
  void dismissConfirmCards() {
    _confirmCardsTimer?.cancel();
    _confirmCardsTimer = null;
    confirmCards = null;
  }

  void _handleChained(MsgChained msg) {
    addLog('连锁 ${msg.chainIndex + 1} 已入链。');
  }

  void _handleChainSolving(MsgChainSolving msg) {
    addLog('正在处理连锁 ${msg.chainIndex + 1}。');
  }

  void _handleChainSolved(MsgChainSolved msg) {
    addLog('连锁 ${msg.solvedIndex + 1} 处理完成。');
  }

  void _handleSummonPreparing(
    int code,
    CardLocation location, {
    required String actionLabel,
  }) {
    lastSummonKey =
        '${location.controller}_${location.location}_${location.sequence}';
    if (code > 0) {
      unawaited(ensureCardInfo(code));
    }
    final name = getCardInfo(code)?.name ?? '怪兽';
    addLog('正在$actionLabel $name。');
  }

  void _handleSummonFinished(String actionLabel) {
    final key = lastSummonKey;
    final name = key != null ? fieldCards[key]?.name ?? '怪兽' : '怪兽';
    lastSummonKey = null;
    addLog('$name $actionLabel成功。');
  }

  int? _cardCodeFromDescriptionValue(int value) {
    if (value <= 0) return null;
    if (value >= 1000000 && value <= 99999999) return value;
    final code = value >> 4;
    if (code < 1000000 || code > 99999999) return null;
    return code;
  }

  void _handleHint(MsgHint msg) {
    final code = _cardCodeFromDescriptionValue(msg.hintData);
    if (code != null && code >= 1000000) {
      unawaited(ensureCardInfo(code));
    }
  }

  void _handleWin(MsgWin msg) {
    final didWin = msg.winPlayer == myController;
    duelResult = DuelResultSummary(
      didWin: didWin,
      winPlayer: msg.winPlayer,
      reason: msg.reason,
      selfName: _playerNameOf(myController),
      opponentName: _playerNameOf(1 - myController),
      selfLp: selfLp,
      opponentLp: opponentLp,
    );
    addLog(didWin ? '决斗胜利。' : '决斗失败。');
  }

  void _handleSelectIdleCmd(dynamic data) {
    applyIdleCmd(data as MsgSelectIdleCmd);
  }

  void _handleSelectBattleCmd(dynamic data) {
    applyBattleCmd(data as MsgSelectBattleCmd);
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
    applySelectPlace(msg);
  }

  void _handleSelectCard(MsgSelectCard msg) {
    applySelectCard(msg);
  }

  void _handleSelectChain(MsgSelectChain msg) {
    applySelectChain(msg);
  }

  void _handleSelectEffectYn(MsgSelectEffectYn msg) {
    applySelectEffectYn(msg);
  }

  void _handleSelectYesNo(MsgSelectYesNo msg) {
    applySelectYesNo(msg);
  }

  void _handleSelectPosition(MsgSelectPosition msg) {
    applySelectPosition(msg);
  }

  void _handleFieldDisabled(MsgFieldDisabled msg) {
    applyFieldDisabled(msg);
    addLog('区域禁用状态已更新。');
  }

  void _handleSet(MsgSet msg) {
    if (msg.code > 0) {
      unawaited(ensureCardInfo(msg.code));
    }
    final name = getCardInfo(msg.code)?.name ?? '卡片';
    addLog('$name 已盖放。');
  }

  void _handleSelectTribute(MsgSelectTribute msg) {
    applySelectTribute(msg);
  }

  void _handleSelectCounter(MsgSelectCounter msg) {
    applySelectCounter(msg);
  }

  void _handleSelectSum(MsgSelectSum msg) {
    applySelectSum(msg);
  }

  void _handleSortCard(MsgSortCard msg) {
    applySortCard(msg);
  }

  void _handleAnnounceCard(MsgAnnounceCard msg) {
    applyAnnounceCard(msg);
  }

  void _handleBattle(MsgBattle msg) {
    applyBattle(msg);
    console.log(
      'MSG_BATTLE: atk=${msg.attacker.controller}/${msg.attacker.location}/${msg.attacker.sequence} '
      'A=${msg.attackerAttack} D=${msg.attackerDefense} P=${msg.attackerPosition}; '
      'def=${msg.defender.controller}/${msg.defender.location}/${msg.defender.sequence} '
      'A=${msg.defenderAttack} D=${msg.defenderDefense} P=${msg.defenderPosition}; '
      'hasDefender=${msg.hasDefender}',
    );
    final attackerSlotId =
        '${msg.attacker.controller}_${msg.attacker.location}_${msg.attacker.sequence}';
    final defenderSlotId = msg.hasDefender
        ? '${msg.defender.controller}_${msg.defender.location}_${msg.defender.sequence}'
        : null;
    battlePresentation =
        (battlePresentation ??
                BattlePresentation(
                  attackerSlotId: attackerSlotId,
                  defenderSlotId: defenderSlotId,
                  attackerName: fieldCards[attackerSlotId]?.name ?? '怪兽',
                  defenderName: defenderSlotId == null
                      ? null
                      : fieldCards[defenderSlotId]?.name ?? '怪兽',
                ))
            .copyWith(
              attackerSlotId: attackerSlotId,
              defenderSlotId: defenderSlotId,
              attackerName: fieldCards[attackerSlotId]?.name ?? '怪兽',
              defenderName: defenderSlotId == null
                  ? null
                  : fieldCards[defenderSlotId]?.name ?? '怪兽',
              attackerAttack: msg.attackerAttack,
              attackerDefense: msg.attackerDefense,
              attackerPosition: msg.attackerPosition,
              defenderAttack: msg.hasDefender ? msg.defenderAttack : null,
              defenderDefense: msg.hasDefender ? msg.defenderDefense : null,
              defenderPosition: msg.hasDefender ? msg.defenderPosition : null,
            );
    if (msg.hasDefender) {
      addLog(
        '${battlePresentation!.attackerName} ${_battleValueLabel(msg.attackerAttack, msg.attackerDefense, msg.attackerPosition)} '
        'VS '
        '${battlePresentation!.defenderName} ${_battleValueLabel(msg.defenderAttack, msg.defenderDefense, msg.defenderPosition)}。',
      );
    } else {
      addLog('${battlePresentation!.attackerName} 进行直接攻击结算。');
    }
  }

  void _handleChainEnd(dynamic data) {
    chains.clear();
  }

  void _handleShuffleHand(dynamic data) {
    applyShuffleHand(data as MsgShuffleHand);
  }

  void _handleShuffleDeck(dynamic data) {
    final msg = data as MsgShuffleDeck;
    addLog('${_playerNameOf(msg.player)} 洗切了卡组。');
    deckShufflePlayer = msg.player;
    deckShuffleTick++;
  }

  void _handleDamageStepStart() {
    inDamageStep = true;
    _battlePresentationTimer?.cancel();
    addLog('进入伤害步骤。');
  }

  void _handleDamageStepEnd() {
    inDamageStep = false;
    addLog('伤害步骤结束。');
    _scheduleBattlePresentationClear();
  }

  void _handleAttackDisabled() {
    inDamageStep = false;
    addLog('此次攻击无效。');
    _scheduleBattlePresentationClear(delay: const Duration(milliseconds: 600));
  }

  void _handleBecomeTarget(MsgBecomeTarget msg) {
    addLog('${msg.count} 张卡成为效果对象。');
  }

  void _handleSelectOption(dynamic data) {
    applySelectOption(data as MsgSelectOption);
  }

  void _handleSelectUnselectCard(dynamic data) {
    applySelectUnselectCard(data as MsgSelectUnselectCard);
  }

  void _handleSelectDisfield(dynamic data) {
    applySelectDisfield(data as MsgSelectPlace);
  }

  void _applyLpChange(int player, int delta) {
    if (player == myController) {
      selfLp += delta;
      selfLpDelta = delta;
      selfLpEventId++;
      return;
    }
    opponentLp += delta;
    opponentLpDelta = delta;
    opponentLpEventId++;
  }

  void _scheduleBattlePresentationClear({
    Duration delay = const Duration(milliseconds: 900),
  }) {
    _battlePresentationTimer?.cancel();
    _battlePresentationTimer = Timer(delay, () {
      battlePresentation = null;
      lastAttackFrom = null;
      lastAttackTo = null;
      notifyListeners();
    });
  }

  String _battleValueLabel(int attack, int defense, int? position) {
    final isDefense = position != null && (position & 0x0c) != 0;
    return isDefense ? 'DEF $defense' : 'ATK $attack';
  }

  void _preloadCardInfos(Iterable<int> codes) {
    for (final code in codes) {
      if (code > 0) {
        unawaited(ensureCardInfo(code));
      }
    }
  }

  // ---- 本地交互状态 ----

  void _inspectCardMut(
    int? code, {
    bool preserveHandSelection = false,
    bool preserveZoneBrowser = false,
  }) {
    if (code == null || code <= 0) return;
    // 主动触发卡信息加载，避免非常规路径（连锁确认等）得知 code 的卡
    // 一直停留在 Card #xxxx 占位。
    unawaited(ensureCardInfo(code));
    _inspectedCardCode = code;
    _inspectedCardInfo = getCardInfo(code);
    console.log('inspectCard: code=$code, info=${_inspectedCardInfo?.name}');
    if (!preserveHandSelection) {
      _selectedHandSequence = null;
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

  void inspectCard(int code) {
    if (code <= 0) return;
    uiSound.playDialogOpen();
    _inspectCardMut(code);
    notifyListeners();
  }

  // ---- 手牌 ----

  void handleHandCardTap(int sequence, int code) {
    _selectedHandSequence = sequence;
    _openZoneBrowserKey = null;
    _selectedZoneBrowserSequence = null;
    _selectedFieldCard = null;
    _showPhaseMenu = false;
    _inspectCardMut(code, preserveHandSelection: true);
    notifyListeners();
  }

  void handleHandCardDoubleTap(int sequence, int code) {
    final action = quickHandActionFor(sequence);
    if (action == null) {
      handleHandCardTap(sequence, code);
      return;
    }
    _selectedHandSequence = null;
    _openZoneBrowserKey = null;
    _selectedZoneBrowserSequence = null;
    _selectedFieldCard = null;
    _showPhaseMenu = false;
    respondCurrentCommand(action.response);
    notifyListeners();
  }

  void handleFieldCardTap(FieldCard? fieldCard, int? code) {
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
    _selectedFieldCard = fieldCard == null || actions.isEmpty
        ? null
        : fieldCard;
    _selectedHandSequence = null;
    _selectedZoneBrowserSequence = null;
    _showPhaseMenu = false;
    notifyListeners();
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
    uiSound.playZoneOpen();
    _selectedHandSequence = null;
    _openZoneBrowserKey = zoneKey;
    _selectedZoneBrowserSequence = null;
    _selectedFieldCard = null;
    _showPhaseMenu = false;
    notifyListeners();
  }

  void closeZoneBrowser() {
    if (_openZoneBrowserKey == null && _selectedZoneBrowserSequence == null) {
      return;
    }
    uiSound.playZoneClose();
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

  void togglePhaseMenu() {
    if (phaseActionsForCurrentWindow().isEmpty) {
      return;
    }
    _showPhaseMenu = !_showPhaseMenu;
    if (_showPhaseMenu) {
      uiSound.playMenuOpen();
    } else {
      uiSound.playMenuClose();
    }
    _selectedHandSequence = null;
    _selectedFieldCard = null;
    notifyListeners();
  }

  /// 当出现更高优先级的选择窗口（非阶段指令）时，本地弹层应当让位。
  bool get needsHigherPriorityDismiss {
    final hasHigherPriorityOverlay =
        currentSelect != null && !hasPhaseCommandWindow;
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
    _selectedZoneBrowserSequence = null;
    _selectedFieldCard = null;
    _openZoneBrowserKey = null;
    _showPhaseMenu = false;
    notifyListeners();
  }

  List<PlaymatResolvedAction> handActionsForCurrentSelection() {
    final selectedSequence = _selectedHandSequence;
    if (selectedSequence == null ||
        selectedSequence < 0 ||
        selectedSequence >= selfHand.length) {
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
    return PlaymatActionResolver.resolveHandActions(
      this,
      myController,
      sequence,
    );
  }

  pkg.CardInfo? cardInfoForHandSequence(int sequence) {
    if (sequence < 0 || sequence >= selfHand.length) {
      return null;
    }
    return getCardInfo(selfHand[sequence]);
  }

  List<PlaymatResolvedAction> phaseActionsForCurrentWindow() {
    return PlaymatActionResolver.resolvePhaseActions(this, myController);
  }

  List<PlaymatResolvedAction> fieldActionsForCard(FieldCard fieldCard) {
    final actions = PlaymatActionResolver.resolveFieldActions(
      this,
      myController,
      fieldCard.controller,
      fieldCard.zone,
      fieldCard.sequence,
      fieldCard.code,
    );
    if (actions.isEmpty &&
        hasIdleCommandWindow &&
        ownsCurrentWindow(myController)) {
      final candidateDebug = selectedIdleActions
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
              _showPhaseMenu = false;
              respondCurrentCommand(action.response);
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
              respondCurrentCommand(action.response);
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
    final cardInfo = getCardInfo(fieldCard.code);
    console.log('dispatchResolvedAction: $cardInfo}');
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
    console.log('dispatchResolvedAction: ${action.kind} ${action.label}');
    if (!respondCurrentCommand(action.response)) {
      return;
    }
    _selectedHandSequence = null;
    _selectedFieldCard = null;
    _showPhaseMenu = false;
    if (closeZoneBrowser) {
      _openZoneBrowserKey = null;
      _selectedZoneBrowserSequence = null;
    }
    notifyListeners();
  }

  List<ZoneBrowserCardEntry> zoneBrowserEntriesFor(String zoneKey) {
    final sequenceToCode = <int, int>{};
    final codes = getZoneCodes(zoneKey);
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
        hasIdleCommandWindow &&
        ownsCurrentWindow(myController)) {
      for (final action in selectedIdleActions) {
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
          this,
          myController,
          controller,
          location,
          entry.code,
          selectedSequence,
        )
        .map((action) {
          final cardInfo = getCardInfo(entry.code);
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
        return selfGrave;
      case 'opp_grave':
        return oppGrave;
      case 'self_removed':
        return selfRemoved;
      case 'opp_removed':
        return oppRemoved;
      case 'self_extra':
        return selfExtra;
      case 'opp_extra':
        return oppExtra;
      default:
        return 0;
    }
  }

  int? _controllerForZoneKey(String zoneKey) {
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

  StreamSubscription<YgoStocMsg>? _msgSub;
  StreamSubscription<DuelPhase>? _phaseSub;
  void bindServerMessage(BuildContext context) {
    _phaseSub = _duelService?.onDuelPhaseMessage.listen((phase) {
      if (!context.mounted) return;
      this.phase = phase;
      // 阶段合法性（enableBp/enableM2/enableEp）只由服务端下发的
      // MSG_SELECT_IDLE_CMD / MSG_SELECT_BATTLE_CMD 驱动，这里不做本地推断。
      final phaseName = getDuelPhaseText(context, phase);
      if (phaseName?.isNotEmpty == true) addLog('$phaseName 开始。');
      notifyListeners();
    });
    _msgSub = _duelService?.onServerMessage.listen((msg) {
      console.log('Received server message: $msg ${msg.gameMsg?.func}');
      handleServerMessage(msg);
    });
  }
}
