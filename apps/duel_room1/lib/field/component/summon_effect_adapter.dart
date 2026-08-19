import 'package:biz/duel/models/summon_effect_event.dart';
import 'package:cardlive/cardlive.dart';
import 'package:flame/components.dart';

import 'package:duel_room1/field/duel_field_world.dart';

/// biz 特效类型 → cardlive 权威类别（决斗域语义到表现层分类的映射）。
SummonCategory summonCategoryOfEffect(SummonEffectType type) {
  return switch (type) {
    SummonEffectType.normal => SummonCategory.normal,
    SummonEffectType.special => SummonCategory.special,
    SummonEffectType.flip => SummonCategory.flip,
    SummonEffectType.set => SummonCategory.set,
    SummonEffectType.ritual => SummonCategory.ritual,
    SummonEffectType.fusion => SummonCategory.fusion,
    SummonEffectType.synchro => SummonCategory.synchro,
    SummonEffectType.xyz => SummonCategory.xyz,
    SummonEffectType.link => SummonCategory.link,
  };
}

/// biz 事件 → cardlive 播放请求（卡槽世界坐标 + 缓存卡图）。
SummonAnimationSpec summonSpecForEvent(
  DuelFieldWorld world,
  SummonEffectEvent event,
) {
  return SummonAnimationSpec(
    category: summonCategoryOfEffect(event.type),
    position: world.worldPositionForZoneKey(event.zoneKey) ?? Vector2.zero(),
    cardImage: event.code > 0 ? world.getCachedCardImage(event.code) : null,
  );
}

/// 召唤特效适配器：监听快照的 `summonEffectTick`，把 biz 事件映射成
/// [SummonAnimationSpec] 入队 [SummonQueueDriver]。
///
/// cardlive 的驱动器不感知决斗协议，本组件是决斗侧唯一接线
/// （连续召唤不打断，同 deckShuffleTick 范式）。
class SummonEffectAdapter extends Component
    with HasWorldReference<DuelFieldWorld> {
  SummonEffectAdapter(this.driver);

  final SummonQueueDriver driver;

  int _lastTick = 0;

  @override
  void update(double dt) {
    super.update(dt);
    final tick = world.game.snapshot.summonEffectTick;
    if (tick != _lastTick) {
      _lastTick = tick;
      final event = world.game.snapshot.summonEffectEvent;
      // tick 与事件 id 不一致（如同批多条消息只见到最新一条）时，
      // 以可见的最新事件为准，中间的退化丢弃（同 deckShuffleTick 语义）。
      if (event != null) {
        driver.enqueue(summonSpecForEvent(world, event));
      }
    }
  }
}
