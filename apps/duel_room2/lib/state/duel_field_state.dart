import 'dart:async';
import 'dart:developer' as console;

import 'package:biz/ygo_data_service.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ygo_data/card_info.dart' as pkg;

import '../../providers/service_providers.dart';
import '../../models/battle_presentation.dart';
import '../../models/chain_link.dart';
import '../../models/duel_result_summary.dart';
import '../../models/field_card.dart';
import '../../models/field_zone_key.dart';

const Object _undefined = Object();

/// MSG_SELECT_OPTION / MSG_HINT 的 description 值里可能携带卡密
/// （直接是卡密，或高 4 位标记 + 卡密），无法解析时返回 null。
int? cardCodeFromDescriptionValue(int value) {
  if (value <= 0) return null;
  if (value >= 1000000 && value <= 99999999) return value;
  final code = value >> 4;
  if (code < 1000000 || code > 99999999) return null;
  return code;
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

/// 对局事实状态：服务器写入的战场数据，不可变快照。
///
/// 字段全部只读，变更一律通过 [copyWith] 生成新快照；
/// 所有写逻辑（MSG_* 战场消息应用）收敛在 [DuelFieldNotifier]。
@immutable
class DuelFieldState {
  const DuelFieldState({
    this.fieldCards = const {},
    this.selfHand = const [],
    this.opponentHand = const [],
    this.selfGraveCodes = const [],
    this.opponentGraveCodes = const [],
    this.selfRemovedCodes = const [],
    this.opponentRemovedCodes = const [],
    this.selfExtraCodes = const [],
    this.opponentExtraCodes = const [],
    this.knownSelfExtraDeckCodes = const [],
    this.selfDeck = 0,
    this.selfExtra = 0,
    this.selfGrave = 0,
    this.selfRemoved = 0,
    this.oppDeck = 0,
    this.oppExtra = 0,
    this.oppGrave = 0,
    this.oppRemoved = 0,
    this.selfLp = 8000,
    this.opponentLp = 8000,
    this.currentPlayer = 0,
    this.phase = DuelPhase.idle,
    this.turnCount = 0,
    this.selfTimeLeft = 0,
    this.opponentTimeLeft = 0,
    this.myController = 0,
    this.chains = const [],
    this.chainSealed = false,
    this.lastSummonKey,
    this.lastAttackFrom,
    this.lastAttackTo,
    this.battlePresentation,
    this.inDamageStep = false,
    this.selfLpDelta = 0,
    this.opponentLpDelta = 0,
    this.selfLpEventId = 0,
    this.opponentLpEventId = 0,
    this.deckShuffleTick = 0,
    this.deckShufflePlayer = 0,
    this.duelLogs = const [],
    this.players = const [],
    this.duelResult,
  });

  /// 当前场上可见卡片，key 格式为 `controller_zone_sequence`。
  final Map<String, FieldCard> fieldCards;
  final List<int> selfHand;
  final List<int> opponentHand;
  final List<int> selfGraveCodes;
  final List<int> opponentGraveCodes;
  final List<int> selfRemovedCodes;
  final List<int> opponentRemovedCodes;
  final List<int> selfExtraCodes;
  final List<int> opponentExtraCodes;
  final List<int> knownSelfExtraDeckCodes;
  final int selfDeck;
  final int selfExtra;
  final int selfGrave;
  final int selfRemoved;
  final int oppDeck;
  final int oppExtra;
  final int oppGrave;
  final int oppRemoved;
  final int selfLp;
  final int opponentLp;
  final int currentPlayer;
  final DuelPhase phase;
  final int turnCount;

  /// 回合剩余时间（秒），由 STOC_TIME_LIMIT 驱动。0=无限制。
  final int selfTimeLeft;
  final int opponentTimeLeft;

  /// 己方引擎玩家编号（0/1），由 MSG_START 的 playerType 确定
  /// （低 nibble 0 = 引擎 0 号玩家 = 惯例先攻方）。房间座位号 ≠ 引擎编号，
  /// 不能从 selfPlayer.pos 推断。
  final int myController;

  final List<ChainLink> chains;

  /// 连锁组建阶段已结束，不再有新的连锁入链（MSG_CHAIN_SOLVING 之后）。
  final bool chainSealed;
  final String? lastSummonKey;
  final String? lastAttackFrom;
  final String? lastAttackTo;
  final BattlePresentation? battlePresentation;
  final bool inDamageStep;
  final int selfLpDelta;
  final int opponentLpDelta;
  final int selfLpEventId;
  final int opponentLpEventId;

  /// 卡组洗切信号：每次 MSG_SHUFFLE_DECK 自增，驱动场地洗牌动效。
  final int deckShuffleTick;
  final int deckShufflePlayer;

  /// 对局日志（战报），供日志抽屉展示。
  final List<String> duelLogs;

  /// 玩家名解析所需的房间玩家列表，由页面在房间阶段变化时同步。
  final List<PlayerInfo> players;

  final DuelResultSummary? duelResult;

  DuelFieldState copyWith({
    Map<String, FieldCard>? fieldCards,
    List<int>? selfHand,
    List<int>? opponentHand,
    List<int>? selfGraveCodes,
    List<int>? opponentGraveCodes,
    List<int>? selfRemovedCodes,
    List<int>? opponentRemovedCodes,
    List<int>? selfExtraCodes,
    List<int>? opponentExtraCodes,
    List<int>? knownSelfExtraDeckCodes,
    int? selfDeck,
    int? selfExtra,
    int? selfGrave,
    int? selfRemoved,
    int? oppDeck,
    int? oppExtra,
    int? oppGrave,
    int? oppRemoved,
    int? selfLp,
    int? opponentLp,
    int? currentPlayer,
    DuelPhase? phase,
    int? turnCount,
    int? selfTimeLeft,
    int? opponentTimeLeft,
    int? myController,
    List<ChainLink>? chains,
    bool? chainSealed,
    Object? lastSummonKey = _undefined,
    Object? lastAttackFrom = _undefined,
    Object? lastAttackTo = _undefined,
    Object? battlePresentation = _undefined,
    bool? inDamageStep,
    int? selfLpDelta,
    int? opponentLpDelta,
    int? selfLpEventId,
    int? opponentLpEventId,
    int? deckShuffleTick,
    int? deckShufflePlayer,
    List<String>? duelLogs,
    List<PlayerInfo>? players,
    Object? duelResult = _undefined,
  }) {
    return DuelFieldState(
      fieldCards: fieldCards ?? this.fieldCards,
      selfHand: selfHand ?? this.selfHand,
      opponentHand: opponentHand ?? this.opponentHand,
      selfGraveCodes: selfGraveCodes ?? this.selfGraveCodes,
      opponentGraveCodes: opponentGraveCodes ?? this.opponentGraveCodes,
      selfRemovedCodes: selfRemovedCodes ?? this.selfRemovedCodes,
      opponentRemovedCodes: opponentRemovedCodes ?? this.opponentRemovedCodes,
      selfExtraCodes: selfExtraCodes ?? this.selfExtraCodes,
      opponentExtraCodes: opponentExtraCodes ?? this.opponentExtraCodes,
      knownSelfExtraDeckCodes:
          knownSelfExtraDeckCodes ?? this.knownSelfExtraDeckCodes,
      selfDeck: selfDeck ?? this.selfDeck,
      selfExtra: selfExtra ?? this.selfExtra,
      selfGrave: selfGrave ?? this.selfGrave,
      selfRemoved: selfRemoved ?? this.selfRemoved,
      oppDeck: oppDeck ?? this.oppDeck,
      oppExtra: oppExtra ?? this.oppExtra,
      oppGrave: oppGrave ?? this.oppGrave,
      oppRemoved: oppRemoved ?? this.oppRemoved,
      selfLp: selfLp ?? this.selfLp,
      opponentLp: opponentLp ?? this.opponentLp,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      phase: phase ?? this.phase,
      turnCount: turnCount ?? this.turnCount,
      selfTimeLeft: selfTimeLeft ?? this.selfTimeLeft,
      opponentTimeLeft: opponentTimeLeft ?? this.opponentTimeLeft,
      myController: myController ?? this.myController,
      chains: chains ?? this.chains,
      chainSealed: chainSealed ?? this.chainSealed,
      lastSummonKey: identical(lastSummonKey, _undefined)
          ? this.lastSummonKey
          : lastSummonKey as String?,
      lastAttackFrom: identical(lastAttackFrom, _undefined)
          ? this.lastAttackFrom
          : lastAttackFrom as String?,
      lastAttackTo: identical(lastAttackTo, _undefined)
          ? this.lastAttackTo
          : lastAttackTo as String?,
      battlePresentation: identical(battlePresentation, _undefined)
          ? this.battlePresentation
          : battlePresentation as BattlePresentation?,
      inDamageStep: inDamageStep ?? this.inDamageStep,
      selfLpDelta: selfLpDelta ?? this.selfLpDelta,
      opponentLpDelta: opponentLpDelta ?? this.opponentLpDelta,
      selfLpEventId: selfLpEventId ?? this.selfLpEventId,
      opponentLpEventId: opponentLpEventId ?? this.opponentLpEventId,
      deckShuffleTick: deckShuffleTick ?? this.deckShuffleTick,
      deckShufflePlayer: deckShufflePlayer ?? this.deckShufflePlayer,
      duelLogs: duelLogs ?? this.duelLogs,
      players: players ?? this.players,
      duelResult: identical(duelResult, _undefined)
          ? this.duelResult
          : duelResult as DuelResultSummary?,
    );
  }

  // ──────────────────────────────────────────
  // 纯派生读取（不依赖外部服务，留在 state 上）
  // ──────────────────────────────────────────

  bool isOnFieldLocation(int location) {
    return (location & CARD_ZONE_ONFIELD) != 0 ||
        (location & CARD_ZONE_FZONE) != 0;
  }

  String fieldCardKey(int controller, int zone, int sequence) {
    final normalizedZone = _normalizeFieldZone(zone);
    final normalizedSequence = _normalizeFieldSequence(zone, sequence);
    return zoneKeyOf(controller, normalizedZone, normalizedSequence);
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

  /// 指定控制者在 GRAVE/REMOVED/EXTRA 区域的卡密列表，非这些区域返回 null。
  List<int>? zoneCodeListFor(int controller, int location) {
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

  String playerNameOf(int pos) {
    return players
        .firstWhere(
          (p) => p.pos == pos,
          orElse: () => PlayerInfo(name: '玩家$pos', pos: pos),
        )
        .name;
  }
}

/// 对局事实（战场）的 Notifier：持有全部 MSG_* 战场消息应用逻辑。
class DuelFieldNotifier extends Notifier<DuelFieldState> {
  late YgoDataService _dataService;
  Timer? _timeLimitTimer;
  Timer? _battlePresentationTimer;
  bool _disposed = false;

  @override
  DuelFieldState build() {
    _dataService = ref.watch(dataServiceProvider);
    ref.onDispose(_dispose);
    return const DuelFieldState();
  }

  void _dispose() {
    _disposed = true;
    _timeLimitTimer?.cancel();
    _battlePresentationTimer?.cancel();
  }

  /// 清空战场状态（对局事实），供离开房间或新对局开始时使用。
  void reset() {
    _battlePresentationTimer?.cancel();
    _battlePresentationTimer = null;
    // 倒计时不在 reset 范围内（与原实现一致）。
    state = DuelFieldState(
      selfTimeLeft: state.selfTimeLeft,
      opponentTimeLeft: state.opponentTimeLeft,
    );
  }

  // ──────────────────────────────────────────
  // 卡片信息（缓存收敛在 dataService）
  // ──────────────────────────────────────────

  /// 获取卡片信息（同步读取 dataService 缓存，未命中返回 null）
  pkg.CardInfo? getCardInfo(int code) => _dataService.getCardCached(code);

  /// 异步预加载卡片信息（缓存判断在 dataService.getCard 内部）
  Future<void> ensureCardInfo(int code) async {
    try {
      final info = await _dataService.getCard(code);
      // 缓存填充后触发一次刷新（copyWith 无参也产生新实例，保证通知）。
      if (info != null && !_disposed) state = state.copyWith();
    } catch (e) {
      console.log('Failed to load card info for $code: $e');
    }
  }

  String getCardImageUrl(int code) {
    return _dataService.getCardImageUrl(code);
  }

  void preloadCardInfos(Iterable<int> codes) {
    for (final code in codes) {
      if (code > 0) {
        unawaited(ensureCardInfo(code));
      }
    }
  }

  // ──────────────────────────────────────────
  // 战场消息应用
  // ──────────────────────────────────────────

  /// 处理抽卡消息，并同步手牌与卡组剩余数量。
  void applyDraw(MsgDraw msg) {
    final isMyDraw = msg.player == state.myController;
    if (isMyDraw) {
      state = state.copyWith(
        selfHand: [...state.selfHand, ...msg.cards],
        selfDeck: state.selfDeck - msg.count,
      );
    } else {
      state = state.copyWith(
        opponentHand: [...state.opponentHand, ...msg.cards],
        oppDeck: state.oppDeck - msg.count,
      );
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
      _applyUpdateAction(
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
    _applyUpdateAction(
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
    final fieldCards = <String, FieldCard>{};
    final selfGraveCodes = <int>[];
    final opponentGraveCodes = <int>[];
    final selfRemovedCodes = <int>[];
    final opponentRemovedCodes = <int>[];
    final selfExtraCodes = <int>[];
    final opponentExtraCodes = <int>[];
    var selfLp = state.selfLp;
    var opponentLp = state.opponentLp;
    var selfDeck = 0, selfExtra = 0, selfGrave = 0, selfRemoved = 0;
    var oppDeck = 0, oppExtra = 0, oppGrave = 0, oppRemoved = 0;
    var selfHand = const <int>[];
    var opponentHand = const <int>[];

    void seedPlaceholder(List<int> list, int sequence) {
      while (list.length <= sequence) {
        list.add(0);
      }
    }

    for (final playerState in msg.players) {
      final isSelf = playerState.player == state.myController;
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
              while (selfExtraCodes.length <= action.sequence) {
                final index = selfExtraCodes.length;
                selfExtraCodes.add(
                  index < state.knownSelfExtraDeckCodes.length
                      ? state.knownSelfExtraDeckCodes[index]
                      : 0,
                );
              }
            } else {
              seedPlaceholder(opponentExtraCodes, action.sequence);
            }
            break;
          case CARD_ZONE_GRAVE:
            grave++;
            seedPlaceholder(
              isSelf ? selfGraveCodes : opponentGraveCodes,
              action.sequence,
            );
            break;
          case CARD_ZONE_REMOVED:
            removed++;
            seedPlaceholder(
              isSelf ? selfRemovedCodes : opponentRemovedCodes,
              action.sequence,
            );
            break;
          case CARD_ZONE_HAND:
            hand++;
            break;
          default:
            if (state.isOnFieldLocation(action.zone)) {
              final normalizedZone = _normalizeFieldZone(action.zone);
              final normalizedSequence = _normalizeFieldSequence(
                action.zone,
                action.sequence,
              );
              fieldCards[state.fieldCardKey(
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
        selfHand = List<int>.filled(hand, 0);
      } else {
        oppDeck = deck;
        oppExtra = extra;
        oppGrave = grave;
        oppRemoved = removed;
        opponentHand = List<int>.filled(hand, 0);
      }
    }

    state = state.copyWith(
      fieldCards: fieldCards,
      selfHand: selfHand,
      opponentHand: opponentHand,
      selfGraveCodes: selfGraveCodes,
      opponentGraveCodes: opponentGraveCodes,
      selfRemovedCodes: selfRemovedCodes,
      opponentRemovedCodes: opponentRemovedCodes,
      selfExtraCodes: selfExtraCodes,
      opponentExtraCodes: opponentExtraCodes,
      selfLp: selfLp,
      opponentLp: opponentLp,
      selfDeck: selfDeck,
      selfExtra: selfExtra,
      selfGrave: selfGrave,
      selfRemoved: selfRemoved,
      oppDeck: oppDeck,
      oppExtra: oppExtra,
      oppGrave: oppGrave,
      oppRemoved: oppRemoved,
    );
  }

  /// 处理卡片移动消息，先移除旧位置，再写入新位置。
  void applyMove(MsgMove msg) {
    state = _removeCardFromLocation(
      state,
      msg.from.controller,
      msg.from.location,
      msg.from.sequence,
    );
    state = _addCardToLocation(
      state,
      msg.code,
      msg.to.controller,
      msg.to.location,
      msg.to.sequence,
      msg.to.position,
    );
    if (msg.code > 0) {
      unawaited(ensureCardInfo(msg.code));
    }
  }

  /// 同步禁用区域状态。
  void applyFieldDisabled(MsgFieldDisabled msg) {
    var cards = state.fieldCards;
    var changed = false;
    for (final action in msg.actions) {
      final key = state.fieldCardKey(
        action.controller,
        action.zone,
        action.sequence,
      );
      final current = cards[key];
      if (current == null) continue;
      if (!changed) {
        cards = {...cards};
        changed = true;
      }
      cards[key] = FieldCard(
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
    if (changed) {
      state = state.copyWith(fieldCards: cards);
    }
  }

  /// 更新战斗结算后场上怪兽的攻守信息。
  void applyBattle(MsgBattle msg) {
    final cards = {...state.fieldCards};
    _writeBattleCardStats(
      cards,
      msg.attacker,
      msg.attackerAttack,
      msg.attackerDefense,
    );
    if (msg.hasDefender) {
      _writeBattleCardStats(
        cards,
        msg.defender,
        msg.defenderAttack,
        msg.defenderDefense,
      );
    }
    state = state.copyWith(fieldCards: cards);
  }

  void _writeBattleCardStats(
    Map<String, FieldCard> cards,
    CardLocation location,
    int attack,
    int defense,
  ) {
    final key = state.fieldCardKey(
      location.controller,
      location.location,
      location.sequence,
    );
    final current = cards[key];
    if (current == null) return;
    cards[key] = FieldCard(
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

  /// 处理表示形式变化。
  void applyPosChange(MsgPosChange msg) {
    final key = state.fieldCardKey(
      msg.cardInfo.controller,
      msg.cardInfo.location,
      msg.cardInfo.sequence,
    );
    final card = state.fieldCards[key];
    if (card == null) return;
    state = state.copyWith(
      fieldCards: {
        ...state.fieldCards,
        key: FieldCard(
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
        ),
      },
    );
  }

  /// 处理洗手牌消息。
  void applyShuffleHand(MsgShuffleHand msg) {
    if (msg.player == state.myController) {
      state = state.copyWith(selfHand: [...msg.cards]);
    } else {
      state = state.copyWith(opponentHand: List.filled(msg.count, 0));
    }
  }

  /// 按消息内容把卡片更新写回到对应区域。
  void _applyUpdateAction({
    required int controller,
    required int zone,
    required int sequence,
    required int position,
    required int code,
    required MsgUpdateAction action,
  }) {
    if (zone & CARD_ZONE_HAND != 0) {
      final isSelf = controller == state.myController;
      final hand = [...(isSelf ? state.selfHand : state.opponentHand)];
      while (hand.length <= sequence) {
        hand.add(0);
      }
      if (code > 0) {
        hand[sequence] = code;
        if (isSelf) {
          unawaited(ensureCardInfo(code));
        }
      }
      state = isSelf
          ? state.copyWith(selfHand: hand)
          : state.copyWith(opponentHand: hand);
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

    if (state.isOnFieldLocation(zone)) {
      final normalizedZone = _normalizeFieldZone(zone);
      final normalizedSequence = _normalizeFieldSequence(zone, sequence);
      final key = state.fieldCardKey(controller, zone, sequence);
      final current = state.fieldCards[key];
      final effectiveCode = code > 0 ? code : (current?.code ?? 0);
      final overlayCount = action.overlayCards.isNotEmpty
          ? action.overlayCards.length
          : (current?.overlayCount ?? 0);
      state = state.copyWith(
        fieldCards: {
          ...state.fieldCards,
          key: FieldCard(
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
          ),
        },
      );
      if (effectiveCode > 0) {
        unawaited(ensureCardInfo(effectiveCode));
      }
    }
  }

  /// 根据区域序号推导该区域当前至少应有多少张卡。
  void _syncZoneCount(int controller, int zone, int sequence, {int? code}) {
    final nextCount = sequence + 1;
    final isSelf = controller == state.myController;
    if (zone & CARD_ZONE_DECK != 0) {
      state = isSelf
          ? state.copyWith(
              selfDeck: state.selfDeck < nextCount ? nextCount : state.selfDeck,
            )
          : state.copyWith(
              oppDeck: state.oppDeck < nextCount ? nextCount : state.oppDeck,
            );
      return;
    }
    if (zone & CARD_ZONE_EXTRA != 0) {
      final codes = _upsertZoneCode(
        isSelf ? state.selfExtraCodes : state.opponentExtraCodes,
        sequence,
        code,
      );
      state = isSelf
          ? state.copyWith(
              selfExtraCodes: codes,
              selfExtra:
                  state.selfExtra < nextCount ? nextCount : state.selfExtra,
            )
          : state.copyWith(
              opponentExtraCodes: codes,
              oppExtra: state.oppExtra < nextCount ? nextCount : state.oppExtra,
            );
      if (code != null && code > 0) {
        unawaited(ensureCardInfo(code));
      }
      return;
    }
    if (zone & CARD_ZONE_GRAVE != 0) {
      final codes = _upsertZoneCode(
        isSelf ? state.selfGraveCodes : state.opponentGraveCodes,
        sequence,
        code,
      );
      state = isSelf
          ? state.copyWith(
              selfGraveCodes: codes,
              selfGrave:
                  state.selfGrave < nextCount ? nextCount : state.selfGrave,
            )
          : state.copyWith(
              opponentGraveCodes: codes,
              oppGrave: state.oppGrave < nextCount ? nextCount : state.oppGrave,
            );
      if (code != null && code > 0) {
        unawaited(ensureCardInfo(code));
      }
      return;
    }
    if (zone & CARD_ZONE_REMOVED != 0) {
      final codes = _upsertZoneCode(
        isSelf ? state.selfRemovedCodes : state.opponentRemovedCodes,
        sequence,
        code,
      );
      state = isSelf
          ? state.copyWith(
              selfRemovedCodes: codes,
              selfRemoved:
                  state.selfRemoved < nextCount ? nextCount : state.selfRemoved,
            )
          : state.copyWith(
              opponentRemovedCodes: codes,
              oppRemoved:
                  state.oppRemoved < nextCount ? nextCount : state.oppRemoved,
            );
      if (code != null && code > 0) {
        unawaited(ensureCardInfo(code));
      }
    }
  }

  List<int> _upsertZoneCode(List<int> list, int sequence, int? code) {
    final next = [...list];
    while (next.length <= sequence) {
      next.add(0);
    }
    if (code != null && code > 0) {
      next[sequence] = code;
    }
    return next;
  }

  void setKnownSelfExtraDeckCodes(List<int> codes) {
    if (state.selfExtraCodes.isEmpty) {
      state = state.copyWith(
        knownSelfExtraDeckCodes: [...codes],
        selfExtraCodes: [...codes],
        selfExtra: codes.length,
      );
      return;
    }
    final next = [...state.selfExtraCodes];
    for (var i = 0; i < next.length && i < codes.length; i++) {
      if (next[i] <= 0) {
        next[i] = codes[i];
      }
    }
    state = state.copyWith(
      knownSelfExtraDeckCodes: [...codes],
      selfExtraCodes: next,
    );
  }

  DuelFieldState _withZoneCodeList(
    DuelFieldState s,
    int controller,
    int location,
    List<int> codes,
  ) {
    final isSelf = controller == s.myController;
    if (location & CARD_ZONE_EXTRA != 0) {
      return isSelf
          ? s.copyWith(selfExtraCodes: codes)
          : s.copyWith(opponentExtraCodes: codes);
    }
    if (location & CARD_ZONE_GRAVE != 0) {
      return isSelf
          ? s.copyWith(selfGraveCodes: codes)
          : s.copyWith(opponentGraveCodes: codes);
    }
    return isSelf
        ? s.copyWith(selfRemovedCodes: codes)
        : s.copyWith(opponentRemovedCodes: codes);
  }

  /// 从指定区域移除一张卡，并维护关联计数。
  DuelFieldState _removeCardFromLocation(
    DuelFieldState s,
    int controller,
    int location,
    int sequence,
  ) {
    final isSelf = controller == s.myController;
    if (location & CARD_ZONE_HAND != 0) {
      final hand = isSelf ? s.selfHand : s.opponentHand;
      if (sequence >= hand.length) return s;
      final next = [...hand]..removeAt(sequence);
      return isSelf
          ? s.copyWith(selfHand: next)
          : s.copyWith(opponentHand: next);
    }
    if (s.isOnFieldLocation(location)) {
      final cards = {...s.fieldCards}
        ..remove(s.fieldCardKey(controller, location, sequence));
      return s.copyWith(fieldCards: cards);
    }
    if (location & CARD_ZONE_GRAVE != 0) {
      final list = s.zoneCodeListFor(controller, location);
      List<int>? next;
      if (list != null && sequence < list.length) {
        next = [...list]..removeAt(sequence);
      }
      return isSelf
          ? s.copyWith(
              selfGraveCodes: next ?? s.selfGraveCodes,
              selfGrave: s.selfGrave > 0 ? s.selfGrave - 1 : 0,
            )
          : s.copyWith(
              opponentGraveCodes: next ?? s.opponentGraveCodes,
              oppGrave: s.oppGrave > 0 ? s.oppGrave - 1 : 0,
            );
    }
    if (location & CARD_ZONE_REMOVED != 0) {
      final list = s.zoneCodeListFor(controller, location);
      List<int>? next;
      if (list != null && sequence < list.length) {
        next = [...list]..removeAt(sequence);
      }
      return isSelf
          ? s.copyWith(
              selfRemovedCodes: next ?? s.selfRemovedCodes,
              selfRemoved: s.selfRemoved > 0 ? s.selfRemoved - 1 : 0,
            )
          : s.copyWith(
              opponentRemovedCodes: next ?? s.opponentRemovedCodes,
              oppRemoved: s.oppRemoved > 0 ? s.oppRemoved - 1 : 0,
            );
    }
    if (location & CARD_ZONE_DECK != 0) {
      return isSelf
          ? s.copyWith(selfDeck: s.selfDeck - 1)
          : s.copyWith(oppDeck: s.oppDeck - 1);
    }
    if (location & CARD_ZONE_EXTRA != 0) {
      final list = s.zoneCodeListFor(controller, location);
      List<int>? next;
      if (list != null && sequence < list.length) {
        next = [...list]..removeAt(sequence);
      }
      return isSelf
          ? s.copyWith(
              selfExtraCodes: next ?? s.selfExtraCodes,
              selfExtra: s.selfExtra > 0 ? s.selfExtra - 1 : 0,
            )
          : s.copyWith(
              opponentExtraCodes: next ?? s.opponentExtraCodes,
              oppExtra: s.oppExtra > 0 ? s.oppExtra - 1 : 0,
            );
    }
    return s;
  }

  /// 向指定区域写入一张卡，并维护关联计数。
  DuelFieldState _addCardToLocation(
    DuelFieldState s,
    int code,
    int controller,
    int location,
    int sequence,
    int position,
  ) {
    final isSelf = controller == s.myController;
    if (location & CARD_ZONE_HAND != 0) {
      return isSelf
          ? s.copyWith(selfHand: [...s.selfHand, code])
          : s.copyWith(opponentHand: [...s.opponentHand, code]);
    }
    if (s.isOnFieldLocation(location)) {
      final normalizedZone = _normalizeFieldZone(location);
      final normalizedSequence = _normalizeFieldSequence(location, sequence);
      return s.copyWith(
        fieldCards: {
          ...s.fieldCards,
          s.fieldCardKey(controller, location, sequence): FieldCard(
            code: code,
            controller: controller,
            zone: normalizedZone,
            sequence: normalizedSequence,
            position: position,
            disabled: false,
          ),
        },
      );
    }
    if (location & CARD_ZONE_GRAVE != 0 ||
        location & CARD_ZONE_REMOVED != 0 ||
        location & CARD_ZONE_EXTRA != 0) {
      final list = s.zoneCodeListFor(controller, location);
      List<int>? next;
      if (list != null) {
        next = [...list];
        while (next.length < sequence) {
          next.add(0);
        }
        if (sequence <= next.length) {
          next.insert(sequence, code);
        }
      }
      if (location & CARD_ZONE_GRAVE != 0) {
        return isSelf
            ? s.copyWith(
                selfGraveCodes: next ?? s.selfGraveCodes,
                selfGrave: s.selfGrave + 1,
              )
            : s.copyWith(
                opponentGraveCodes: next ?? s.opponentGraveCodes,
                oppGrave: s.oppGrave + 1,
              );
      }
      if (location & CARD_ZONE_REMOVED != 0) {
        return isSelf
            ? s.copyWith(
                selfRemovedCodes: next ?? s.selfRemovedCodes,
                selfRemoved: s.selfRemoved + 1,
              )
            : s.copyWith(
                opponentRemovedCodes: next ?? s.opponentRemovedCodes,
                oppRemoved: s.oppRemoved + 1,
              );
      }
      return isSelf
          ? s.copyWith(
              selfExtraCodes: next ?? s.selfExtraCodes,
              selfExtra: s.selfExtra + 1,
            )
          : s.copyWith(
              opponentExtraCodes: next ?? s.opponentExtraCodes,
              oppExtra: s.oppExtra + 1,
            );
    }
    if (location & CARD_ZONE_DECK != 0) {
      return isSelf
          ? s.copyWith(selfDeck: s.selfDeck + 1)
          : s.copyWith(oppDeck: s.oppDeck + 1);
    }
    return s;
  }

  String? handleChaining(dynamic data) {
    final msg = data as MsgChaining;
    state = state.copyWith(
      chains: [
        ...state.chains,
        ChainLink(
          code: msg.code,
          controller: msg.location.controller,
          zone: msg.location.location,
          sequence: msg.location.sequence,
        ),
      ],
    );
    final name = getCardInfo(msg.code)?.name ?? '卡片';
    return name;
  }

  String? handleSummoning(dynamic data) {
    final msg = data as MsgSummoning;
    state = state.copyWith(
      lastSummonKey: zoneKeyOf(
        msg.location.controller,
        msg.location.location,
        msg.location.sequence,
      ),
    );
    unawaited(ensureCardInfo(msg.code));
    final name = getCardInfo(msg.code)?.name ?? '怪兽';
    return name;
  }

  FieldCard? handlePosChange(dynamic data) {
    final msg = data as MsgPosChange;
    applyPosChange(msg);
    final key = state.fieldCardKey(
      msg.cardInfo.controller,
      msg.cardInfo.location,
      msg.cardInfo.sequence,
    );
    return state.fieldCards[key];
  }

  void setChainSealed(bool sealed) {
    state = state.copyWith(chainSealed: sealed);
  }

  // ──────────────────────────────────────────
  // 战报与玩家
  // ──────────────────────────────────────────

  /// 记录对局日志并触发刷新。
  void addLog(String log) {
    state = state.copyWith(duelLogs: [...state.duelLogs, log]);
  }

  /// 同步房间玩家列表，供日志文案解析玩家名。
  void syncPlayers(List<PlayerInfo> players) {
    state = state.copyWith(players: players);
  }

  // ──────────────────────────────────────────
  // 服务器消息处理（战场部分）
  // ──────────────────────────────────────────

  void handleStart(dynamic data) {
    final msg = data as MsgStart;
    // MSG_START 首字节是服务端按客户端单独下发的引擎玩家编号
    // （0x00 = 引擎 0 号玩家，0x01 = 引擎 1 号玩家），不是房间座位号。
    final isPlayer0 = msg.isPlayer0;
    state = state.copyWith(
      myController: isPlayer0 ? 0 : 1,
      selfLp: isPlayer0 ? msg.life1 : msg.life2,
      opponentLp: isPlayer0 ? msg.life2 : msg.life1,
      selfDeck: isPlayer0 ? msg.deckSize1 : msg.deckSize2,
      selfExtra: isPlayer0 ? msg.extraSize1 : msg.extraSize2,
      oppDeck: isPlayer0 ? msg.deckSize2 : msg.deckSize1,
      oppExtra: isPlayer0 ? msg.extraSize2 : msg.extraSize1,
      selfHand: const [],
      opponentHand: const [],
      fieldCards: const {},
      turnCount: 1,
    );
    addLog('决斗开始。');
  }

  void handleNewTurn(dynamic data) {
    final msg = data as MsgNewTurn;
    state = state.copyWith(
      currentPlayer: msg.player,
      turnCount: state.turnCount + 1,
    );
    addLog('${state.playerNameOf(msg.player)} 的回合。');
  }

  void handleWaiting(MsgWait msg) {
    addLog('等待对手操作。');
  }

  void handleAttack(dynamic data) {
    final msg = data as MsgAttack;
    final from = zoneKeyOf(
      msg.attacker.controller,
      msg.attacker.location,
      msg.attacker.sequence,
    );
    final to = msg.target != null
        ? zoneKeyOf(
            msg.target!.controller,
            msg.target!.location,
            msg.target!.sequence,
          )
        : null;
    final attackerName = state.fieldCards[from]?.name ?? '怪兽';
    _battlePresentationTimer?.cancel();
    state = state.copyWith(
      lastAttackFrom: from,
      lastAttackTo: to,
      battlePresentation: BattlePresentation(
        attackerSlotId: from,
        defenderSlotId: to,
        attackerName: attackerName,
        defenderName: to == null
            ? null
            : state.fieldCards[to]?.name ?? '怪兽',
      ),
    );
    if (to != null) {
      final targetName = state.fieldCards[to]?.name ?? '怪兽';
      addLog('$attackerName 攻击 $targetName。');
    } else {
      addLog('$attackerName 发动直接攻击。');
    }
  }

  void handleDamage(dynamic data) {
    final msg = data as MsgDamage;
    _applyLpChange(msg.player, -msg.value);
    addLog('${state.playerNameOf(msg.player)} 受到 ${msg.value} 点伤害。');
  }

  void handleRecover(dynamic data) {
    final msg = data as MsgRecover;
    _applyLpChange(msg.player, msg.value);
    addLog('${state.playerNameOf(msg.player)} 回复了 ${msg.value} 点生命值。');
  }

  void handleLpUpdate(dynamic data) {
    final msg = data as MsgLpUpdate;
    final oldLp = msg.player == state.myController
        ? state.selfLp
        : state.opponentLp;
    final delta = msg.newLp - oldLp;
    if (msg.player == state.myController) {
      state = state.copyWith(
        selfLp: msg.newLp,
        selfLpDelta: delta,
        selfLpEventId: state.selfLpEventId + 1,
      );
    } else {
      state = state.copyWith(
        opponentLp: msg.newLp,
        opponentLpDelta: delta,
        opponentLpEventId: state.opponentLpEventId + 1,
      );
    }
    console.log(
      'MSG_LP_UPDATE: player=${msg.player} old=$oldLp new=${msg.newLp} delta=$delta',
    );
  }

  void handlePayLife(dynamic data) {
    final msg = data as MsgPayLpCost;
    _applyLpChange(msg.player, -msg.value);
    addLog('${state.playerNameOf(msg.player)} 支付了 ${msg.value} 点生命值。');
  }

  void syncConfirmedCard(CardInfo card) {
    final code = card.code;
    if (code <= 0) {
      return;
    }

    final controller = card.controller;
    final location = card.location;
    final sequence = card.sequence;
    final isSelf = controller == state.myController;

    if (location & CARD_ZONE_HAND != 0) {
      final hand = [...(isSelf ? state.selfHand : state.opponentHand)];
      while (hand.length <= sequence) {
        hand.add(0);
      }
      hand[sequence] = code;
      state = isSelf
          ? state.copyWith(selfHand: hand)
          : state.copyWith(opponentHand: hand);
      return;
    }

    if (location & CARD_ZONE_GRAVE != 0 ||
        location & CARD_ZONE_REMOVED != 0 ||
        location & CARD_ZONE_EXTRA != 0) {
      final list = state.zoneCodeListFor(controller, location);
      if (list != null) {
        final next = _upsertZoneCode(list, sequence, code);
        state = _withZoneCodeList(state, controller, location, next);
      }
      return;
    }

    if (state.isOnFieldLocation(location)) {
      final key = state.fieldCardKey(controller, location, sequence);
      final current = state.fieldCards[key];
      state = state.copyWith(
        fieldCards: {
          ...state.fieldCards,
          key: FieldCard(
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
          ),
        },
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
    state = state.copyWith(
      lastSummonKey: zoneKeyOf(
        location.controller,
        location.location,
        location.sequence,
      ),
    );
    if (code > 0) {
      unawaited(ensureCardInfo(code));
    }
    final name = getCardInfo(code)?.name ?? '怪兽';
    addLog('正在$actionLabel $name。');
  }

  void handleSummonFinished(String actionLabel) {
    final key = state.lastSummonKey;
    final name = key != null ? state.fieldCards[key]?.name ?? '怪兽' : '怪兽';
    state = state.copyWith(lastSummonKey: null);
    addLog('$name $actionLabel成功。');
  }

  void handleHint(MsgHint msg) {
    final code = cardCodeFromDescriptionValue(msg.hintData);
    if (code != null && code >= 1000000) {
      unawaited(ensureCardInfo(code));
    }
  }

  void handleWin(MsgWin msg) {
    final didWin = msg.winPlayer == state.myController;
    state = state.copyWith(
      duelResult: DuelResultSummary(
        didWin: didWin,
        winPlayer: msg.winPlayer,
        reason: msg.reason,
        selfName: state.playerNameOf(state.myController),
        opponentName: state.playerNameOf(1 - state.myController),
        selfLp: state.selfLp,
        opponentLp: state.opponentLp,
      ),
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
    final attackerSlotId = zoneKeyOf(
      msg.attacker.controller,
      msg.attacker.location,
      msg.attacker.sequence,
    );
    final defenderSlotId = msg.hasDefender
        ? zoneKeyOf(
            msg.defender.controller,
            msg.defender.location,
            msg.defender.sequence,
          )
        : null;
    final base = state.battlePresentation ??
        BattlePresentation(
          attackerSlotId: attackerSlotId,
          defenderSlotId: defenderSlotId,
          attackerName: state.fieldCards[attackerSlotId]?.name ?? '怪兽',
          defenderName: defenderSlotId == null
              ? null
              : state.fieldCards[defenderSlotId]?.name ?? '怪兽',
        );
    final presentation = base.copyWith(
      attackerSlotId: attackerSlotId,
      defenderSlotId: defenderSlotId,
      attackerName: state.fieldCards[attackerSlotId]?.name ?? '怪兽',
      defenderName: defenderSlotId == null
          ? null
          : state.fieldCards[defenderSlotId]?.name ?? '怪兽',
      attackerAttack: msg.attackerAttack,
      attackerDefense: msg.attackerDefense,
      attackerPosition: msg.attackerPosition,
      defenderAttack: msg.hasDefender ? msg.defenderAttack : null,
      defenderDefense: msg.hasDefender ? msg.defenderDefense : null,
      defenderPosition: msg.hasDefender ? msg.defenderPosition : null,
    );
    state = state.copyWith(battlePresentation: presentation);
    if (msg.hasDefender) {
      addLog(
        '${presentation.attackerName} ${_battleValueLabel(msg.attackerAttack, msg.attackerDefense, msg.attackerPosition)} '
        'VS '
        '${presentation.defenderName} ${_battleValueLabel(msg.defenderAttack, msg.defenderDefense, msg.defenderPosition)}。',
      );
    } else {
      addLog('${presentation.attackerName} 进行直接攻击结算。');
    }
  }

  void handleChainEnd(dynamic data) {
    state = state.copyWith(chains: const []);
  }

  void handleShuffleDeck(dynamic data) {
    final msg = data as MsgShuffleDeck;
    addLog('${state.playerNameOf(msg.player)} 洗切了卡组。');
    state = state.copyWith(
      deckShufflePlayer: msg.player,
      deckShuffleTick: state.deckShuffleTick + 1,
    );
  }

  void handleDamageStepStart() {
    _battlePresentationTimer?.cancel();
    state = state.copyWith(inDamageStep: true);
    addLog('进入伤害步骤。');
  }

  void handleDamageStepEnd() {
    state = state.copyWith(inDamageStep: false);
    addLog('伤害步骤结束。');
    scheduleBattlePresentationClear();
  }

  void handleAttackDisabled() {
    state = state.copyWith(inDamageStep: false);
    addLog('此次攻击无效。');
    scheduleBattlePresentationClear(delay: const Duration(milliseconds: 600));
  }

  void handleBecomeTarget(MsgBecomeTarget msg) {
    addLog('${msg.count} 张卡成为效果对象。');
  }

  void handleTimeLimit(StocTimeLimit msg) {
    final player = msg.player;
    final left = msg.leftTime;
    state = player == state.myController
        ? state.copyWith(selfTimeLeft: left)
        : state.copyWith(opponentTimeLeft: left);
    _timeLimitTimer?.cancel();
    if (left > 0) {
      _timeLimitTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          var selfLeft = state.selfTimeLeft;
          var oppLeft = state.opponentTimeLeft;
          if (player == state.myController) {
            if (selfLeft > 0) selfLeft--;
          } else {
            if (oppLeft > 0) oppLeft--;
          }
          state = state.copyWith(
            selfTimeLeft: selfLeft,
            opponentTimeLeft: oppLeft,
          );
          if (selfLeft <= 0 && oppLeft <= 0) {
            _timeLimitTimer?.cancel();
          }
        },
      );
    }
  }

  void _applyLpChange(int player, int delta) {
    if (player == state.myController) {
      state = state.copyWith(
        selfLp: state.selfLp + delta,
        selfLpDelta: delta,
        selfLpEventId: state.selfLpEventId + 1,
      );
      return;
    }
    state = state.copyWith(
      opponentLp: state.opponentLp + delta,
      opponentLpDelta: delta,
      opponentLpEventId: state.opponentLpEventId + 1,
    );
  }

  void scheduleBattlePresentationClear({
    Duration delay = const Duration(milliseconds: 900),
  }) {
    _battlePresentationTimer?.cancel();
    _battlePresentationTimer = Timer(delay, () {
      state = state.copyWith(
        battlePresentation: null,
        lastAttackFrom: null,
        lastAttackTo: null,
      );
    });
  }

  String _battleValueLabel(int attack, int defense, int? position) {
    final isDefense = position != null && (position & 0x0c) != 0;
    return isDefense ? 'DEF $defense' : 'ATK $attack';
  }

  /// onDuelPhaseMessage 流驱动：更新阶段并按需记战报。
  ///
  /// 阶段合法性（enableBp/enableM2/enableEp）只由服务端下发的
  /// MSG_SELECT_IDLE_CMD / MSG_SELECT_BATTLE_CMD 驱动，这里不做本地推断。
  void setPhaseFromStream(DuelPhase phase, String? phaseName) {
    state = state.copyWith(phase: phase);
    if (phaseName?.isNotEmpty == true) addLog('$phaseName 开始。');
  }
}

/// 对局事实状态（战场）的 provider，按房间 ProviderScope override 隔离。
final duelFieldProvider =
    NotifierProvider<DuelFieldNotifier, DuelFieldState>(DuelFieldNotifier.new);
