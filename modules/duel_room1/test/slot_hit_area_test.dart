import 'package:duel_room1/field/util/duel_field_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('卡槽触控热区', () {
    test('热区不小于视觉槽位（触控目标 ≥ 视觉）', () {
      expect(DuelFieldLayout.slotHitWidth, greaterThanOrEqualTo(DuelFieldLayout.slotWidth));
      expect(DuelFieldLayout.slotHitHeight, greaterThanOrEqualTo(DuelFieldLayout.slotHeight));
    });

    test('横向热区不与相邻列重叠（列距 84）', () {
      final colSpacing = DuelFieldLayout.colX[1] - DuelFieldLayout.colX[0];
      expect(DuelFieldLayout.slotHitWidth, lessThanOrEqualTo(colSpacing));
    });

    test('纵向热区不与相邻行重叠（行距 100，EMZ 半高 48）', () {
      // 怪兽行 y=100 / 魔陷行 y=200 / EMZ 行 y=0（上下各 48 半高）：
      // 热区高 100 时相邻行相切不重叠，EMZ 底沿 50 与怪兽行顶沿 50 相切。
      expect(DuelFieldLayout.slotHitHeight, lessThanOrEqualTo(100.0));
      expect(
        DuelFieldLayout.monsterY - DuelFieldLayout.slotHitHeight / 2,
        greaterThanOrEqualTo(0 + 48.0),
      );
    });
  });
}
