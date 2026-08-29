/// 召唤特效事件（通用层：几何召唤阵 + 粒子 + 卡图显现）。
///
/// 在 *_SUMMONED / MSG_SET 到达时由 duel_field_state 发出，
/// 经状态快照（tick 自增信号）推到表现层播放，语义同
/// deckShuffleTick / DrawAnimationEvent 的 tick 范式。
library;

import 'package:resource_data/card_info.dart' as pkg;

/// 召唤特效类型（决定配色与是否升卡图）。
///
/// normal/special/flip 由完成消息（'召唤'/'特殊召唤'/'反转召唤'）区分；
/// ritual/fusion/synchro/xyz/link 在 special 基础上按卡数据类型推断
/// （协议上都走 MSG_SP_SUMMONED）；set 为盖放（含怪兽与魔陷，
/// 背面放置不升卡图）。
enum SummonEffectType {
  normal,
  special,
  flip,
  set,
  ritual,
  fusion,
  synchro,
  xyz,
  link,
}

class SummonEffectEvent {
  /// 事件 id（= 发出时的 tick 值，单调递增）。
  final int id;

  /// 卡号（0 = 未知，如对手盖放）；卡图经 CardImageLoader 按 code 取。
  final int code;

  /// 目标卡槽标识（`controller_zone_sequence`，见 zoneKeyOf），定位世界坐标。
  final String zoneKey;

  final SummonEffectType type;

  const SummonEffectEvent({
    required this.id,
    required this.code,
    required this.zoneKey,
    required this.type,
  });
}

/// 依据完成消息与卡数据推断特效类型（纯函数，便于测试）。
///
/// [actionLabel] 为完成消息标签（'召唤'/'特殊召唤'/'反转召唤'）；
/// [info] 为卡数据（未加载完成时为 null，退回 special 配色）。
/// extra 差异化：仪式/融合/同调/超量/链接在协议上都是特殊召唤，
/// 按卡数据类型细分（灵摆融合等多类别卡取第一个命中项，
/// 优先级 link > xyz > synchro > fusion > ritual）。
SummonEffectType resolveSummonEffectType(
  String actionLabel,
  pkg.CardInfo? info,
) {
  var type = switch (actionLabel) {
    '召唤' => SummonEffectType.normal,
    '反转召唤' => SummonEffectType.flip,
    _ => SummonEffectType.special,
  };
  if (type == SummonEffectType.special && info != null) {
    if (info.isLink) {
      type = SummonEffectType.link;
    } else if (info.isXyz) {
      type = SummonEffectType.xyz;
    } else if (info.isSynchro) {
      type = SummonEffectType.synchro;
    } else if (info.isFusion) {
      type = SummonEffectType.fusion;
    } else if (info.isRitual) {
      type = SummonEffectType.ritual;
    }
  }
  return type;
}
