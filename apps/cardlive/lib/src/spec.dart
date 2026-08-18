import 'dart:ui' as ui;

import 'package:flame/components.dart';

import 'category.dart';
import 'twod/themes/summon_theme.dart';

/// 一次召唤动画的播放请求（驱动与动画组件之间的唯一契约）。
///
/// 来源无关：决斗场地适配器、鉴赏页、debug 按钮都构造它入队。
class SummonAnimationSpec {
  const SummonAnimationSpec({
    required this.category,
    required this.position,
    this.cardImage,
    this.themeOverride,
    this.onFinished,
  });

  final SummonCategory category;

  /// 动画中心点（决斗场地 = 卡槽世界坐标；全屏鉴赏场景不使用）。
  final Vector2 position;

  /// 要升起的卡图；null = 不显示卡图（对手盖放、纯阵效等）。
  final ui.Image? cardImage;

  /// 覆盖类别默认主题（如按怪兽换色）；null 用 [themeFor] 的默认值。
  final SummonTheme? themeOverride;

  /// 播放结束回调（驱动器用它推进队列）。
  final void Function()? onFinished;

  /// 复制并替换 [onFinished]（驱动器包装完成回调时用）。
  SummonAnimationSpec withOnFinished(void Function()? callback) {
    return SummonAnimationSpec(
      category: category,
      position: position,
      cardImage: cardImage,
      themeOverride: themeOverride,
      onFinished: callback,
    );
  }
}
