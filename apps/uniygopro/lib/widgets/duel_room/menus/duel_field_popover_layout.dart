import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../models/FieldCard.dart';
import 'hand_action_popover.dart';

/// popover 最大预估高度，用于把 bottom 锚定的 popover 限制在屏幕内。
const double popoverEstimatedMaxHeight = 240.0;

/// 一个 popover 的完整放置结果：左边距、底部间距与可选的箭头对齐位置。
class PopoverPlacement {
  const PopoverPlacement({
    required this.left,
    required this.bottom,
    this.arrowDx,
  });

  final double left;
  final double bottom;

  /// 锚点在 popover 坐标系内的 x 位置（用于对齐底部箭头）。
  final double? arrowDx;
}

double clampPopoverLeft(
  Size viewport,
  double desiredLeft, {
  double menuWidth = 220,
  double margin = 16,
}) {
  final maxLeft = math.max(0.0, viewport.width - menuWidth - margin);
  return desiredLeft.clamp(0.0, maxLeft).toDouble();
}

/// popover 统一以"底边对齐锚点上方"的方式放置，
/// 高度随动作数量变化时不会遮挡锚点或与锚点脱节。
PopoverPlacement placePopoverAbove(
  Size viewport, {
  required double anchorCenterX,
  required double anchorTopY,
  double horizontalOffset = 110,
  bool showArrow = true,
}) {
  final left = clampPopoverLeft(viewport, anchorCenterX - horizontalOffset);
  final arrowDx = showArrow
      ? (anchorCenterX - left)
            .clamp(16.0, HandActionPopover.menuWidth - 16)
            .toDouble()
      : null;
  final desiredBottom = viewport.height - anchorTopY;
  final maxBottom = math.max(0.0, viewport.height - popoverEstimatedMaxHeight);
  return PopoverPlacement(
    left: left,
    bottom: desiredBottom.clamp(0.0, maxBottom).toDouble(),
    arrowDx: arrowDx,
  );
}

/// 手牌 popover 的锚点：x 对准选中卡中心，y 为手牌栏上沿。
Offset handPopoverAnchor(
  Size size,
  int handCount,
  int sequence,
  Rect? measuredCardRect,
) {
  // 优先使用手牌栏上报的实际渲染矩形（含滚动偏移与上浮变换），
  // 手牌溢出滚动或窄窗口时也能对准选中卡。
  final measured = measuredCardRect;
  if (measured != null) {
    return Offset(measured.center.dx, size.height - 96 + measured.top - 8);
  }
  const cardWidth = 64.0;
  const step = 72.0;
  const bottomRailHeight = 96.0;
  final totalWidth = handCount <= 1
      ? cardWidth
      : cardWidth + ((handCount - 1) * step);
  final left = (size.width - totalWidth) / 2;
  return Offset(
    left + (sequence * step) + (cardWidth / 2),
    size.height - bottomRailHeight - 8,
  );
}

String fieldSlotId(FieldCard fieldCard) {
  return '${fieldCard.controller}_${fieldCard.zone}_${fieldCard.sequence}';
}

/// 渲染器 anchors 缺失时的场地卡回退锚点（按经验比例估算）。
Offset fieldCardAnchor(Size size, FieldCard fieldCard, int myController) {
  final boardCenterX = size.width * 0.56;
  final boardWidth = math.min(size.width * 0.66, 940.0);
  final startX = boardCenterX - (boardWidth / 2);
  final stepX = boardWidth / 6;

  int displayColumn;
  if (fieldCard.zone == 4 && fieldCard.sequence >= 5) {
    displayColumn = fieldCard.sequence == 5 ? 2 : 4;
  } else {
    final rawColumn = fieldCard.sequence + 1;
    displayColumn = fieldCard.controller == myController
        ? rawColumn
        : 6 - rawColumn;
  }

  final normalizedY = switch ((fieldCard.zone, fieldCard.sequence)) {
    (4, 5) || (4, 6) => 0.50,
    (4, _) when fieldCard.controller == myController => 0.58,
    (4, _) => 0.38,
    (8, _) when fieldCard.controller == myController => 0.73,
    (8, _) => 0.24,
    _ => 0.5,
  };

  return Offset(startX + (displayColumn * stepX), size.height * normalizedY);
}
