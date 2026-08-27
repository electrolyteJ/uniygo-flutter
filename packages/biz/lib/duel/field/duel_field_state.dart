import 'dart:async';
import 'dart:developer' as console;

import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ygo_data/card_info.dart' as pkg;

import '../models/battle_presentation.dart';
import '../models/chain_link.dart';
import '../models/draw_animation_event.dart';
import '../models/field_card.dart';
import '../models/summon_effect_event.dart';
import '../models/field_zone_key.dart';
// 注：与本文件存在双向 import（duel_room_state 也引用 duelFieldProvider）；
// Dart 允许 import 环，且两侧都只在运行期惰性读取对方的 provider。
import '../room/duel_room_state.dart' show duelRoomProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'duel_field_state.g.dart';

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

// ──────────────────────────────────────────
// Tag（双打）模式的座位 ↔ 引擎玩家映射
// ──────────────────────────────────────────

/// Tag 模式下座位所属队伍（ocgcore 约定：座位 0,2 = 队伍 0；座位 1,3 = 队伍 1）。
///
/// Tag 对局里引擎只有两个「玩家」（即两支队伍），服务器消息里的 player
/// 字段是队伍编号 0/1，与 4 个决斗座位号不一一对应，展示前需经此映射。
/// 1v1 下座位号只有 0/1，`pos % 2 == pos`，映射天然退化为恒等。
int teamOfSeat(int pos) => pos % 2;

/// [team] 队伍在 [players] 中的全部决斗座位（按座位号升序）。
///
/// 只统计决斗座位（pos 0..3）：观战位（pos==7）不参与队伍映射。
List<PlayerInfo> seatsOfTeam(int team, List<PlayerInfo> players) {
  final seats = players
      .where((p) => p.pos >= 0 && p.pos <= 3 && teamOfSeat(p.pos) == team)
      .toList(growable: false);
  seats.sort((a, b) => a.pos.compareTo(b.pos));
  return seats;
}

/// 一侧玩家名展示：tag 模式把同队队友名字用 " / " 连接（如 "A / B"），
/// 1v1 每队恰有一个座位，输出与旧的 `pos` 精确匹配逻辑一致。
/// 该侧没有任何座位时返回 [fallback]。
String teamDisplayName(
  int team,
  List<PlayerInfo> players, {
  required String fallback,
}) {
  final names = seatsOfTeam(team, players).map((p) => p.name);
  if (names.isEmpty) return fallback;
  return names.join(' / ');
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
    this.startLp = 8000,
    this.currentPlayer = 0,
    this.phase = DuelPhase.idle,
    this.turnCount = 0,
    this.selfTimeLeft = 0,
    this.opponentTimeLeft = 0,
    this.myController = 0,
    this.mySeat = -1,
    this.chains = const [],
    this.chainSealed = false,
    this.lastSummonKey,
    this.lastAttackFrom,
    this.lastAttackTo,
    this.attackEventId = 0,
    this.battlePresentation,
    this.inDamageStep = false,
    this.selfLpDelta = 0,
    this.opponentLpDelta = 0,
    this.selfLpEventId = 0,
    this.opponentLpEventId = 0,
    this.deckShuffleTick = 0,
    this.deckShufflePlayer = 0,
    this.extraShuffleTick = 0,
    this.extraShufflePlayer = 0,
    this.selfDeckShuffleTick = 0,
    this.oppDeckShuffleTick = 0,
    this.selfExtraShuffleTick = 0,
    this.oppExtraShuffleTick = 0,
    this.handShuffleTick = 0,
    this.handShufflePlayer = 0,
    this.drawAnimationEvent,
    this.drawAnimationTick = 0,
    this.summonEffectEvent,
    this.summonEffectTick = 0,
    this.duelLogs = const [],
    this.players = const [],
    this.roomMode,
    this.duelResult,
    this.cardInfoVersion = 0,
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

  /// 本局初始 LP（MSG_START 的 life1/life2；match/tag 为 16000）。
  /// LP 条按 lp/startLp 比例分档，不再硬编码 8000。默认 8000 兜底。
  final int startLp;
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

  /// 我方房间座位号（0-3），由 [DuelFieldNotifier] 从房间状态
  /// （STOC_TYPE_CHANGE → DuelRoomState.selfType）同步；-1 = 未知
  /// （观战位/尚未同步）。
  ///
  /// 与 [myController] 组成「引擎编号 ↔ 座位」锚点：服务端在猜拳后按
  /// 胜者的先/后攻选择交换 players[]（single_duel.cpp TPResult），
  /// 交换后引擎编号 ≠ 座位号。名字解析经 [teamOfEnginePlayer] 走锚点
  /// 映射，避免玩家名与 LP/场面错位（观感即"双方生命值对调"）。
  final int mySeat;

  final List<ChainLink> chains;

  /// 连锁组建阶段已结束，不再有新的连锁入链（MSG_CHAIN_SOLVING 之后）。
  final bool chainSealed;
  final String? lastSummonKey;
  final String? lastAttackFrom;
  final String? lastAttackTo;

  /// 攻击宣言事件序号：每次 MSG_ATTACK 单调递增（与 lpEventId 同构）。
  /// 表现层按它做 diff——lastAttackFrom/To 的字符串 diff 会吞掉
  /// 「同攻击方+同目标」的连续攻击（900ms 清理窗口期内第二次无 diff）。
  final int attackEventId;
  final BattlePresentation? battlePresentation;
  final bool inDamageStep;
  final int selfLpDelta;
  final int opponentLpDelta;
  final int selfLpEventId;
  final int opponentLpEventId;

  /// 卡组洗切信号：每次 MSG_SHUFFLE_DECK 自增，驱动场地洗牌动效。
  final int deckShuffleTick;
  final int deckShufflePlayer;

  /// 额外卡组洗切信号：每次 MSG_SHUFFLE_EXTRA 自增。
  final int extraShuffleTick;
  final int extraShufflePlayer;

  /// 按侧拆分的卡组洗切 tick（每侧单调递增）。
  ///
  /// 全局 [deckShuffleTick] + [deckShufflePlayer] 只能表达"最后一次洗牌"，
  /// 双方洗牌消息同帧到达时先洗牌一方会被表现层（每帧采样）吞掉；
  /// 每侧独立 tick 保证双方各自的洗牌动效都能触发。
  final int selfDeckShuffleTick;
  final int oppDeckShuffleTick;

  /// 按侧拆分的额外卡组洗切 tick，语义同 [selfDeckShuffleTick]。
  final int selfExtraShuffleTick;
  final int oppExtraShuffleTick;

  /// 手牌洗切信号：每次 MSG_SHUFFLE_HAND 自增。
  final int handShuffleTick;
  final int handShufflePlayer;

  /// 最近一次抽卡动画事件；页面监听该字段变化播放抽卡飞行动画
  /// （播放中到达的新事件由页面侧 FIFO 队列排队，见 DrawAnimationQueue）。
  /// [DuelFieldNotifier.handleStart] 在新对局开始时将其清为 null，
  /// 页面以此作为清空本地动画队列的信号。
  final DrawAnimationEvent? drawAnimationEvent;
  final int drawAnimationTick;

  /// 最近一次召唤特效事件；表现层监听 tick 变化播放几何召唤阵演出
  /// （连续召唤由表现层 FIFO 排队，语义同 [drawAnimationEvent]）。
  final SummonEffectEvent? summonEffectEvent;
  final int summonEffectTick;

  /// 对局日志（战报），供日志抽屉展示。
  final List<String> duelLogs;

  /// 卡信息缓存版本号：ensureCardInfo 批量入库完成后 +1。
  /// 卡名/卡图缓存不在本状态内（属 dataService 缓存），该版本号是
  /// "缓存有更新"的订阅信号，供细粒度 Consumer（检视器/确认面板等）
  /// watch，替代原先整页 watch 传导的卡名刷新。
  final int cardInfoVersion;

  /// 玩家名解析所需的房间玩家列表，由页面在房间阶段变化时同步。
  final List<PlayerInfo> players;

  /// 房间对战模式，由 [DuelFieldNotifier] 从房间状态只读同步。
  /// null 表示房间信息尚未同步（此时 tag 判定退回「4 决斗座位」启发式，
  /// 见 [isTagMode]）。tag 模式影响座位↔引擎玩家映射，见 [teamOfSeat]。
  final RoomMode? roomMode;

  final Map<String, Object?>? duelResult;

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
    int? startLp,
    int? currentPlayer,
    DuelPhase? phase,
    int? turnCount,
    int? selfTimeLeft,
    int? opponentTimeLeft,
    int? myController,
    int? mySeat,
    List<ChainLink>? chains,
    bool? chainSealed,
    Object? lastSummonKey = _undefined,
    Object? lastAttackFrom = _undefined,
    Object? lastAttackTo = _undefined,
    int? attackEventId,
    Object? battlePresentation = _undefined,
    bool? inDamageStep,
    int? selfLpDelta,
    int? opponentLpDelta,
    int? selfLpEventId,
    int? opponentLpEventId,
    int? deckShuffleTick,
    int? deckShufflePlayer,
    int? extraShuffleTick,
    int? extraShufflePlayer,
    int? selfDeckShuffleTick,
    int? oppDeckShuffleTick,
    int? selfExtraShuffleTick,
    int? oppExtraShuffleTick,
    int? handShuffleTick,
    int? handShufflePlayer,
    Object? drawAnimationEvent = _undefined,
    int? drawAnimationTick,
    Object? summonEffectEvent = _undefined,
    int? summonEffectTick,
    List<String>? duelLogs,
    int? cardInfoVersion,
    List<PlayerInfo>? players,
    RoomMode? roomMode,
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
      startLp: startLp ?? this.startLp,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      phase: phase ?? this.phase,
      turnCount: turnCount ?? this.turnCount,
      selfTimeLeft: selfTimeLeft ?? this.selfTimeLeft,
      opponentTimeLeft: opponentTimeLeft ?? this.opponentTimeLeft,
      myController: myController ?? this.myController,
      mySeat: mySeat ?? this.mySeat,
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
      attackEventId: attackEventId ?? this.attackEventId,
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
      extraShuffleTick: extraShuffleTick ?? this.extraShuffleTick,
      extraShufflePlayer: extraShufflePlayer ?? this.extraShufflePlayer,
      selfDeckShuffleTick: selfDeckShuffleTick ?? this.selfDeckShuffleTick,
      oppDeckShuffleTick: oppDeckShuffleTick ?? this.oppDeckShuffleTick,
      selfExtraShuffleTick: selfExtraShuffleTick ?? this.selfExtraShuffleTick,
      oppExtraShuffleTick: oppExtraShuffleTick ?? this.oppExtraShuffleTick,
      handShuffleTick: handShuffleTick ?? this.handShuffleTick,
      handShufflePlayer: handShufflePlayer ?? this.handShufflePlayer,
      drawAnimationEvent: identical(drawAnimationEvent, _undefined)
          ? this.drawAnimationEvent
          : drawAnimationEvent as DrawAnimationEvent?,
      drawAnimationTick: drawAnimationTick ?? this.drawAnimationTick,
      summonEffectEvent: identical(summonEffectEvent, _undefined)
          ? this.summonEffectEvent
          : summonEffectEvent as SummonEffectEvent?,
      summonEffectTick: summonEffectTick ?? this.summonEffectTick,
      duelLogs: duelLogs ?? this.duelLogs,
      cardInfoVersion: cardInfoVersion ?? this.cardInfoVersion,
      players: players ?? this.players,
      roomMode: roomMode ?? this.roomMode,
      duelResult: identical(duelResult, _undefined)
          ? this.duelResult
          : duelResult as Map<String, Object?>?,
    );
  }

  // ──────────────────────────────────────────
  // 纯派生读取（不依赖外部服务，留在 state 上）
  // ──────────────────────────────────────────

  /// 主卡组洗切后的状态迁移：全局 tick/player 与按侧 tick 一起更新。
  DuelFieldState withDeckShuffle(int player) {
    final isSelf = player == myController;
    return copyWith(
      deckShufflePlayer: player,
      deckShuffleTick: deckShuffleTick + 1,
      selfDeckShuffleTick: isSelf
          ? selfDeckShuffleTick + 1
          : selfDeckShuffleTick,
      oppDeckShuffleTick: isSelf ? oppDeckShuffleTick : oppDeckShuffleTick + 1,
    );
  }

  /// 额外卡组洗切后的状态迁移，语义同 [withDeckShuffle]。
  DuelFieldState withExtraShuffle(int player) {
    final isSelf = player == myController;
    return copyWith(
      extraShufflePlayer: player,
      extraShuffleTick: extraShuffleTick + 1,
      selfExtraShuffleTick: isSelf
          ? selfExtraShuffleTick + 1
          : selfExtraShuffleTick,
      oppExtraShuffleTick: isSelf
          ? oppExtraShuffleTick
          : oppExtraShuffleTick + 1,
    );
  }

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

  /// 返回公共区域最上面一张可展示卡的卡密，未知/空区域返回 0。
  int topZoneCode(String zoneKey) {
    final codes = getZoneCodes(zoneKey);
    for (var sequence = codes.length - 1; sequence >= 0; sequence--) {
      final code = codes[sequence];
      if (code > 0) return code;
    }
    return 0;
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

  /// 是否 tag（双打）模式。
  ///
  /// 优先取房间选项 [roomMode]；房间信息尚未同步（null）时退回
  /// 「存在 4 个决斗座位」启发式：1v1 只有座位 0/1，tag 为 0..3。
  /// 该启发式只在房间信息缺失时兜底，正常流程 roomMode 会在进房后即同步。
  bool get isTagMode {
    final mode = roomMode;
    if (mode != null) return mode == RoomMode.tag;
    return players.where((p) => p.pos >= 0 && p.pos <= 3).length >= 4;
  }

  /// 引擎玩家编号 → 展示侧队伍/座位号，以「我方引擎编号 [myController]
  /// ↔ 我方座位 [mySeat]」为锚点。
  ///
  /// 服务端在猜拳后会按胜者的先/后攻选择交换 players[]（single_duel.cpp
  /// TPResult：(tp && type==1) || (!tp && type==0) 时 swap），交换后
  /// 引擎编号 ≠ 房间座位号——四种猜拳结果里有两种会触发。旧的
  /// 「座位号 == 引擎编号」假设此时会把玩家名与 LP/场面错位，
  /// 观感即"我方生命值和对方生命值对调"。锚点事实（我坐在 [mySeat]、
  /// 我的引擎编号是 [myController]）恒真，对方侧由此推出。
  /// [mySeat] 未知（观战位/尚未同步）时退回旧假设（引擎编号 == 座位号）。
  int teamOfEnginePlayer(int player) {
    if (mySeat < 0 || mySeat > 3) return player;
    if (!isTagMode) {
      // 1v1 座位只会是 0/1；异常值退回旧假设兜底。
      if (mySeat > 1) return player;
      return player == myController ? mySeat : 1 - mySeat;
    }
    final myTeam = teamOfSeat(mySeat);
    return player == myController ? myTeam : 1 - myTeam;
  }

  /// 把引擎玩家编号解析为展示用玩家名。
  ///
  /// 先经 [teamOfEnginePlayer] 做「引擎编号 → 座位/队伍」锚点映射
  /// （抵御服务端 TPResult 交换 players[] 造成的编号≠座位），
  /// 再按座位列表解析名字。
  /// tag 模式：引擎只有两个「玩家」（两支队伍），无法与 4 个座位
  /// 一一对应，尝试用回合数推导当前行动的队友：ocgcore 中回合 1..4
  /// 依次对应座位轮转，handleStart 把 turnCount 置 1 且每条
  /// MSG_NEW_TURN（含第 1 回合）自增一次，故第 T 回合时
  /// turnCount == T+1，当前座位 = (turnCount - 2) % 4。
  String playerNameOf(int player) {
    final team = teamOfEnginePlayer(player);
    final seats = seatsOfTeam(team, players);
    if (seats.isEmpty) return '玩家$player';
    if (seats.length == 1) return seats.first.name;
    // 推导当前行动座位；turnCount 尚未走过首个 MSG_NEW_TURN 时无法推导。
    if (turnCount >= 2) {
      final expectedSeat = (turnCount - 2) % 4;
      if (teamOfSeat(expectedSeat) == team) {
        for (final seat in seats) {
          if (seat.pos == expectedSeat) return seat.name;
        }
      }
    }
    // 局限：对局中重连/中途观战/跳回合等使 turnCount 与实际座位轮转脱节时，
    // 无法确定当前行动的队友，退回队伍首个座位。
    return seats.first.name;
  }
}

/// 对局事实（战场）的 Notifier：持有全部 MSG_* 战场消息应用逻辑。
///
/// keepAlive: true 保持手写 NotifierProvider 语义；按房间 ProviderScope
/// override 隔离。
@Riverpod(keepAlive: true)
class DuelFieldNotifier extends _$DuelFieldNotifier {
  late YgoDataService _dataService;
  Timer? _timeLimitTimer;
  Timer? _battlePresentationTimer;
  bool _disposed = false;

  @override
  DuelFieldState build() {
    _dataService = ref.watch(dataServiceProvider);
    // 同步房间对战模式（tag 判定影响座位↔引擎玩家映射，见 playerNameOf）。
    // 用 read 取初值 + listen 跟变化，而不用 watch：watch 会在房间状态
    // 任意变更时重建本 notifier，把整个战场状态清空。
    final roomMode = ref.read(
      duelRoomProvider.select((s) => s.roomOptions?.mode),
    );
    ref.listen(duelRoomProvider.select((s) => s.roomOptions?.mode), (
      prev,
      next,
    ) {
      if (next != null && next != state.roomMode) {
        state = state.copyWith(roomMode: next);
      }
    });
    // 同步我方座位号（引擎编号 ↔ 座位映射的锚点，见 teamOfEnginePlayer）。
    // selfType 由大厅阶段的 STOC_TYPE_CHANGE 给出，整场对局期间不再变化。
    final selfType = ref.read(duelRoomProvider.select((s) => s.selfType));
    ref.listen(duelRoomProvider.select((s) => s.selfType), (prev, next) {
      final seat = next.isDuelist ? next.slot : -1;
      if (seat != state.mySeat) {
        state = state.copyWith(mySeat: seat);
      }
    });
    ref.onDispose(_dispose);
    return DuelFieldState(
      roomMode: roomMode,
      mySeat: selfType.isDuelist ? selfType.slot : -1,
    );
  }

  void _dispose() {
    _disposed = true;
    _timeLimitTimer?.cancel();
    _battlePresentationTimer?.cancel();
  }

  // ──────────────────────────────────────────
  // 卡片信息（缓存收敛在 dataService）
  // ──────────────────────────────────────────

  /// 获取卡片信息（同步读取 dataService 缓存，未命中返回 null）
  pkg.CardInfo? getCardInfo(int code) => _dataService.getCardCached(code);

  /// 批量预加载期间挂起的加载数；归零时统一触发一次状态通知。
  int _pendingCardLoads = 0;

  /// 批量预加载是否有新卡信息入库（决定归零时要不要通知）。
  bool _cardCacheDirty = false;

  /// 异步预加载卡片信息（缓存判断在 dataService.getCard 内部）。
  ///
  /// 批量预加载（preloadCardInfos 并发多张）时不再每张各触发一次
  /// state 通知：等本批全部加载完成后只通知一次，避免高频重建。
  Future<void> ensureCardInfo(int code) async {
    _pendingCardLoads++;
    try {
      final info = await _dataService.getCard(code);
      if (info != null) _cardCacheDirty = true;
    } catch (e) {
      console.log('Failed to load card info for $code: $e');
    }
    _pendingCardLoads--;
    if (_pendingCardLoads <= 0) {
      _pendingCardLoads = 0;
      if (_cardCacheDirty && !_disposed) {
        _cardCacheDirty = false;
        // 缓存填充后递增版本号通知订阅方（检视器/确认面板等按版本号
        // watch，拿到新卡名；无参 copyWith 对 select 订阅者不产生信号）。
        state = state.copyWith(cardInfoVersion: state.cardInfoVersion + 1);
      }
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
  ///
  /// 对方手牌隐私：对方抽到的卡只记数量（存 0 占位），
  /// 不落地明文卡密；UI 对方手牌只渲染卡背（cardsVisible: false）。
  void applyDraw(MsgDraw msg) {
    final isMyDraw = msg.player == state.myController;
    final drawnCodes = isMyDraw
        ? List<int>.of(msg.cards)
        : List<int>.filled(msg.cards.length, 0);
    final drawEvent = DrawAnimationEvent(
      id: state.drawAnimationTick + 1,
      player: msg.player,
      codes: drawnCodes,
      turnCount: state.turnCount,
    );
    if (isMyDraw) {
      state = state.copyWith(
        selfHand: [...state.selfHand, ...msg.cards],
        selfDeck: state.selfDeck - msg.count,
        drawAnimationEvent: drawEvent,
        drawAnimationTick: drawEvent.id,
      );
    } else {
      state = state.copyWith(
        opponentHand: [...state.opponentHand, ...drawnCodes],
        oppDeck: state.oppDeck - msg.count,
        drawAnimationEvent: drawEvent,
        drawAnimationTick: drawEvent.id,
      );
    }
  }

  /// 批量应用服务端发来的区域更新。
  void applyUpdateData(MsgUpdateData msg) {
    // 怪兽区的 MSG_UPDATE_DATA 是「7 槽位整区快照」（空槽 len=4 无 action）。
    // 先清掉该玩家怪兽区里所有卡再按快照重建，避免 EMZ 等已离开但没走
    // MOVE 的卡残留（整区重同步语义）。
    //
    // 快照只带 code/position（不含 attack/defense/name），清空重建会丢掉
    // 之前从 MSG_UPDATE_CARD / MSG_BATTLE 拿到的攻守与卡名；这里先按 key
    // 备份旧怪兽区卡，重建时回退这些字段，避免攻击力徽章消失。
    Map<String, FieldCard>? prevZoneCards;
    if (msg.zone == CARD_ZONE_MZONE) {
      prevZoneCards = {
        for (final e in state.fieldCards.entries)
          if (e.value.controller == msg.player &&
              e.value.zone == CARD_ZONE_MZONE)
            e.key: e.value,
      };
      state = _clearZone(state, msg.player, CARD_ZONE_MZONE);
    }
    var atkFallbackCount = 0;
    for (final action in msg.actions) {
      final location = action.location;
      if (location == null) {
        continue;
      }
      final fallbackKey = state.fieldCardKey(
        location.controller,
        location.location,
        location.sequence,
      );
      final fallback = prevZoneCards?[fallbackKey];
      if (fallback != null &&
          action.attack == null &&
          fallback.attack != null) {
        atkFallbackCount++;
      }
      _applyUpdateAction(
        controller: location.controller,
        zone: location.location,
        sequence: location.sequence,
        position: location.position,
        // 里侧卡（对端）可能不带 CODE flag（code==null）：用 0 兜底，
        // 仍占槽并渲染卡背，而不是当作空槽跳过。
        code: action.code ?? 0,
        action: action,
        fallback: fallback,
      );
    }
    if (msg.zone == CARD_ZONE_MZONE) {
      console.log(
        'applyUpdateData: MZONE rebuild player=${msg.player} '
        'prev=${prevZoneCards?.length ?? 0} actions=${msg.actions.length} '
        'atkFallback=$atkFallbackCount',
      );
    }
  }

  /// 清掉指定玩家在指定区域的全部场地卡（保留其它区域）。
  DuelFieldState _clearZone(DuelFieldState s, int controller, int zone) {
    final cards = <String, FieldCard>{};
    for (final entry in s.fieldCards.entries) {
      final card = entry.value;
      if (card.controller == controller && card.zone == zone) continue;
      cards[entry.key] = card;
    }
    return s.copyWith(fieldCards: cards);
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
  ///
  /// 对方手牌隐私：对方「卡组→手牌」的移动只记数量（存 0 占位），
  /// 不落地明文卡密；后续若服务端以 MSG_CONFIRM_CARDS 展示该卡，
  /// revealDeckToHandDraw / syncConfirmedCard 才会写入真实卡密。
  void applyMove(MsgMove msg) {
    final isOpponentDeckToHand =
        (msg.from.location & CARD_ZONE_DECK) != 0 &&
        (msg.to.location & CARD_ZONE_HAND) != 0 &&
        msg.to.controller != state.myController;
    state = _removeCardFromLocation(
      state,
      msg.from.controller,
      msg.from.location,
      msg.from.sequence,
    );
    state = _addCardToLocation(
      state,
      isOpponentDeckToHand ? 0 : msg.code,
      msg.to.controller,
      msg.to.location,
      msg.to.sequence,
      msg.to.position,
    );
    if (msg.code > 0 && !isOpponentDeckToHand) {
      unawaited(ensureCardInfo(msg.code));
    }
    if (isOpponentDeckToHand) {
      final drawEvent = DrawAnimationEvent(
        id: state.drawAnimationTick + 1,
        player: msg.to.controller,
        codes: const [0],
        turnCount: state.turnCount,
      );
      state = state.copyWith(
        drawAnimationEvent: drawEvent,
        drawAnimationTick: drawEvent.id,
      );
    }
  }

  /// MSG_CONFIRM_CARDS 揭示对手刚检索到手牌的卡时，更新当前动画事件为可见。
  void revealDeckToHandDraw(List<CardInfo> cards) {
    final current = state.drawAnimationEvent;
    if (current == null || current.player == state.myController) return;
    for (final card in cards) {
      if (card.controller == current.player &&
          (card.location & CARD_ZONE_HAND) != 0 &&
          card.code > 0) {
        state = state.copyWith(
          drawAnimationEvent: current.copyWith(
            codes: [card.code],
            revealCard: true,
          ),
        );
        return;
      }
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
    console.log(
      'applyPosChange: code=${card.code} c=${msg.cardInfo.controller} '
      'z=${card.zone} s=${card.sequence} '
      'pos=${card.position}->${msg.curPosition}',
    );
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
    state = state.copyWith(
      handShufflePlayer: msg.player,
      handShuffleTick: state.handShuffleTick + 1,
    );
  }

  /// 本地洗切自己的手牌（纯展示层：重排本地手牌顺序并触发洗牌抖动，
  /// 不发服务端协议——牌序由服务端维护，本地重排仅影响己方显示）。
  void shuffleSelfHand() {
    if (state.selfHand.length < 2) return;
    final shuffled = [...state.selfHand]..shuffle();
    addLog('洗切了手牌。', player: state.myController);
    state = state.copyWith(
      selfHand: shuffled,
      handShufflePlayer: state.myController,
      handShuffleTick: state.handShuffleTick + 1,
    );
  }

  /// 处理洗额外卡组消息（MSG_SHUFFLE_EXTRA）。
  void handleShuffleExtra(MsgShuffleExtra msg) {
    addLog('洗切了额外卡组。', player: msg.player);
    state = state.withExtraShuffle(msg.player);
  }

  /// 按消息内容把卡片更新写回到对应区域。
  ///
  /// [fallback] 用于怪兽区整区快照重建时回退快照里不包含的字段
  /// （attack/defense/name/position）：清空重建后 [current] 为 null，
  /// 靠旧卡兜底，避免攻击力徽章消失或里侧卡状态丢失。
  void _applyUpdateAction({
    required int controller,
    required int zone,
    required int sequence,
    required int position,
    required int code,
    required MsgUpdateAction action,
    FieldCard? fallback,
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
      // 清空重建后 current 为 null，回退到旧卡（fallback）补齐快照未带的字段。
      final base = current ?? fallback;
      final effectiveCode = code > 0 ? code : (base?.code ?? 0);
      final overlayCount = action.overlayCards.isNotEmpty
          ? action.overlayCards.length
          : (base?.overlayCount ?? 0);
      final cards = state.fieldCards;
      state = state.copyWith(
        fieldCards: {
          ...cards,
          key: FieldCard(
            code: effectiveCode,
            controller: controller,
            zone: normalizedZone,
            sequence: normalizedSequence,
            position: position != 0 ? position : (base?.position ?? 0),
            overlayCount: overlayCount,
            disabled: base?.disabled ?? false,
            attack: action.attack ?? base?.attack,
            defense: action.defense ?? base?.defense,
            name: base?.name,
          ),
        },
      );
      // 里侧卡（code<=0）或攻击力从旧卡回退时打印，便于定位卡背/攻击力缺失问题。
      final atkFallbackHit = action.attack == null && base?.attack != null;
      if (effectiveCode <= 0 || atkFallbackHit) {
        console.log(
          'applyUpdateField: c=$controller z=$normalizedZone '
          's=$normalizedSequence code=$effectiveCode '
          'pos=${position != 0 ? position : (base?.position ?? 0)} '
          'atk=${action.attack ?? base?.attack} '
          'def=${action.defense ?? base?.defense}'
          '${atkFallbackHit ? ' (atkFallback)' : ''}',
        );
      }
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
              selfExtra: state.selfExtra < nextCount
                  ? nextCount
                  : state.selfExtra,
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
              selfGrave: state.selfGrave < nextCount
                  ? nextCount
                  : state.selfGrave,
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
              selfRemoved: state.selfRemoved < nextCount
                  ? nextCount
                  : state.selfRemoved,
            )
          : state.copyWith(
              opponentRemovedCodes: codes,
              oppRemoved: state.oppRemoved < nextCount
                  ? nextCount
                  : state.oppRemoved,
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
      // 卡组计数下限为 0：乱序/重复的 MSG_MOVE 不应把计数打成负数。
      return isSelf
          ? s.copyWith(selfDeck: s.selfDeck > 0 ? s.selfDeck - 1 : 0)
          : s.copyWith(oppDeck: s.oppDeck > 0 ? s.oppDeck - 1 : 0);
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
      final key = s.fieldCardKey(controller, location, sequence);
      final cards = s.fieldCards;
      return s.copyWith(
        fieldCards: {
          ...cards,
          key: FieldCard(
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

  /// 对局日志上限：与聊天（_maxMessages=500）对齐，超出丢弃最旧条目，
  /// 避免长对局（尤其是 match 多局）日志列表无界增长拖垮内存与渲染。
  static const int maxDuelLogs = 500;

  /// 记录对局日志并触发刷新。
  ///
  /// [player] 非空时该条战报加《玩家名》前缀（标注动作归属方）；
  /// 系统/阶段类消息不传 player，保持无前缀。
  void addLog(String log, {int? player}) {
    final text = player == null ? log : '《${state.playerNameOf(player)}》 $log';
    if (kDebugMode) {
      console.log('Duel log: $text');
    }
    var logs = state.duelLogs;
    if (logs.length >= maxDuelLogs) {
      logs = logs.sublist(logs.length - maxDuelLogs + 1);
    }
    state = state.copyWith(duelLogs: [...logs, text]);
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
      // 初始 LP 是 LP 条的满格基准：取双方最大值兜底（标准规则双方相等）。
      startLp: msg.life1 > msg.life2 ? msg.life1 : msg.life2,
      selfDeck: isPlayer0 ? msg.deckSize1 : msg.deckSize2,
      selfExtra: isPlayer0 ? msg.extraSize1 : msg.extraSize2,
      oppDeck: isPlayer0 ? msg.deckSize2 : msg.deckSize1,
      oppExtra: isPlayer0 ? msg.extraSize2 : msg.extraSize1,
      selfHand: const [],
      opponentHand: const [],
      fieldCards: const {},
      turnCount: 1,
      // 清空上一局残留的抽卡动画事件：页面以「事件变为 null」作为
      // 新对局信号，同步清空本地动画队列。
      drawAnimationEvent: null,
      drawAnimationTick: 0,
      // Match 局间重开：清掉上一局残留的 per-duel 状态——
      // 胜负结果（否则退出导航会拿上一局结算）、连锁栈、战斗演出、
      // 阶段与当前回合玩家（MSG_NEW_TURN / MSG_NEW_PHASE 随后即会刷新）。
      duelResult: null,
      chains: const [],
      battlePresentation: null,
      // Match 局间清攻击残留：900ms 清理计时器可能还没触发，
      // 残留 key 会让下一局首个同 key 攻击被字符串 diff 吞掉。
      lastAttackFrom: null,
      lastAttackTo: null,
      phase: DuelPhase.idle,
      currentPlayer: 0,
    );
    addLog('决斗开始。');
  }

  void handleNewTurn(dynamic data) {
    final msg = data as MsgNewTurn;
    state = state.copyWith(
      currentPlayer: msg.player,
      turnCount: state.turnCount + 1,
    );
    addLog('的回合。', player: msg.player);
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
      attackEventId: state.attackEventId + 1,
      battlePresentation: BattlePresentation(
        attackerZoneKey: from,
        defenderZoneKey: to,
        attackerName: attackerName,
        defenderName: to == null ? null : state.fieldCards[to]?.name ?? '怪兽',
      ),
    );
    if (to != null) {
      final targetName = state.fieldCards[to]?.name ?? '怪兽';
      addLog('$attackerName 攻击 $targetName。', player: msg.attacker.controller);
    } else {
      addLog('$attackerName 发动直接攻击。', player: msg.attacker.controller);
    }
  }

  void handleDamage(dynamic data) {
    final msg = data as MsgDamage;
    _applyLpChange(msg.player, -msg.value);
    addLog('受到 ${msg.value} 点伤害。', player: msg.player);
  }

  void handleRecover(dynamic data) {
    final msg = data as MsgRecover;
    _applyLpChange(msg.player, msg.value);
    addLog('回复了 ${msg.value} 点生命值。', player: msg.player);
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
    addLog('支付了 ${msg.value} 点生命值。', player: msg.player);
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
    addLog('正在$actionLabel $name。', player: location.controller);
  }

  void handleSummonFinished(String actionLabel) {
    final key = state.lastSummonKey;
    final name = key != null ? state.fieldCards[key]?.name ?? '怪兽' : '怪兽';
    if (key != null) {
      _emitSummonEffect(key, actionLabel);
    }
    final player = key != null ? state.fieldCards[key]?.controller : null;
    state = state.copyWith(lastSummonKey: null);
    addLog('$name $actionLabel成功。', player: player);
  }

  /// 依据完成消息与卡数据推断特效类型并发事件（SUMMONED 时机播放）。
  void _emitSummonEffect(String slotId, String actionLabel) {
    final code = state.fieldCards[slotId]?.code ?? 0;
    final type = resolveSummonEffectType(
      actionLabel,
      code > 0 ? getCardInfo(code) : null,
    );
    state = state.copyWith(
      summonEffectEvent: SummonEffectEvent(
        id: state.summonEffectTick + 1,
        code: code,
        zoneKey: slotId,
        type: type,
      ),
      summonEffectTick: state.summonEffectTick + 1,
    );
  }

  void handleHint(MsgHint msg) {
    final code = cardCodeFromDescriptionValue(msg.hintData);
    if (code != null && code >= 1000000) {
      unawaited(ensureCardInfo(code));
    }
    // 提示文案（event/message/selectMessage/optionSelected 的 hintData 是
    // strings.conf 的 !system 索引）：能解析到中文文案就写进战报。
    final hintText = switch (msg.hintType) {
      MsgHintType.event ||
      MsgHintType.message ||
      MsgHintType.selectMessage ||
      MsgHintType.optionSelected =>
        ref.read(stringsServiceProvider).systemString(msg.hintData),
      _ => null,
    };
    if (hintText != null && hintText.isNotEmpty) {
      addLog(hintText);
    }
  }

  void handleWin(MsgWin msg) {
    // 对局结束：停掉所有本地定时器，避免胜负已分后倒计时/演出继续跑。
    _timeLimitTimer?.cancel();
    _timeLimitTimer = null;
    _battlePresentationTimer?.cancel();
    _battlePresentationTimer = null;
    final didWin = msg.winPlayer == state.myController;
    state = state.copyWith(
      duelResult: <String, Object?>{
        'didWin': didWin,
        'winPlayer': msg.winPlayer,
        'reason': msg.reason,
        'selfName': state.playerNameOf(state.myController),
        'opponentName': state.playerNameOf(1 - state.myController),
        'selfLp': state.selfLp,
        'opponentLp': state.opponentLp,
      },
    );
    addLog(didWin ? '决斗胜利。' : '决斗失败。');
  }

  void handleSet(MsgSet msg) {
    if (msg.code > 0) {
      unawaited(ensureCardInfo(msg.code));
    }
    final name = getCardInfo(msg.code)?.name ?? '卡片';
    addLog('$name 已盖放。', player: msg.location.controller);
    // 盖放尘雾特效（背面放置不升卡图；对手盖放 code 未知为 0）。
    state = state.copyWith(
      summonEffectEvent: SummonEffectEvent(
        id: state.summonEffectTick + 1,
        code: msg.code,
        zoneKey: zoneKeyOf(
          msg.location.controller,
          msg.location.location,
          msg.location.sequence,
        ),
        type: SummonEffectType.set,
      ),
      summonEffectTick: state.summonEffectTick + 1,
    );
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
    final attackerZoneKey = zoneKeyOf(
      msg.attacker.controller,
      msg.attacker.location,
      msg.attacker.sequence,
    );
    final defenderZoneKey = msg.hasDefender
        ? zoneKeyOf(
            msg.defender.controller,
            msg.defender.location,
            msg.defender.sequence,
          )
        : null;
    final base =
        state.battlePresentation ??
        BattlePresentation(
          attackerZoneKey: attackerZoneKey,
          defenderZoneKey: defenderZoneKey,
          attackerName: state.fieldCards[attackerZoneKey]?.name ?? '怪兽',
          defenderName: defenderZoneKey == null
              ? null
              : state.fieldCards[defenderZoneKey]?.name ?? '怪兽',
        );
    final presentation = base.copyWith(
      attackerZoneKey: attackerZoneKey,
      defenderZoneKey: defenderZoneKey,
      attackerName: state.fieldCards[attackerZoneKey]?.name ?? '怪兽',
      defenderName: defenderZoneKey == null
          ? null
          : state.fieldCards[defenderZoneKey]?.name ?? '怪兽',
      attackerAttack: msg.attackerAttack,
      attackerDefense: msg.attackerDefense,
      attackerPosition: msg.attackerPosition,
      defenderAttack: msg.hasDefender ? msg.defenderAttack : null,
      defenderDefense: msg.hasDefender ? msg.defenderDefense : null,
      defenderPosition: msg.hasDefender ? msg.defenderPosition : null,
    );
    state = state.copyWith(battlePresentation: presentation);
    // 攻击方归属：由攻击方槽位的控制者解析玩家名前缀。
    final attackerController = state.fieldCards[attackerZoneKey]?.controller;
    if (msg.hasDefender) {
      addLog(
        '${presentation.attackerName} ${_battleValueLabel(msg.attackerAttack, msg.attackerDefense, msg.attackerPosition)} '
        'VS '
        '${presentation.defenderName} ${_battleValueLabel(msg.defenderAttack, msg.defenderDefense, msg.defenderPosition)}。',
        player: attackerController,
      );
    } else {
      addLog(
        '${presentation.attackerName} 进行直接攻击结算。',
        player: attackerController,
      );
    }
  }

  void handleChainEnd(dynamic data) {
    state = state.copyWith(chains: const []);
  }

  void handleShuffleDeck(dynamic data) {
    final msg = data as MsgShuffleDeck;
    addLog('洗切了卡组。', player: msg.player);
    state = state.withDeckShuffle(msg.player);
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

  /// STOC_TIME_LIMIT：同步被计时方的剩余时间并本地倒数。
  ///
  /// - 倒计时只递减「本条消息正在计时」的玩家；该玩家归零即停表，
  ///   不再以「双方都归零」为条件（对方残留的旧时间值会让旧实现
  ///   的定时器永不取消）。
  /// - 这里不再回 CTOS_TIME_CONFIRM：duelink_socket 的 SocketDuelService
  ///   已在收到 STOC_TIME_LIMIT 时自动确认（srvpro 系服务器在收到确认前
  ///   会挂起后续回包）。在此重复确认会导致每条 TIME_LIMIT 双发
  ///   CTOS_TIME_CONFIRM，使服务器计时同步错乱。
  void handleTimeLimit(StocTimeLimit msg) {
    final player = msg.player;
    final left = msg.leftTime;
    state = player == state.myController
        ? state.copyWith(selfTimeLeft: left)
        : state.copyWith(opponentTimeLeft: left);
    _timeLimitTimer?.cancel();
    _timeLimitTimer = null;
    if (left > 0) {
      _timeLimitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final timedLeft = player == state.myController
            ? state.selfTimeLeft
            : state.opponentTimeLeft;
        if (timedLeft <= 0) {
          // 被计时方已归零：停表（服务端会另行下发超时裁决）。
          _timeLimitTimer?.cancel();
          _timeLimitTimer = null;
          return;
        }
        final next = timedLeft - 1;
        state = player == state.myController
            ? state.copyWith(selfTimeLeft: next)
            : state.copyWith(opponentTimeLeft: next);
        if (next <= 0) {
          _timeLimitTimer?.cancel();
          _timeLimitTimer = null;
        }
      });
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
