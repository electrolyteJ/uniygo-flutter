import 'dart:async';
import 'dart:developer' as console;

import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:service_loader/service_loader.dart';
import 'package:ygo_card/card_info.dart' as pkg;
import 'package:ygo_card_mycard/ygo_card_mycard.dart';

import '../../../models/ChainLink.dart';
import '../../../models/FieldCard.dart';

/// 对局战场状态仓库。
///
/// 负责维护场上卡片、手牌、墓地/除外/额外卡组数量、LP、
/// 阶段、连锁，以及对局渲染需要的卡片信息缓存。
class DuelBoardStore extends ChangeNotifier {
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
  IDuelService? _service;
  String? errorMessage;
  final cardService = ServiceFactory.create<CardService>();
  /// 卡片信息缓存：code → CardInfo（从本地 SQLite 查询）
  final Map<int, pkg.CardInfo> _cardInfoCache = {};

  /// 获取卡片信息（优先从缓存读取，未命中则异步查 DB 并缓存）
  pkg.CardInfo? getCardInfo(int code) => _cardInfoCache[code];

  /// 异步预加载卡片信息到缓存
  Future<void> ensureCardInfo(int code) async {
    if (_cardInfoCache.containsKey(code)) return;
    try {
      final info = await cardService.getCard(code);
      if (info != null) {
        _cardInfoCache[code] = info;
      }
    } catch (e) {
      console.log('Failed to load card info for $code: $e');
    }
  }

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
    notifyListeners();
  }

  void markChanged() {
    notifyListeners();
  }

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
            break;
          case CARD_ZONE_GRAVE:
            grave++;
            break;
          case CARD_ZONE_REMOVED:
            removed++;
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
    await ensureCardInfo(code);
    enrichFieldCard(code, controller, location, sequence);
    notifyListeners();
  }

  void enrichFieldCard(int code, int controller, int location, int sequence) {
    final info = getCardInfo(code);
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
      disabled: card.disabled,
      attack: info.attack >= 0 ? info.attack : null,
      defense: info.defense >= 0 ? info.defense : null,
      name: info.name,
    );
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
          unawaited(ensureCardInfo(code));
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
        unawaited(ensureCardInfo(code));
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
        unawaited(ensureCardInfo(code));
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
        unawaited(ensureCardInfo(code));
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

  void bind(IDuelService duelService) {
    _service = duelService;
  }

  String getCardImageUrl(int code) {
    return cardService.getCardImageUrl(code);
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
}
