import 'package:biz/duel/models/field_card.dart';
import 'package:biz/duel/models/summon_effect_event.dart';

import '../scene3d/fx/effects_manager.dart';
import '../scene3d/standee_diff.dart';

/// biz 快照 → 场景视图模型的纯函数映射（可单测）。

/// 场上卡 → 立牌视图。
Map<String, StandeeCardView> mapFieldCards(Map<String, FieldCard> cards) {
  return {
    for (final entry in cards.entries)
      entry.key: StandeeCardView(
        zoneKey: entry.key,
        code: entry.value.code,
        position: entry.value.position,
        overlayCount: entry.value.overlayCount,
      ),
  };
}

/// biz 召唤特效类型 → 场景特效枚举。
SummonFx mapSummonFx(SummonEffectType type) => switch (type) {
  SummonEffectType.normal => SummonFx.normal,
  SummonEffectType.special => SummonFx.special,
  SummonEffectType.flip => SummonFx.flip,
  SummonEffectType.set => SummonFx.set,
  SummonEffectType.ritual => SummonFx.ritual,
  SummonEffectType.fusion => SummonFx.fusion,
  SummonEffectType.synchro => SummonFx.synchro,
  SummonEffectType.xyz => SummonFx.xyz,
  SummonEffectType.link => SummonFx.link,
};
