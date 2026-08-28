/// CardMoveEvent 几何换算与分发决策测试（card_move_geometry.dart）。
///
/// 覆盖：各区域端点 → 矩形来源分类 / 棋盘板面坐标（与槽位布局一致）/
/// 卡面朝向规则。
library;

import 'package:biz/duel/models/card_move_event.dart';
import 'package:duel_room1/field/components/card_move_geometry.dart';
import 'package:duel_room1/field/util/duel_field_layout.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter_test/flutter_test.dart';

CardMoveEvent event({
  int code = 89631139,
  int fromController = 0,
  int fromLocation = CARD_ZONE_HAND,
  int toController = 0,
  int toLocation = CARD_ZONE_GRAVE,
}) => CardMoveEvent(
  id: 1,
  code: code,
  fromController: fromController,
  fromLocation: fromLocation,
  fromSequence: 0,
  toController: toController,
  toLocation: toLocation,
  toSequence: 0,
);

void main() {
  group('moveEndpointSource 分发', () {
    test('手牌/卡组/板上区域/未知', () {
      expect(moveEndpointSource(CARD_ZONE_HAND), MoveEndpointSource.handBar);
      expect(moveEndpointSource(CARD_ZONE_DECK), MoveEndpointSource.deckSlot);
      for (final z in [
        CARD_ZONE_MZONE,
        CARD_ZONE_SZONE,
        CARD_ZONE_GRAVE,
        CARD_ZONE_REMOVED,
        CARD_ZONE_EXTRA,
      ]) {
        expect(
          moveEndpointSource(z),
          MoveEndpointSource.boardSlot,
          reason: 'zone=$z',
        );
      }
      expect(moveEndpointSource(0x80), MoveEndpointSource.unresolvable);
    });
  });

  group('boardPosForCardLocation（myController=0）', () {
    Offset? pos(int c, int z, int s) => boardPosForCardLocation(
      controller: c,
      location: z,
      sequence: s,
      myController: 0,
    );

    test('卡组/额外与布局常量一致', () {
      expect(pos(0, CARD_ZONE_DECK, 0), DuelFieldLayout.deckSlotPos(isSelf: true));
      expect(pos(1, CARD_ZONE_DECK, 0), DuelFieldLayout.deckSlotPos(isSelf: false));
      expect(pos(0, CARD_ZONE_EXTRA, 0), DuelFieldLayout.extraSlotPos(isSelf: true));
      expect(pos(1, CARD_ZONE_EXTRA, 0), DuelFieldLayout.extraSlotPos(isSelf: false));
    });

    test('墓地/除外：己方右列、对方左列，y 行正确', () {
      expect(pos(0, CARD_ZONE_GRAVE, 0)!.dx, DuelFieldLayout.colX[6]);
      expect(pos(0, CARD_ZONE_GRAVE, 0)!.dy, DuelFieldLayout.monsterY);
      expect(pos(1, CARD_ZONE_GRAVE, 0)!.dx, DuelFieldLayout.colX[0]);
      expect(pos(1, CARD_ZONE_GRAVE, 0)!.dy, -DuelFieldLayout.monsterY);
      expect(pos(0, CARD_ZONE_REMOVED, 0)!.dy, 0);
      expect(pos(1, CARD_ZONE_REMOVED, 0)!.dx, DuelFieldLayout.colX[0]);
    });

    test('怪兽区镜像与 EMZ 双方镜像', () {
      // 己方 M1 在 colX[1] 怪兽行下方，对方 M1 镜像到 colX[5] 上方
      expect(pos(0, CARD_ZONE_MZONE, 0)!.dx, DuelFieldLayout.colX[1]);
      expect(pos(0, CARD_ZONE_MZONE, 0)!.dy, DuelFieldLayout.monsterY);
      expect(pos(1, CARD_ZONE_MZONE, 0)!.dx, DuelFieldLayout.colX[5]);
      expect(pos(1, CARD_ZONE_MZONE, 0)!.dy, -DuelFieldLayout.monsterY);
      // EMZ：己方 s5 与敌方 s6 同在屏幕左（-84），己方 s6/敌方 s5 在右
      expect(pos(0, CARD_ZONE_MZONE, 5)!.dx, -84);
      expect(pos(1, CARD_ZONE_MZONE, 6)!.dx, -84);
      expect(pos(0, CARD_ZONE_MZONE, 6)!.dx, 84);
      expect(pos(1, CARD_ZONE_MZONE, 5)!.dx, 84);
    });

    test('魔陷区与场地魔法位', () {
      expect(pos(0, CARD_ZONE_SZONE, 2)!.dx, DuelFieldLayout.colX[3]);
      expect(pos(0, CARD_ZONE_SZONE, 2)!.dy, DuelFieldLayout.stY);
      // 场地位（seq 5）：最外列、怪兽行同高
      expect(pos(0, CARD_ZONE_SZONE, 5)!.dx, DuelFieldLayout.colX[0]);
      expect(pos(0, CARD_ZONE_SZONE, 5)!.dy, DuelFieldLayout.monsterY);
      expect(pos(1, CARD_ZONE_SZONE, 5)!.dx, DuelFieldLayout.colX[6]);
    });

    test('手牌返回 null（走 handBar 分支）', () {
      expect(pos(0, CARD_ZONE_HAND, 0), isNull);
    });

    test('myController=1 时整体镜像', () {
      final p = boardPosForCardLocation(
        controller: 1,
        location: CARD_ZONE_GRAVE,
        sequence: 0,
        myController: 1,
      );
      expect(p!.dx, DuelFieldLayout.colX[6]); // 视角中「自己」在下方
      expect(p.dy, DuelFieldLayout.monsterY);
    });
  });

  group('cardMoveFaceUp', () {
    test('己方卡移动显示卡面；对方卡/code=0 显示卡背', () {
      expect(cardMoveFaceUp(event(), 0), isTrue);
      expect(cardMoveFaceUp(event(fromController: 1), 0), isFalse);
      expect(cardMoveFaceUp(event(code: 0), 0), isFalse);
    });
  });
}
