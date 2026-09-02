import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_portal/flutter_portal.dart';

import 'package:biz/duel/models/field_card.dart';

// 卡槽 key 统一由 biz/duel/models/field_zone_key.dart 的 fieldSlotId 提供，
// 此处不再重复定义（页面 import 也不再需要 hide）。

class SafeAligned implements Anchor {
  const SafeAligned({
    required this.follower,
    required this.target,
    required this.safePadding,
    this.offset = Offset.zero,
  });

  final Alignment follower;
  final Alignment target;
  final EdgeInsets safePadding;
  final Offset offset;

  Aligned get _aligned =>
      Aligned(follower: follower, target: target, offset: offset);

  @override
  BoxConstraints getFollowerConstraints({
    required Size targetSize,
    required BoxConstraints theaterConstraints,
  }) => _aligned.getFollowerConstraints(
    targetSize: targetSize,
    theaterConstraints: theaterConstraints,
  );

  @override
  Offset getFollowerOffset({
    required Size followerSize,
    required Size targetSize,
    required Rect theaterRect,
  }) {
    final desired = _aligned.getFollowerOffset(
      followerSize: followerSize,
      targetSize: targetSize,
      theaterRect: theaterRect,
    );
    final safeRect = Rect.fromLTRB(
      theaterRect.left + safePadding.left,
      theaterRect.top + safePadding.top,
      theaterRect.right - safePadding.right,
      theaterRect.bottom - safePadding.bottom,
    );
    return Offset(
      _softClamp(
        desired.dx,
        safeRect.left,
        safeRect.right - followerSize.width,
      ),
      _softClamp(
        desired.dy,
        safeRect.top,
        safeRect.bottom - followerSize.height,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other.runtimeType == runtimeType &&
        other is SafeAligned &&
        _aligned == other._aligned &&
        safePadding == other.safePadding;
  }

  @override
  int get hashCode => Object.hash(_aligned, safePadding);
}

double _softClamp(double value, double lower, double upper) =>
    lower > upper ? lower : value.clamp(lower, upper).toDouble();

double popoverArrowDx({
  required Rect anchorRect,
  required Rect safeRect,
  required double menuWidth,
}) {
  final width = menuWidth.clamp(0.0, safeRect.width).toDouble();
  final maxLeft = safeRect.right - width;
  final menuLeft = (anchorRect.center.dx - width / 2)
      .clamp(safeRect.left, maxLeft)
      .toDouble();
  return (anchorRect.center.dx - menuLeft).clamp(0.0, width).toDouble();
}

/// 渲染器 anchors 缺失时的场地卡回退锚点（按经验比例估算）。
Offset fieldCardAnchor(
  Size size,
  FieldCard fieldCard,
  int myController, {
  Rect? safeRect,
}) {
  final width = size.width.isFinite && size.width > 0 ? size.width : 1.0;
  final height = size.height.isFinite && size.height > 0 ? size.height : 1.0;
  final viewport = Size(width, height);
  final bounds = safeRect ?? Offset.zero & viewport;
  final sequence = fieldCard.sequence.clamp(0, 7);
  final boardCenterX = viewport.width * 0.56;
  final boardWidth = math.min(viewport.width * 0.66, 940.0);
  final startX = boardCenterX - (boardWidth / 2);
  final stepX = boardWidth / 6;

  final isSelf = fieldCard.controller == myController;
  int displayColumn;
  if (fieldCard.zone == 4 && sequence >= 5) {
    // EMZ 为双方共享的物理槽位：屏幕左 EMZ = 己方 s5 / 对方 s6，
    // 屏幕右 EMZ = 己方 s6 / 对方 s5（见 zone_slot_spec 的 emz 注释）。
    displayColumn = (sequence == 5) == isSelf ? 2 : 4;
  } else if (fieldCard.zone == 8 && sequence == 5) {
    displayColumn = isSelf ? 0 : 6;
  } else if (fieldCard.zone == 8 && sequence >= 6) {
    // 灵摆区（SZONE s6/s7）：落在经验网格最左/最右列，双方镜像
    // （本模块暂未渲染灵摆槽位，此分支为锚点兜底）。
    final selfCol = sequence == 6 ? 0 : 6;
    displayColumn = isSelf ? selfCol : 6 - selfCol;
  } else {
    final rawColumn = sequence + 1;
    displayColumn = isSelf ? rawColumn : 6 - rawColumn;
  }

  final normalizedY = switch ((fieldCard.zone, sequence)) {
    (4, 5) || (4, 6) => 0.50,
    (4, _) when fieldCard.controller == myController => 0.58,
    (4, _) => 0.38,
    (8, 5) when fieldCard.controller == myController => 0.58,
    (8, 5) => 0.38,
    (8, _) when fieldCard.controller == myController => 0.73,
    (8, _) => 0.24,
    _ => 0.5,
  };

  final anchor = Offset(
    startX + (displayColumn * stepX),
    viewport.height * normalizedY,
  );
  return Offset(
    anchor.dx.clamp(bounds.left, bounds.right).toDouble(),
    anchor.dy.clamp(bounds.top, bounds.bottom).toDouble(),
  );
}
