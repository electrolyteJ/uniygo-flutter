/// 卡片移动（CardMoveEvent）端点的几何换算：纯函数，可单测。
///
/// 端点（controller/location/sequence）→ 棋盘板面坐标（与
/// DuelFieldWorld.boardPositionForZoneKey 同一几何；墓地/除外/额外/卡组
/// 等堆叠区域落到对应槽位中心）。手牌端点返回 null——手牌矩形由
/// HandBarComponent.cardSlotRect 直接给出（屏幕空间）。
library;

import 'dart:ui' show Offset;

import 'package:duelink/duelink.dart';

import 'duel_field_layout.dart';

/// 移动端点的矩形来源分类（CardMoveAnimator 的分发决策）。
enum MoveEndpointSource {
  /// 手牌栏卡位矩形（HandBarComponent.cardSlotRect）。
  handBar,

  /// 卡组槽位矩形（DuelFlameGame.deckSlotWidgetRect）。
  deckSlot,

  /// 场上/墓地/除外/额外槽位（棋盘板面坐标 → 屏幕矩形）。
  boardSlot,

  /// 无法换算（未知区域），跳过动画。
  unresolvable,
}

/// 端点 location → 矩形来源分类。
MoveEndpointSource moveEndpointSource(int location) {
  if (location & CARD_ZONE_HAND != 0) return MoveEndpointSource.handBar;
  if (location & CARD_ZONE_DECK != 0) return MoveEndpointSource.deckSlot;
  if (location &
          (CARD_ZONE_MZONE |
              CARD_ZONE_SZONE |
              CARD_ZONE_GRAVE |
              CARD_ZONE_REMOVED |
              CARD_ZONE_EXTRA) !=
      0) {
  return MoveEndpointSource.boardSlot;
  }
  return MoveEndpointSource.unresolvable;
}

/// 端点 → 棋盘板面坐标；手牌返回 null（走 handBar 分支）。
///
/// 怪兽/魔陷区（含 EMZ 镜像）与 DuelFieldWorld.boardPositionForZoneKey
/// 的换算逐一对应；堆叠区域对齐 zone_slot_spec 的槽位布局：
/// 墓地=怪兽行最外列、除外=EMZ 行最外列、额外=魔陷行最外列、
/// 卡组=[DuelFieldLayout.deckSlotPos]。
Offset? boardPosForCardLocation({
  required int controller,
  required int location,
  required int sequence,
  required int myController,
}) {
  final isSelf = controller == myController;
  const colX = DuelFieldLayout.colX;

  if (location & CARD_ZONE_DECK != 0) {
    return DuelFieldLayout.deckSlotPos(isSelf: isSelf);
  }
  if (location & CARD_ZONE_EXTRA != 0) {
    return DuelFieldLayout.extraSlotPos(isSelf: isSelf);
  }
  if (location & CARD_ZONE_GRAVE != 0) {
    return Offset(
      isSelf ? colX[6] : colX[0],
      isSelf ? DuelFieldLayout.monsterY : -DuelFieldLayout.monsterY,
    );
  }
  if (location & CARD_ZONE_REMOVED != 0) {
    return Offset(isSelf ? colX[6] : colX[0], 0);
  }
  if (location & CARD_ZONE_MZONE != 0) {
    // EMZ 物理槽位双方镜像：己方 s5/对方 s6 在屏幕左，己方 s6/对方 s5 在右。
    if (sequence == 5) return Offset(isSelf ? -84 : 84, 0);
    if (sequence == 6) return Offset(isSelf ? 84 : -84, 0);
    if (sequence < 0 || sequence > 4) return null;
    return Offset(
      colX[1 + (isSelf ? sequence : 4 - sequence)],
      isSelf ? DuelFieldLayout.monsterY : -DuelFieldLayout.monsterY,
    );
  }
  if (location & CARD_ZONE_SZONE != 0) {
    // 场地魔法位（seq 5）与怪兽行同高、最外列。
    if (sequence == 5) {
      return Offset(
        isSelf ? colX[0] : colX[6],
        isSelf ? DuelFieldLayout.monsterY : -DuelFieldLayout.monsterY,
      );
    }
    if (sequence < 0 || sequence > 4) return null;
    return Offset(
      colX[1 + (isSelf ? sequence : 4 - sequence)],
      isSelf ? DuelFieldLayout.stY : -DuelFieldLayout.stY,
    );
  }
  return null;
}
