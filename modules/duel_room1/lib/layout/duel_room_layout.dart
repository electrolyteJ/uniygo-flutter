import 'package:flutter/widgets.dart';

/// 决斗房间布局档位。
///
/// 判定优先级从上到下，边界值归入尺寸更大的档位：
/// - [compact]：可用宽 `< 1024` 或可用高 `< 600`；
/// - [regular]：不属于 [compact]，且宽 `< 1600` 或高 `< 900`；
/// - [wide]：宽 `>= 1600` 且高 `>= 900`。
enum DuelRoomLayoutTier { compact, regular, wide }

@immutable
class DuelRoomLayoutSpec {
  const DuelRoomLayoutSpec._({
    required this.viewport,
    required this.safePadding,
    required this.safeRect,
    required this.pagePadding,
    required this.dialogMaxSize,
    required this.dockedPanelWidth,
    required this.gridColumns,
    this.tier = DuelRoomLayoutTier.regular,
    this.topHudHeightValue = 52,
    this.handBarHeightValue = 96,
    this.panelGapValue = 18,
    this.dialogMaxHeightRatio = 0.955,
  });

  final Size viewport;
  final EdgeInsets safePadding;
  final Rect safeRect;
  final double pagePadding;
  final Size dialogMaxSize;
  final double dockedPanelWidth;
  final int gridColumns;
  final DuelRoomLayoutTier tier;

  final double topHudHeightValue;
  final double handBarHeightValue;
  final double panelGapValue;

  /// 对话框高度占可用高度的比例。
  final double dialogMaxHeightRatio;

  double get minimumTapExtent => 44;
  double get topHudHeight => topHudHeightValue;
  double get handBarHeight => handBarHeightValue;
  double get panelGap => panelGapValue;

  /// 固定设计分辨率（1280×800，无设备安全区）下的基准布局规格。
  ///
  /// 保留给不需要真实自适应的调试页与单元测试；实际页面应使用
  /// [resolve] 按真实视口推导。
  static const DuelRoomLayoutSpec fixed = DuelRoomLayoutSpec._(
    viewport: Size(1280, 800),
    safePadding: EdgeInsets.zero,
    safeRect: Rect.fromLTWH(0, 0, 1280, 800),
    pagePadding: 18,
    dialogMaxSize: Size(860, 764),
    dockedPanelWidth: 440,
    gridColumns: 4,
  );

  /// 由真实视口与安全区推导规格。
  ///
  /// [size] 非法（零或负）时返回 [fixed]，保证不产生负约束。
  static DuelRoomLayoutSpec resolve(Size size, EdgeInsets safePadding) {
    if (size.width <= 0 || size.height <= 0) return fixed;

    final tier = resolveTier(size, safePadding);
    final safeRect = Rect.fromLTWH(
      safePadding.left,
      safePadding.top,
      (size.width - safePadding.horizontal).clamp(0.0, double.infinity),
      (size.height - safePadding.vertical).clamp(0.0, double.infinity),
    );

    return switch (tier) {
      DuelRoomLayoutTier.compact => DuelRoomLayoutSpec._(
        viewport: size,
        safePadding: safePadding,
        safeRect: safeRect,
        tier: tier,
        pagePadding: 12,
        dialogMaxSize: Size(safeRect.width * 0.94, safeRect.height * 0.92),
        dockedPanelWidth: (safeRect.width * 0.42).clamp(280.0, 360.0),
        gridColumns: 2,
        topHudHeightValue: 44,
        handBarHeightValue: 72,
        panelGapValue: 12,
        dialogMaxHeightRatio: 0.92,
      ),
      DuelRoomLayoutTier.regular => DuelRoomLayoutSpec._(
        viewport: size,
        safePadding: safePadding,
        safeRect: safeRect,
        tier: tier,
        pagePadding: 18,
        dialogMaxSize: Size(
          (safeRect.width * 0.94).clamp(0.0, 860),
          (safeRect.height * 0.94).clamp(0.0, 764),
        ),
        dockedPanelWidth: 440,
        gridColumns: 4,
        topHudHeightValue: 52,
        handBarHeightValue: 96,
        panelGapValue: 18,
        dialogMaxHeightRatio: 0.94,
      ),
      DuelRoomLayoutTier.wide => DuelRoomLayoutSpec._(
        viewport: size,
        safePadding: safePadding,
        safeRect: safeRect,
        tier: tier,
        pagePadding: 24,
        dialogMaxSize: Size(
          (safeRect.width * 0.94).clamp(0.0, 900),
          (safeRect.height * 0.94).clamp(0.0, 860),
        ),
        dockedPanelWidth: 520,
        gridColumns: 5,
        topHudHeightValue: 56,
        handBarHeightValue: 108,
        panelGapValue: 22,
        dialogMaxHeightRatio: 0.94,
      ),
    };
  }

  /// 仅推导档位（供测试与纯逻辑复用）。
  static DuelRoomLayoutTier resolveTier(Size size, EdgeInsets safePadding) {
    final w = size.width - safePadding.horizontal;
    final h = size.height - safePadding.vertical;
    if (w < 1024 || h < 600) return DuelRoomLayoutTier.compact;
    if (w < 1600 || h < 900) return DuelRoomLayoutTier.regular;
    return DuelRoomLayoutTier.wide;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DuelRoomLayoutSpec &&
          viewport == other.viewport &&
          safePadding == other.safePadding &&
          safeRect == other.safeRect &&
          pagePadding == other.pagePadding &&
          dialogMaxSize == other.dialogMaxSize &&
          dockedPanelWidth == other.dockedPanelWidth &&
          gridColumns == other.gridColumns &&
          tier == other.tier &&
          topHudHeightValue == other.topHudHeightValue &&
          handBarHeightValue == other.handBarHeightValue &&
          panelGapValue == other.panelGapValue &&
          dialogMaxHeightRatio == other.dialogMaxHeightRatio;

  @override
  int get hashCode => Object.hash(
    viewport,
    safePadding,
    safeRect,
    pagePadding,
    dialogMaxSize,
    dockedPanelWidth,
    gridColumns,
    tier,
    topHudHeightValue,
    handBarHeightValue,
    panelGapValue,
    dialogMaxHeightRatio,
  );
}

class DuelRoomLayout extends InheritedWidget {
  const DuelRoomLayout({super.key, required this.spec, required super.child});

  final DuelRoomLayoutSpec spec;

  static DuelRoomLayoutSpec of(BuildContext context) =>
      maybeOf(context) ?? DuelRoomLayoutSpec.fixed;

  static DuelRoomLayoutSpec? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DuelRoomLayout>()?.spec;

  @override
  bool updateShouldNotify(DuelRoomLayout oldWidget) => oldWidget.spec != spec;
}
