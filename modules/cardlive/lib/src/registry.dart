import 'package:flame/components.dart';

import 'category.dart';
import 'spec.dart';
import 'twod/animations/field_summon_player.dart';

/// 类别 → 动画组件工厂。
typedef SummonAnimationFactory =
    PositionComponent Function(SummonAnimationSpec spec);

/// 召唤动画注册表：按类别分发到对应的时间线组件。
///
/// 阶段 1：所有类别共用 [FieldSummonPlayer]（按主题差异化）；
/// 阶段 2 起逐类别注册独立时间线组件。未注册的类别回落到
/// [SummonCategory.special] 的工厂。
class SummonAnimationRegistry {
  SummonAnimationRegistry();

  final Map<SummonCategory, SummonAnimationFactory> _factories = {};

  void register(SummonCategory category, SummonAnimationFactory factory) {
    _factories[category] = factory;
  }

  PositionComponent create(SummonAnimationSpec spec) {
    final factory =
        _factories[spec.category] ?? _factories[SummonCategory.special]!;
    return factory(spec);
  }
}

/// 默认注册表：全部类别使用通用场地播放器。
SummonAnimationRegistry defaultSummonAnimationRegistry() {
  final registry = SummonAnimationRegistry();
  for (final category in SummonCategory.values) {
    registry.register(category, FieldSummonPlayer.new);
  }
  return registry;
}
