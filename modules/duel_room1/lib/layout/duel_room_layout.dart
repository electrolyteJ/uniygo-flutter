import 'package:flutter/widgets.dart';

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
  });

  final Size viewport;
  final EdgeInsets safePadding;
  final Rect safeRect;
  final double pagePadding;
  final Size dialogMaxSize;
  final double dockedPanelWidth;
  final int gridColumns;

  double get minimumTapExtent => 44;
  double get topHudHeight => 52;
  double get handBarHeight => 96;
  double get panelGap => 18;

  /// 全局 FittedBox 固定设计分辨率（1280×800，无设备安全区）下的唯一布局规格。
  ///
  /// 应用已改用 [_ScaledApp] 等比缩放：整棵 widget 树按 [kAppDesignSize]
  /// 布局，MediaQuery 也被覆盖为设计分辨率，因此不再需要按视口/断点分支，
  /// 所有页面共用这一份固定几何。
  static const DuelRoomLayoutSpec fixed = DuelRoomLayoutSpec._(
    viewport: Size(1280, 800),
    safePadding: EdgeInsets.zero,
    safeRect: Rect.fromLTWH(0, 0, 1280, 800),
    pagePadding: 18,
    dialogMaxSize: Size(860, 764),
    dockedPanelWidth: 440,
    gridColumns: 4,
  );

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
          gridColumns == other.gridColumns;

  @override
  int get hashCode => Object.hash(
    viewport,
    safePadding,
    safeRect,
    pagePadding,
    dialogMaxSize,
    dockedPanelWidth,
    gridColumns,
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
