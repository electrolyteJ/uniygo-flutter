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
  // 卡图克隆持有：CardImageLoader 的 LRU 驱逐会 dispose 原图，动画
  // 播放期（约 1.1s）内必须自持克隆；播放结束经驱动器链式回调
  // onFinished 释放（driver._startNext 会先推进队列再调本回调）。
  final cached = event.code > 0 ? world.getCachedCardImage(event.code) : null;
  final image = cached?.clone();
  return SummonAnimationSpec(
    category: summonCategoryOfEffect(event.type),
    position: world.worldPositionForZoneKey(event.zoneKey) ?? Vector2.zero(),
    cardImage: image,
    onFinished: image == null ? null : () => image.dispose(),
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

  /// 卡图补充加载的短超时预算：召唤动画前 0.35s 为聚集阶段（无卡面），
  /// 预算内等到图即可让本次特效带上卡面；超时按无图入队，不阻塞特效。
  static const _imageWaitBudget = Duration(milliseconds: 350);

  int _lastTick = 0;
  bool _disposed = false;

  @override
  void onMount() {
    super.onMount();
    // DuelFieldWorld.reload()（热重载）会把同一实例移除后重新挂载，
    // 复位闭锁与 tick 游标，避免复用后静默丢特效/重播旧特效。
    _disposed = false;
    _lastTick = world.game.snapshot.summonEffectTick;
  }

  @override
  void onRemove() {
    _disposed = true;
    super.onRemove();
  }

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
        _enqueue(event);
      }
    }
  }

  /// 入队召唤特效。卡图命中同步缓存时直接入队；未命中（卡组/手牌
  /// 召唤的卡通常没缓存）则触发加载，在 [_imageWaitBudget] 内等到
  /// 就带卡面入队，超时/失败按无卡面入队（加载结果已入缓存，后续
  /// 特效与卡槽可直接命中）。
  void _enqueue(SummonEffectEvent event) {
    if (event.code <= 0 || world.getCachedCardImage(event.code) != null) {
      driver.enqueue(summonSpecForEvent(world, event));
      return;
    }
    world
        .loadCardImage(event.code)
        .timeout(_imageWaitBudget, onTimeout: () => null)
        .then((_) {
          if (_disposed) return;
          driver.enqueue(summonSpecForEvent(world, event));
        });
  }
}
