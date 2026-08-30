import 'package:biz/duel/models/battle_presentation.dart';
import 'package:biz/duel/models/card_move_event.dart';
import 'package:biz/duel/models/summon_effect_event.dart';
import 'package:biz/duel/models/field_card.dart';
import 'package:biz/duel/models/lp_change_event.dart';
import 'package:collection/collection.dart';
import 'package:duelink/duelink.dart' show DuelPhase;

import '../components/hand_card/hand.dart';


/// 推入 Flame 场地的不可变状态快照。
///
/// widget 层（DuelFieldPage）的 listenManual 订阅在 provider 变更时
/// 组装本快照并经 [DuelFlameGame.applySnapshot] 推入游戏（不经 build）；
/// Flame component
/// 只读快照、不 watch 任何 Provider，渲染循环与 Riverpod 完全解耦。
///
/// 快照只包含 Flame 渲染真正用到的字段子集（场上卡/手牌/阶段/伤害步骤/
/// 攻击呈现/洗牌信号/区域卡码/就地选择高亮）；交互回调（点卡/检视/
/// 放置）仍走构造时注入的闭包，不经过快照。
class FlameFieldSnapshot {
  const FlameFieldSnapshot({
    required this.fieldCards,
    required this.myController,
    required this.phase,
    required this.inDamageStep,
    required this.battlePresentation,
    required this.selfDeckShuffleTick,
    required this.oppDeckShuffleTick,
    required this.selfExtraShuffleTick,
    required this.oppExtraShuffleTick,
    required this.summonEffectTick,
    required this.summonEffectEvent,
    // 移动飞牌信号给默认值：既有快照构造点（测试等）不受影响。
    this.cardMoveTick = 0,
    this.cardMoveEvent,
    required this.selfDeck,
    required this.oppDeck,
    required this.zoneCodes,
    required this.inlineSelectedFieldKeys,
    required this.inlineSelectableFieldKeys,
    required this.placeTargetFieldKeys,
    required this.activatableZoneKeys,
    required this.chainOrderBySlotKey,
    required this.selfHand,
    required this.oppHand,
    // ── HUD 字段（回合徽章/中央计时/左侧状态卡）──
    // ⚠️ 本组字段刻意【不参与 ==/hashCode】：计时每秒变化、LP 频繁
    // 变化，纳入判等会让 applySnapshot 的 changed 短路失效，每秒触发
    // world.rebuildField() 全量重建。消费这些字段的组件（PhaseRail
    // 回合徽章 / CenterTimer / PlayerStatusCard）在 render/update 中
    // 直读快照，不依赖重建触发。给默认值是为了既有构造点（测试等）
    // 不受影响。
    this.turnCount = 0,
    this.currentPlayer = 0,
    this.selfTimeLeft = 0,
    this.opponentTimeLeft = 0,
    this.selfLp = 0,
    this.opponentLp = 0,
    this.selfExtra = 0,
    this.oppExtra = 0,
    this.selfGrave = 0,
    this.oppGrave = 0,
    this.selfRemoved = 0,
    this.oppRemoved = 0,
    this.selfName = '',
    this.oppName = '',
    this.lpChangeTick = 0,
    this.lpChangeEvent,
  });

  /// 首次推送前的空快照（场地状态尚未到达）。
  FlameFieldSnapshot.empty()
    : this(
        fieldCards: const {},
        myController: 0,
        phase: DuelPhase.idle,
        inDamageStep: false,
        battlePresentation: null,
        selfDeckShuffleTick: 0,
        oppDeckShuffleTick: 0,
        selfExtraShuffleTick: 0,
        oppExtraShuffleTick: 0,
        summonEffectTick: 0,
        summonEffectEvent: null,
        cardMoveTick: 0,
        cardMoveEvent: null,
        selfDeck: 0,
        oppDeck: 0,
        zoneCodes: const {},
        inlineSelectedFieldKeys: const {},
        inlineSelectableFieldKeys: const {},
        placeTargetFieldKeys: const {},
        activatableZoneKeys: const {},
        chainOrderBySlotKey: const {},
        selfHand: const HandSnapshot.empty(),
        oppHand: const HandSnapshot.empty(),
      );

  /// 场上卡（key 为 `controller_zone_sequence`）。
  final Map<String, FieldCard> fieldCards;

  /// 己方控制器编号（0/1），决定场地朝向。
  final int myController;

  /// 当前阶段（阶段灯渲染）。
  final DuelPhase phase;

  /// 是否处于伤害步骤（攻击呈现的冲击波特效开关）。
  final bool inDamageStep;

  /// 攻击宣言/战斗数值呈现（波束 + 信息牌）。
  final BattlePresentation? battlePresentation;

  /// 卡组洗切信号（每侧独立单调 tick，自增触发一次该侧洗牌动效）。
  ///
  /// 按侧拆分的原因：全局 tick+player 只能表达"最后一次洗牌"，双方
  /// 洗牌消息同帧到达时（开局必现）先洗牌一方的动效会被吞掉。
  final int selfDeckShuffleTick;
  final int oppDeckShuffleTick;

  /// 额外卡组洗切信号（每侧独立单调 tick）。
  final int selfExtraShuffleTick;
  final int oppExtraShuffleTick;

  /// 召唤特效信号（tick 自增触发一条几何召唤阵演出）。
  final int summonEffectTick;
  final SummonEffectEvent? summonEffectEvent;

  /// 卡片移动信号（tick 自增触发一次飞牌动画；抽卡不走此管线）。
  /// CardMoveAnimator 按 tick diff 消费（同 summonEffectTick 语义：
  /// 同帧多条移动只见最新一条）。
  final int cardMoveTick;
  final CardMoveEvent? cardMoveEvent;

  /// 双方卡组数量（卡组槽位预览卡）。
  final int selfDeck;
  final int oppDeck;

  /// 墓地/除外/额外区域卡码（区域预览卡顶卡）。
  /// key：self_grave / opp_grave / self_extra / opp_extra /
  /// self_removed / opp_removed。
  final Map<String, List<int>> zoneCodes;

  /// 就地选择多选中已勾选的槽位 key。
  final Set<String> inlineSelectedFieldKeys;

  /// 就地选择中可选中的槽位 key。
  final Set<String> inlineSelectableFieldKeys;

  /// 放置选择（MSG_SELECT_PLACE）的可放置空槽位 key。
  final Set<String> placeTargetFieldKeys;

  /// 当前 idle 窗口下「有可召唤/可发动卡」的区域 key（self_extra /
  /// self_grave / self_removed 等），驱动对应区域槽位的提醒角标。
  final Set<String> activatableZoneKeys;

  /// 连锁序号映射：槽位 key（场上卡 `controller_zone_sequence` 或
  /// `self_grave` 等区域堆命名 key）→ 连锁序号（1 起）。
  /// 卡槽组件据此把连锁序号直接画在卡片上（替代原居中连锁弹窗）；
  /// 连锁结束清空后由组件自行停留 1s 淡出。
  final Map<String, int> chainOrderBySlotKey;

  /// 己方手牌（底部手牌栏）。
  final HandSnapshot selfHand;

  /// 对方手牌（顶部手牌栏；codes 为 0 占位，faceUp=false）。
  final HandSnapshot oppHand;

  // ── HUD 字段（不参与判等，见构造器注释）──

  /// 当前回合数（MSG_NEW_TURN 累进；0 = 尚未下发）。
  final int turnCount;

  /// 当前行动方控制器编号（0/1）。
  final int currentPlayer;

  /// 双方剩余时间（秒，TIME_LIMIT 推送）。
  final int selfTimeLeft;
  final int opponentTimeLeft;

  /// 双方 LP。
  final int selfLp;
  final int opponentLp;

  /// 双方区域计数（额外/墓地/除外；卡组数用既有 selfDeck/oppDeck，
  /// 手牌数用 selfHand/oppHand 的 codes 长度）。
  final int selfExtra;
  final int oppExtra;
  final int selfGrave;
  final int oppGrave;
  final int selfRemoved;
  final int oppRemoved;

  /// 双方显示名（页面侧经 teamDisplayName 解析后推入，
  /// tag 双打为同队名字 " / " 连接）。
  final String selfName;
  final String oppName;

  /// LP 变动事件（伤害/回复/支付/直接变值）：tick 自增驱动
  /// LpChangeToastComponent 在受影响玩家状态卡旁播锚定 toast。
  /// 与 cardMoveEvent 同构：同帧多条只保留最新一条。
  final int lpChangeTick;
  final LpChangeEvent? lpChangeEvent;

  List<int> zoneCodesOf(String zoneKey) => zoneCodes[zoneKey] ?? const [];

  /// 内容判等：驱动 [DuelFlameGame.applySnapshot] 的重建短路——
  /// 快照内容未变时跳过 Flame 侧全量卡槽重建（弹窗/检视等纯 UI
  /// 状态变化也会触发页面 build，但不应误伤 Flame）。
  ///
  /// 集合走 [DeepCollectionEquality]：biz/duel 状态是不可变 copyWith
  /// 纪律，未变化的卡牌/列表复用实例（FieldCard 无 ==，按实例判等
  /// 恰好能精确识别"哪张卡变了"）；int/String 集合按值判等。
  static const _deep = DeepCollectionEquality();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlameFieldSnapshot &&
        other.myController == myController &&
        other.phase == phase &&
        other.inDamageStep == inDamageStep &&
        other.battlePresentation == battlePresentation &&
        other.selfDeckShuffleTick == selfDeckShuffleTick &&
        other.oppDeckShuffleTick == oppDeckShuffleTick &&
        other.selfExtraShuffleTick == selfExtraShuffleTick &&
        other.oppExtraShuffleTick == oppExtraShuffleTick &&
        other.summonEffectTick == summonEffectTick &&
        identical(other.summonEffectEvent, summonEffectEvent) &&
        other.cardMoveTick == cardMoveTick &&
        identical(other.cardMoveEvent, cardMoveEvent) &&
        other.selfDeck == selfDeck &&
        other.oppDeck == oppDeck &&
        _deep.equals(other.fieldCards, fieldCards) &&
        _deep.equals(other.zoneCodes, zoneCodes) &&
        _deep.equals(other.inlineSelectedFieldKeys, inlineSelectedFieldKeys) &&
        _deep.equals(
          other.inlineSelectableFieldKeys,
          inlineSelectableFieldKeys,
        ) &&
        _deep.equals(other.placeTargetFieldKeys, placeTargetFieldKeys) &&
        _deep.equals(other.activatableZoneKeys, activatableZoneKeys) &&
        _deep.equals(other.chainOrderBySlotKey, chainOrderBySlotKey) &&
        other.selfHand == selfHand &&
        other.oppHand == oppHand;
  }

  @override
  int get hashCode => Object.hashAll([
    myController,
    phase,
    inDamageStep,
    battlePresentation,
    selfDeckShuffleTick,
    oppDeckShuffleTick,
    selfExtraShuffleTick,
    oppExtraShuffleTick,
    summonEffectTick,
    summonEffectEvent,
    cardMoveTick,
    cardMoveEvent,
    selfDeck,
    oppDeck,
    _deep.hash(fieldCards),
    _deep.hash(zoneCodes),
    _deep.hash(inlineSelectedFieldKeys),
    _deep.hash(inlineSelectableFieldKeys),
    _deep.hash(placeTargetFieldKeys),
    _deep.hash(activatableZoneKeys),
    _deep.hash(chainOrderBySlotKey),
    selfHand,
    oppHand,
  ]);
}
