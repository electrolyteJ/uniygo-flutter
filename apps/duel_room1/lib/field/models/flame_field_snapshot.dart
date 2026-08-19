import 'package:biz/duel/models/battle_presentation.dart';
import 'package:biz/duel/models/summon_effect_event.dart';
import 'package:biz/duel/models/field_card.dart';
import 'package:collection/collection.dart';
import 'package:duelink/duelink.dart' show DuelPhase;

/// 推入 Flame 场地的不可变状态快照。
///
/// widget 层（DuelFieldPage）每次 build 从 biz/duel 的 Riverpod Provider
/// 组装本快照并经 [DuelFlameGame.applySnapshot] 推入游戏；Flame component
/// 只读快照、不 watch 任何 Provider，渲染循环与 Riverpod 完全解耦。
///
/// 快照只包含 Flame 渲染真正用到的字段子集（场上卡/阶段/伤害步骤/
/// 攻击呈现/洗牌信号/区域卡码/就地选择高亮）；交互回调（点卡/检视/
/// 放置）仍走构造时注入的闭包，不经过快照。
class FlameFieldSnapshot {
  const FlameFieldSnapshot({
    required this.fieldCards,
    required this.myController,
    required this.phase,
    required this.inDamageStep,
    required this.battlePresentation,
    required this.deckShuffleTick,
    required this.deckShufflePlayer,
    required this.summonEffectTick,
    required this.summonEffectEvent,
    required this.selfDeck,
    required this.oppDeck,
    required this.zoneCodes,
    required this.inlineSelectedFieldKeys,
    required this.inlineSelectableFieldKeys,
    required this.placeTargetFieldKeys,
  });

  /// 首次推送前的空快照（场地状态尚未到达）。
  FlameFieldSnapshot.empty()
    : this(
        fieldCards: const {},
        myController: 0,
        phase: DuelPhase.idle,
        inDamageStep: false,
        battlePresentation: null,
        deckShuffleTick: 0,
        deckShufflePlayer: 0,
        summonEffectTick: 0,
        summonEffectEvent: null,
        selfDeck: 0,
        oppDeck: 0,
        zoneCodes: const {},
        inlineSelectedFieldKeys: const {},
        inlineSelectableFieldKeys: const {},
        placeTargetFieldKeys: const {},
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

  /// 卡组洗切信号（tick 自增触发一次洗牌动效）。
  final int deckShuffleTick;
  final int deckShufflePlayer;

  /// 召唤特效信号（tick 自增触发一条几何召唤阵演出）。
  final int summonEffectTick;
  final SummonEffectEvent? summonEffectEvent;

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
        other.deckShuffleTick == deckShuffleTick &&
        other.deckShufflePlayer == deckShufflePlayer &&
        other.summonEffectTick == summonEffectTick &&
        identical(other.summonEffectEvent, summonEffectEvent) &&
        other.selfDeck == selfDeck &&
        other.oppDeck == oppDeck &&
        _deep.equals(other.fieldCards, fieldCards) &&
        _deep.equals(other.zoneCodes, zoneCodes) &&
        _deep.equals(other.inlineSelectedFieldKeys, inlineSelectedFieldKeys) &&
        _deep.equals(
          other.inlineSelectableFieldKeys,
          inlineSelectableFieldKeys,
        ) &&
        _deep.equals(other.placeTargetFieldKeys, placeTargetFieldKeys);
  }

  @override
  int get hashCode => Object.hash(
    myController,
    phase,
    inDamageStep,
    battlePresentation,
    deckShuffleTick,
    deckShufflePlayer,
    summonEffectTick,
    summonEffectEvent,
    selfDeck,
    oppDeck,
    _deep.hash(fieldCards),
    _deep.hash(zoneCodes),
    _deep.hash(inlineSelectedFieldKeys),
    _deep.hash(inlineSelectableFieldKeys),
    _deep.hash(placeTargetFieldKeys),
  );
}
