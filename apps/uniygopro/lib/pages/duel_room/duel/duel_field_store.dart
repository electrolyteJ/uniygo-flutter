import 'dart:async';
import 'dart:developer' as console;

import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:uniygopro/service_singleton.dart';
import 'package:ygo_data/card_info.dart' as pkg;

import '../../../models/BattleAction.dart';
import '../../../models/ChainLink.dart';
import '../../../models/FieldCard.dart';
import '../../../models/IdleAction.dart';
import '../../../models/SelectState.dart';

/// 对局状态仓库（服务器驱动），全局唯一。
///
/// 战场部分：场上卡片、手牌、墓地/除外/额外卡组数量、LP、阶段、连锁，
/// 以及对局渲染需要的卡片信息缓存。
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
  int myController = 0;

  List<ChainLink> chains = [];
  String? lastSummonKey;
  String? lastAttackFrom;
  String? lastAttackTo;
  String? errorMessage;
  final dataService = ServiceSingleton.instance.dataService;

  /// 卡片信息缓存：code → CardInfo（从本地 SQLite 查询）
  final Map<int, pkg.CardInfo> _cardInfoCache = {};

  // ──────────────────────────────────────────
  // 选择态
  // ──────────────────────────────────────────

  List<IdleAction> selectedIdleActions = [];
  List<BattleAction> selectedBattleActions = [];
  bool enableBp = false;
  bool enableM2 = false;
  bool enableEp = false;
  SelectState? currentSelect;

  bool get isWaitingForInput => currentSelect != null;
  bool get hasIdleCommandWindow => currentSelect?.type == SelectType.idleCmd;
  bool get hasBattleCommandWindow =>
      currentSelect?.type == SelectType.battleCmd;
  bool get hasPhaseCommandWindow =>
      hasIdleCommandWindow || hasBattleCommandWindow;
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
    errorMessage = null;
    selectedIdleActions = [];
    selectedBattleActions = [];
    enableBp = false;
    enableM2 = false;
    enableEp = false;
    currentSelect = null;
    notifyListeners();
  }

  /// 供页面在批量字段赋值后显式触发刷新。
  void markChanged() {
    notifyListeners();
  }

  // ──────────────────────────────────────────
  // 卡片信息缓存
  // ──────────────────────────────────────────

  /// 获取卡片信息（优先从缓存读取，未命中则异步查 DB 并缓存）
  pkg.CardInfo? getCardInfo(int code) => _cardInfoCache[code];

  /// 异步预加载卡片信息到缓存
  Future<void> ensureCardInfo(int code) async {
    if (_cardInfoCache.containsKey(code)) return;
    try {
      final info = await dataService.getCard(code);
      if (info != null) {
        _cardInfoCache[code] = info;
        notifyListeners();
      }
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
            _seedZonePlaceholder(
              isSelf ? selfExtraCodes : opponentExtraCodes,
              action.sequence,
            );
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
            if (action.zone & CARD_ZONE_ONFIELD != 0) {
              fieldCards['${playerState.player}_${action.zone}_${action.sequence}'] =
                  FieldCard(
                    code: 0,
                    controller: playerState.player,
                    zone: action.zone,
                    sequence: action.sequence,
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
      final key = '${action.controller}_${action.zone}_${action.sequence}';
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
    final key =
        '${msg.cardInfo.controller}_${msg.cardInfo.location}_${msg.cardInfo.sequence}';
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
    final key =
        '${location.controller}_${location.location}_${location.sequence}';
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
    } else if (location & CARD_ZONE_ONFIELD != 0) {
      fieldCards.remove('${controller}_${location}_$sequence');
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
    } else if (location & CARD_ZONE_ONFIELD != 0) {
      fieldCards['${controller}_${location}_$sequence'] = FieldCard(
        code: code,
        controller: controller,
        zone: location,
        sequence: sequence,
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
    final name = _cardInfoCache[msg.code]?.name ?? '卡片';
    return name;
  }

  String? handleSummoning(dynamic data) {
    final msg = data as MsgSummoning;
    lastSummonKey =
        '${msg.location.controller}_${msg.location.location}_${msg.location.sequence}';
    unawaited(ensureCardInfo(msg.code));
    final name = _cardInfoCache[msg.code]?.name ?? '怪兽';
    return name;
  }

  FieldCard? handlePosChange(dynamic data) {
    final msg = data as MsgPosChange;
    applyPosChange(msg);
    final key =
        '${msg.cardInfo.controller}_${msg.cardInfo.location}_${msg.cardInfo.sequence}';
    final card = fieldCards[key];
    return card;
  }

  void setFieldCard(FieldCard card) {
    fieldCards[card.key] = card;
    notifyListeners();
  }

  void removeFieldCard(int controller, int zone, int sequence) {
    fieldCards.remove('${controller}_${zone}_$sequence');
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

  void setError(int type, int code) {
    errorMessage = _errorMessage(type, code);
    notifyListeners();
  }

  String _errorMessage(int type, int code) {
    switch (type) {
      case 1:
        return '连接已断开';
      case 2:
        return '你已经被踢出房间';
      case 3:
        return '错误: $code';
      case 4:
        return '卡组无效 (错误码: $code)';
      case 5:
        return '卡组数量不正确 (错误码: $code)';
      case 6:
        return '主卡组需要至少40张';
      case 7:
        return '额外卡组不能超过15张';
      case 8:
        return '副卡组不能超过15张';
      case 9:
        return '禁限卡表不匹配';
      default:
        return '服务器错误: type=$type code=$code';
    }
  }

  void clearError() {
    errorMessage = null;
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
    notifyListeners();
  }

  void respondIdleCmd(int sequence) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectIdleCmd(sequence));
    clearSelect();
  }

  void respondBattleCmd(int sequence) {
    _duelService?.playGameResponse(
      CtosGameMsgResponse.selectBattleCmd(sequence),
    );
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
    _duelService?.playGameResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSelectChain(int sequence) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectSingle(sequence));
    clearSelect();
  }

  void respondSelectEffectYn(bool yes) {
    _duelService?.playGameResponse(
      CtosGameMsgResponse.selectEffectYn(yes ? 1 : 0),
    );
    clearSelect();
  }

  void respondSelectYesNo(bool yes) {
    _duelService?.playGameResponse(
      CtosGameMsgResponse.selectEffectYn(yes ? 1 : 0),
    );
    clearSelect();
  }

  void respondSelectPosition(int position) {
    _duelService?.playGameResponse(
      CtosGameMsgResponse.selectPosition(position),
    );
    clearSelect();
  }

  void respondSelectOption(int sequence) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectOption(sequence));
    clearSelect();
  }

  void respondSelectPlace(int player, int zone, int sequence) {
    _duelService?.playGameResponse(
      CtosGameMsgResponse.selectPlace(
        CtosSelectPlace(player: player, zone: zone, sequence: sequence),
      ),
    );
    clearSelect();
  }

  void respondSelectTribute(List<int> sequences) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSelectCounter(List<int> values) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectCounter(values));
    clearSelect();
  }

  void respondSelectSum(List<int> sequences) {
    _duelService?.playGameResponse(CtosGameMsgResponse.selectMulti(sequences));
    clearSelect();
  }

  void respondSortCard(List<int> indices) {
    _duelService?.playGameResponse(CtosGameMsgResponse.sortCard(indices));
    clearSelect();
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
    final options = <SelectOption>[];
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
          SelectOption(code: msg.codes[index], sequence: index),
      ],
      min: 1,
      max: 1,
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
    currentSelect = SelectState(
      type: SelectType.card,
      player: msg.player,
      options: options,
      min: msg.min,
      max: msg.max,
      cancelable: msg.cancelable,
    );
  }

  void applySelectDisfield(MsgSelectPlace msg) {
    final options = <SelectOption>[];
    for (int bit = 0; bit < 32; bit++) {
      if ((msg.field & (1 << bit)) == 0) continue;
      options.add(
        SelectOption(
          code: 0,
          controller: bit >= 16 ? 1 : 0,
          zone: bit < 8 || (bit >= 16 && bit < 24)
              ? CARD_ZONE_MZONE
              : CARD_ZONE_SZONE,
          sequence: bit % 8,
        ),
      );
    }
    currentSelect = SelectState(
      type: SelectType.place,
      player: msg.player,
      options: options,
      min: msg.count,
      max: msg.count,
      cancelable: false,
    );
  }
}
