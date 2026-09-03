import 'dart:math' as math;

import 'package:duel_room1/field/util/ui_scale.dart';
import 'package:flutter/widgets.dart';

enum DuelRoomSizeClass { compact, regular, wide }

@immutable
class DuelRoomLayoutSpec {
  const DuelRoomLayoutSpec._({
    required this.viewport,
    required this.safePadding,
    required this.safeRect,
    required this.sizeClass,
    required this.hudScale,
    required this.pagePadding,
    required this.dialogMaxSize,
    required this.dockedPanelWidth,
    required this.gridColumns,
  });

  final Size viewport;
  final EdgeInsets safePadding;
  final Rect safeRect;
  final DuelRoomSizeClass sizeClass;
  final double hudScale;
  final double pagePadding;
  final Size dialogMaxSize;
  final double dockedPanelWidth;
  final int gridColumns;

  bool get isCompact => sizeClass == DuelRoomSizeClass.compact;
  double get minimumTapExtent => 44;
  double get topHudHeight => 52 * hudScale;
  double get handBarHeight => 96 * hudScale;
  double get panelGap => isCompact ? 8 : 18;

  factory DuelRoomLayoutSpec.resolve(
    Size rawViewport, {
    EdgeInsets safePadding = EdgeInsets.zero,
  }) {
    final hasValidRawHeight =
        rawViewport.height.isFinite && rawViewport.height > 0;
    final viewport = Size(
      _validDimension(rawViewport.width),
      _validDimension(rawViewport.height),
    );
    final left = _clampInset(safePadding.left, viewport.width);
    final top = _clampInset(safePadding.top, viewport.height);
    final right = _clampInset(safePadding.right, viewport.width - left);
    final bottom = _clampInset(safePadding.bottom, viewport.height - top);
    final resolvedPadding = EdgeInsets.fromLTRB(left, top, right, bottom);
    final safeWidth = viewport.width - resolvedPadding.horizontal;
    final safeHeight = viewport.height - resolvedPadding.vertical;
    final sizeClass = safeWidth < 1024 || safeHeight < 600
        ? DuelRoomSizeClass.compact
        : safeWidth >= 1600 && safeHeight >= 900
        ? DuelRoomSizeClass.wide
        : DuelRoomSizeClass.regular;
    final pagePadding = sizeClass == DuelRoomSizeClass.compact ? 8.0 : 18.0;
    final contentWidth = math.max(0.0, safeWidth - pagePadding * 2);
    final contentHeight = math.max(0.0, safeHeight - pagePadding * 2);
    final compactPanelWidth = (safeWidth * 0.35).clamp(220.0, 300.0);

    return DuelRoomLayoutSpec._(
      viewport: viewport,
      safePadding: resolvedPadding,
      safeRect: Rect.fromLTWH(left, top, safeWidth, safeHeight),
      sizeClass: sizeClass,
      hudScale: hasValidRawHeight ? hudScaleForAvailableHeight(safeHeight) : 1,
      pagePadding: pagePadding,
      dialogMaxSize: Size(math.min(860, contentWidth), contentHeight),
      dockedPanelWidth: math.min(
        sizeClass == DuelRoomSizeClass.compact ? compactPanelWidth : 440,
        contentWidth,
      ),
      gridColumns: safeWidth < 720
          ? 2
          : safeWidth < 1024
          ? 3
          : 4,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DuelRoomLayoutSpec &&
          viewport == other.viewport &&
          safePadding == other.safePadding &&
          safeRect == other.safeRect &&
          sizeClass == other.sizeClass &&
          hudScale == other.hudScale &&
          pagePadding == other.pagePadding &&
          dialogMaxSize == other.dialogMaxSize &&
          dockedPanelWidth == other.dockedPanelWidth &&
          gridColumns == other.gridColumns;

  @override
  int get hashCode => Object.hash(
    viewport,
    safePadding,
    safeRect,
    sizeClass,
    hudScale,
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
      maybeOf(context) ??
      DuelRoomLayoutSpec.resolve(
        MediaQuery.sizeOf(context),
        safePadding: MediaQuery.viewPaddingOf(context),
      );

  static DuelRoomLayoutSpec? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DuelRoomLayout>()?.spec;

  @override
  bool updateShouldNotify(DuelRoomLayout oldWidget) => oldWidget.spec != spec;
}

double _validDimension(double value) => value.isFinite && value > 0 ? value : 1;

double _clampInset(double value, double maximum) =>
    value.isFinite ? value.clamp(0.0, maximum) : 0;
