import 'dart:math' as math;

import 'dart:ui';

/// 手牌扇形（凸弧）排布的纯几何计算。
///
/// 从 HandCardsBar 的 Flutter 实现移植，供 Flame 侧 HandBarComponent 使用；
/// 抽成纯 Dart 便于单测（对齐 phase_rail_layout / shuffle_slot 的风格）。
///
/// 排布规则：
/// - 卡片绕各自中心旋转，呈放射状扇形；中心卡略微升起（凸弧）；
/// - 手牌数不超出可用宽度时按自然间距 [baseSpacing] 铺开；
/// - 超出后压缩卡心间距（重叠排布，Master Duel 风格），不再横向滚动；
///   间距低于 [minSpacing] 后允许继续超出（实战中几乎不会触达）。
class HandFanLayout {
  /// 卡尺寸（与场上卡槽同规格）。
  static const double cardWidth = 64;
  static const double cardHeight = 90;

  /// 自然卡心间距（卡宽 64 + 间隙 8）。
  static const double baseSpacing = 72;

  /// 压缩后的最小卡心间距。
  static const double minSpacing = 24;

  /// 凸弧中心升起的最大高度。
  static const double arcLift = 10;

  /// 每张卡的放射旋转步长（弧度）。
  static const double rotationStep = 0.10;

  /// 选中/悬停时的额外上浮与放大（组件级动效的目标值）。
  static const double activeLift = 22;
  static const double activeScale = 1.16;

  /// 就地选择高亮卡的上浮。
  static const double highlightLift = 14;

  /// 手牌数量。
  final int count;

  /// 排布可用的最大宽度（一般为视口宽减去左右边距）。
  final double maxWidth;

  const HandFanLayout({required this.count, required this.maxWidth});

  /// 中心卡下标（偶数张时落在偏左的半张上，与原实现一致）。
  double get centerIndex => (count - 1) / 2;

  /// 卡心间距：自然铺开或按可用宽度压缩（不低于 [minSpacing]）。
  double get spacing {
    if (count <= 1) return baseSpacing;
    final compressed = (maxWidth - cardWidth) / (count - 1);
    return compressed.clamp(minSpacing, baseSpacing).toDouble();
  }

  /// 第 [index] 张卡的卡心相对扇形中心的水平偏移。
  double centerDx(int index) => (index - centerIndex) * spacing;

  /// 凸弧升起高度：中心最高（[arcLift]），向两侧递减至 0。
  double arcLiftAt(int index) {
    final rel = (index - centerIndex).abs();
    final maxAbs = math.max(centerIndex, 1.0);
    final factor = (1.0 - rel / maxAbs).clamp(0.0, 1.0);
    return factor * arcLift;
  }

  /// 放射旋转角：左侧逆时针、右侧顺时针。
  double angleAt(int index) => (index - centerIndex) * rotationStep;

  /// 扇形整体宽度（首张到末张卡心的距离 + 一张卡宽）。
  double get totalWidth => count <= 0 ? 0 : (count - 1) * spacing + cardWidth;

  /// 第 [index] 张卡的卡心（相对扇形锚点的局部坐标）。
  ///
  /// y 轴向上为正：返回的 dy 是「应向负 y 方向移动」的升起量，
  /// 调用方按自身锚点方向换算。
  Offset centerAt(int index) => Offset(centerDx(index), -arcLiftAt(index));
}

class HandBarViewportGeometry {
  const HandBarViewportGeometry({
    required this.centerX,
    required this.maxWidth,
    required this.selfBottomInset,
  });

  final double centerX;
  final double maxWidth;
  final double selfBottomInset;

  factory HandBarViewportGeometry.resolve({
    required Size viewport,
    required Rect safeRect,
    required double hudScale,
  }) {
    final scale = hudScale.isFinite && hudScale > 0 ? hudScale : 1.0;
    return HandBarViewportGeometry(
      centerX: safeRect.center.dx / scale,
      maxWidth: math.max(1, safeRect.width / scale - 16),
      selfBottomInset: math.max(0, viewport.height - safeRect.bottom) / scale,
    );
  }
}
