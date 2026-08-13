import 'dart:async';
import 'dart:developer' as console;

import 'package:biz/ygo_data_service.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ygo_data/card_info.dart' as pkg;

import '../../providers/service_providers.dart';
import '../../models/battle_presentation.dart';
import '../../models/chain_link.dart';
import '../../models/duel_result_summary.dart';
import '../../models/field_card.dart';
import '../../models/field_zone_key.dart';

/// MSG_SELECT_OPTION / MSG_HINT 的 description 值里可能携带卡密
/// （直接是卡密，或高 4 位标记 + 卡密），无法解析时返回 null。
int? cardCodeFromDescriptionValue(int value) {
  if (value <= 0) return null;
  if (value >= 1000000 && value <= 99999999) return value;
  final code = value >> 4;
  if (code < 1000000 || code > 99999999) return null;
  return code;
}

/// 对局事实状态：服务器写入的战场数据。
///
/// 场上卡片、手牌、墓地/除外/额外卡组、LP、阶段、回合、连锁、战斗演出、
/// 战报日志、对局结果，以及全部 MSG_* 战场消息的应用逻辑
/// （与 duel_room1 保持逐字节一致）。
///
/// 刻意保留「就地修改 + 显式 [emit]」的语义：[emit] 由 [DuelFieldNotifier]
/// 注入 `ref.notifyListeners`，等价于原 ChangeNotifier 的 notifyListeners，
/// 避免在拆分过程中引入行为回归。
class DuelFieldState {
  DuelFieldState({required this.dataService});

  /// 状态变更通知，由 [DuelFieldNotifier] 注入（ref.notifyListeners）。
  void Function() emit = () {};

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

  /// 回合剩余时间（秒），由 STOC_TIME_LIMIT 驱动。0=无限制。
  int selfTimeLeft = 0;
  int opponentTimeLeft = 0;
  Timer? _timeLimitTimer;

  /// 己方引擎玩家编号（0/1），由 MSG_START 的 playerType 确定
  /// （低 nibble 0 = 引擎 0 号玩家 = 惯例先攻方）。房间座位号 ≠ 引擎编号，
  /// 不能从 selfPlayer.pos 推断。
  int myController = 0;

  List<ChainLink> chains = [];
  /// 连锁组建阶段已结束，不再有新的连锁入链（MSG_CHAIN_SOLVING 之后）。
  bool chainSealed = false;
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
  final YgoDataService dataService;

  /// 卡组洗切信号：每次 MSG_SHUFFLE_DECK 自增，驱动场地洗牌动效。
  int deckShuffleTick = 0;
  int deckShufflePlayer = 0;

  /// 对局日志（战报），供日志抽屉展示。
  final List<String> duelLogs = [];

  /// 玩家名解析所需的房间玩家列表，由页面在房间阶段变化时同步。
  List<PlayerInfo> players = [];

  DuelResultSummary? duelResult;

  // ──────────────────────────────────────────
  // 生命周期
  // ──────────────────────────────────────────

  /// Provider 销毁时兜底取消定时器（流订阅由协调器负责）。
  void dispose() {
    _timeLimitTimer?.cancel();
    _battlePresentationTimer?.cancel();
  }

  /// 清空战场状态（对局事实），供离开房间或新对局开始时使用。
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
    chainSealed = false;
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
    duelResult = null;
    duelLogs.clear();
    players = [];
    deckShuffleTick = 0;
    deckShufflePlayer = 0;
    emit();
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
      if (info != null) emit();
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
            if (isOnFieldLocation(action.zone)) {
              final normalizedZone = _normalizeFieldZone(action.zone);
              final normalizedSequence = _normalizeFieldSequence(
                action.zone,
                action.sequence,
              );
              fieldCards[fieldCardKey(
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
      final key = fieldCardKey(
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
    final key = fieldCardKey(
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
    final key = fieldCardKey(
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

    if (isOnFieldLocation(zone)) {
      final normalizedZone = _normalizeFieldZone(zone);
      final normalizedSequence = _normalizeFieldSequence(zone, sequence);
      final key = fieldCardKey(controller, zone, sequence);
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
      emit();
      return;
    }
    for (var i = 0; i < selfExtraCodes.length && i < codes.length; i++) {
      if (selfExtraCodes[i] <= 0) {
        selfExtraCodes[i] = codes[i];
      }
    }
    emit();
  }

  bool isOnFieldLocation(int location) {
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

  String fieldCardKey(int controller, int zone, int sequence) {
    final normalizedZone = _normalizeFieldZone(zone);
    final normalizedSequence = _normalizeFieldSequence(zone, sequence);
    return zoneKeyOf(controller, normalizedZone, normalizedSequence);
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
    } else if (isOnFieldLocation(location)) {
      fieldCards.remove(fieldCardKey(controller, location, sequence));
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
    } else if (isOnFieldLocation(location)) {
      final normalizedZone = _normalizeFieldZone(location);
      final normalizedSequence = _normalizeFieldSequence(location, sequence);
      fieldCards[fieldCardKey(controller, location, sequence)] = FieldCard(
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
        zoneKeyOf(msg.location.controller, msg.location.location, msg.location.sequence);
    unawaited(ensureCardInfo(msg.code));
    final name = getCardInfo(msg.code)?.name ?? '怪兽';
    return name;
  }

  FieldCard? handlePosChange(dynamic data) {
    final msg = data as MsgPosChange;
    applyPosChange(msg);
    final key = fieldCardKey(
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
    fieldCards[fieldCardKey(
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
    emit();
  }

  void removeFieldCard(int controller, int zone, int sequence) {
    fieldCards.remove(fieldCardKey(controller, zone, sequence));
    emit();
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
    emit();
  }

  // ──────────────────────────────────────────
  // 战报与玩家
  // ──────────────────────────────────────────

  /// 记录对局日志并触发刷新。
  void addLog(String log) {
    duelLogs.add(log);
    emit();
  }

  /// 同步房间玩家列表，供日志文案解析玩家名。
  void syncPlayers(List<PlayerInfo> players) {
    this.players = players;
  }

  String playerNameOf(int pos) {
    return players
        .firstWhere(
          (p) => p.pos == pos,
          orElse: () => PlayerInfo(name: '玩家$pos', pos: pos),
        )
        .name;
  }

  // ──────────────────────────────────────────
  // 服务器消息处理（战场部分）
  // ──────────────────────────────────────────

  void handleStart(dynamic data) {
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

  void handleNewTurn(dynamic data) {
    final msg = data as MsgNewTurn;
    currentPlayer = msg.player;
    turnCount++;
    addLog('${playerNameOf(msg.player)} 的回合。');
  }

  void handleWaiting(MsgWait msg) {
    addLog('等待对手操作。');
  }

  void handleAttack(dynamic data) {
    final msg = data as MsgAttack;
    lastAttackFrom =
        zoneKeyOf(msg.attacker.controller, msg.attacker.location, msg.attacker.sequence);

    if (msg.target != null) {
      lastAttackTo =
          zoneKeyOf(msg.target!.controller, msg.target!.location, msg.target!.sequence);
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

  void handleDamage(dynamic data) {
    final msg = data as MsgDamage;
    _applyLpChange(msg.player, -msg.value);
    addLog('${playerNameOf(msg.player)} 受到 ${msg.value} 点伤害。');
  }

  void handleRecover(dynamic data) {
    final msg = data as MsgRecover;
    _applyLpChange(msg.player, msg.value);
    addLog('${playerNameOf(msg.player)} 回复了 ${msg.value} 点生命值。');
  }

  void handleLpUpdate(dynamic data) {
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

  void handlePayLife(dynamic data) {
    final msg = data as MsgPayLpCost;
    _applyLpChange(msg.player, -msg.value);
    addLog('${playerNameOf(msg.player)} 支付了 ${msg.value} 点生命值。');
  }

  void syncConfirmedCard(CardInfo card) {
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

    if (isOnFieldLocation(location)) {
      final key = fieldCardKey(controller, location, sequence);
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

  void handleChained(MsgChained msg) {
    addLog('连锁 ${msg.chainIndex + 1} 已入链。');
  }

  void handleChainSolving(MsgChainSolving msg) {
    addLog('正在处理连锁 ${msg.chainIndex + 1}。');
  }

  void handleChainSolved(MsgChainSolved msg) {
    addLog('连锁 ${msg.solvedIndex + 1} 处理完成。');
  }

  void handleSummonPreparing(
    int code,
    CardLocation location, {
    required String actionLabel,
  }) {
    lastSummonKey =
        zoneKeyOf(location.controller, location.location, location.sequence);
    if (code > 0) {
      unawaited(ensureCardInfo(code));
    }
    final name = getCardInfo(code)?.name ?? '怪兽';
    addLog('正在$actionLabel $name。');
  }

  void handleSummonFinished(String actionLabel) {
    final key = lastSummonKey;
    final name = key != null ? fieldCards[key]?.name ?? '怪兽' : '怪兽';
    lastSummonKey = null;
    addLog('$name $actionLabel成功。');
  }

  void handleHint(MsgHint msg) {
    final code = cardCodeFromDescriptionValue(msg.hintData);
    if (code != null && code >= 1000000) {
      unawaited(ensureCardInfo(code));
    }
  }

  void handleWin(MsgWin msg) {
    final didWin = msg.winPlayer == myController;
    duelResult = DuelResultSummary(
      didWin: didWin,
      winPlayer: msg.winPlayer,
      reason: msg.reason,
      selfName: playerNameOf(myController),
      opponentName: playerNameOf(1 - myController),
      selfLp: selfLp,
      opponentLp: opponentLp,
    );
    addLog(didWin ? '决斗胜利。' : '决斗失败。');
  }

  void handleSet(MsgSet msg) {
    if (msg.code > 0) {
      unawaited(ensureCardInfo(msg.code));
    }
    final name = getCardInfo(msg.code)?.name ?? '卡片';
    addLog('$name 已盖放。');
  }

  void handleBattle(MsgBattle msg) {
    applyBattle(msg);
    console.log(
      'MSG_BATTLE: atk=${msg.attacker.controller}/${msg.attacker.location}/${msg.attacker.sequence} '
      'A=${msg.attackerAttack} D=${msg.attackerDefense} P=${msg.attackerPosition}; '
      'def=${msg.defender.controller}/${msg.defender.location}/${msg.defender.sequence} '
      'A=${msg.defenderAttack} D=${msg.defenderDefense} P=${msg.defenderPosition}; '
      'hasDefender=${msg.hasDefender}',
    );
    final attackerSlotId =
        zoneKeyOf(msg.attacker.controller, msg.attacker.location, msg.attacker.sequence);
    final defenderSlotId = msg.hasDefender
        ? zoneKeyOf(msg.defender.controller, msg.defender.location, msg.defender.sequence)
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

  void handleChainEnd(dynamic data) {
    chains.clear();
  }

  void handleShuffleDeck(dynamic data) {
    final msg = data as MsgShuffleDeck;
    addLog('${playerNameOf(msg.player)} 洗切了卡组。');
    deckShufflePlayer = msg.player;
    deckShuffleTick++;
  }

  void handleDamageStepStart() {
    inDamageStep = true;
    _battlePresentationTimer?.cancel();
    addLog('进入伤害步骤。');
  }

  void handleDamageStepEnd() {
    inDamageStep = false;
    addLog('伤害步骤结束。');
    scheduleBattlePresentationClear();
  }

  void handleAttackDisabled() {
    inDamageStep = false;
    addLog('此次攻击无效。');
    scheduleBattlePresentationClear(delay: const Duration(milliseconds: 600));
  }

  void handleBecomeTarget(MsgBecomeTarget msg) {
    addLog('${msg.count} 张卡成为效果对象。');
  }

  void handleTimeLimit(StocTimeLimit msg) {
    final left = msg.leftTime;
    if (msg.player == myController) {
      selfTimeLeft = left;
    } else {
      opponentTimeLeft = left;
    }
    _timeLimitTimer?.cancel();
    if (left > 0) {
      _timeLimitTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (msg.player == myController) {
            if (selfTimeLeft > 0) selfTimeLeft--;
          } else {
            if (opponentTimeLeft > 0) opponentTimeLeft--;
          }
          if (selfTimeLeft <= 0 && opponentTimeLeft <= 0) {
            _timeLimitTimer?.cancel();
          }
          emit();
        },
      );
    }
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

  void scheduleBattlePresentationClear({
    Duration delay = const Duration(milliseconds: 900),
  }) {
    _battlePresentationTimer?.cancel();
    _battlePresentationTimer = Timer(delay, () {
      battlePresentation = null;
      lastAttackFrom = null;
      lastAttackTo = null;
      emit();
    });
  }

  String _battleValueLabel(int attack, int defense, int? position) {
    final isDefense = position != null && (position & 0x0c) != 0;
    return isDefense ? 'DEF $defense' : 'ATK $attack';
  }

  void preloadCardInfos(Iterable<int> codes) {
    for (final code in codes) {
      if (code > 0) {
        unawaited(ensureCardInfo(code));
      }
    }
  }

  /// onDuelPhaseMessage 流驱动：更新阶段并按需记战报。
  ///
  /// 阶段合法性（enableBp/enableM2/enableEp）只由服务端下发的
  /// MSG_SELECT_IDLE_CMD / MSG_SELECT_BATTLE_CMD 驱动，这里不做本地推断。
  void setPhaseFromStream(DuelPhase phase, String? phaseName) {
    this.phase = phase;
    if (phaseName?.isNotEmpty == true) addLog('$phaseName 开始。');
    emit();
  }
}

/// 对局事实（战场）的 Notifier：仅负责持有状态与生命周期，
/// 消息应用逻辑全部在 [DuelFieldState] 内，与 duel_room1 逐字节一致。
class DuelFieldNotifier extends Notifier<DuelFieldState> {
  @override
  DuelFieldState build() {
    final state = DuelFieldState(
      dataService: ref.watch(dataServiceProvider),
    );
    state.emit = ref.notifyListeners;
    ref.onDispose(state.dispose);
    return state;
  }
}

/// 对局事实状态（战场）的 provider，按房间 ProviderScope override 隔离。
final duelFieldProvider =
    NotifierProvider<DuelFieldNotifier, DuelFieldState>(DuelFieldNotifier.new);
