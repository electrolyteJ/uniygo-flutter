import 'package:duel_room3/scene3d/field_3d_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Field3DLayout.buildSlots', () {
    test('生成 32 个卡槽', () {
      expect(Field3DLayout.buildSlots(0), hasLength(32));
      expect(Field3DLayout.buildSlots(1), hasLength(32));
    });

    test('己方/对方槽位 key 按 myController 镜像', () {
      final slots = Field3DLayout.buildSlots(0);
      final selfM1 = slots.firstWhere((s) => s.label == 'self_m_0');
      expect(selfM1.slotKeys, ['0_4_0']);
      final oppM1 = slots.firstWhere((s) => s.label == 'opp_m_0');
      expect(oppM1.slotKeys, ['1_4_0']);
      // myController=1 时交换
      final swapped = Field3DLayout.buildSlots(1);
      expect(swapped.firstWhere((s) => s.label == 'self_m_0').slotKeys,
          ['1_4_0']);
    });

    test('EMZ 槽位携带双方 key，序列镜像（与 duel_room1 语义一致）', () {
      final slots = Field3DLayout.buildSlots(0);
      final emz1 = slots.firstWhere((s) => s.label == 'emz_1');
      expect(emz1.slotKeys, ['0_4_5', '1_4_6']);
      final emz2 = slots.firstWhere((s) => s.label == 'emz_2');
      expect(emz2.slotKeys, ['0_4_6', '1_4_5']);
    });

    test('行位置：己方在 +Z，对方在 -Z，EMZ 在 0', () {
      final slots = Field3DLayout.buildSlots(0);
      expect(slots.firstWhere((s) => s.label == 'self_m_0').center.z,
          closeTo(Field3DLayout.monsterRowZ, 1e-5));
      expect(slots.firstWhere((s) => s.label == 'opp_m_0').center.z,
          closeTo(-Field3DLayout.monsterRowZ, 1e-5));
      expect(slots.firstWhere((s) => s.label == 'emz_1').center.z, 0);
      expect(slots.firstWhere((s) => s.label == 'self_st_0').center.z,
          closeTo(Field3DLayout.spellTrapRowZ, 1e-5));
      expect(slots.firstWhere((s) => s.label == 'opp_st_0').center.z,
          closeTo(-Field3DLayout.spellTrapRowZ, 1e-5));
    });

    test('所有槽位 x/z 不重叠', () {
      final slots = Field3DLayout.buildSlots(0);
      final seen = <String>{};
      for (final s in slots) {
        final k = '${s.center.x.toStringAsFixed(3)}_${s.center.z}';
        expect(seen.add(k), isTrue, reason: '槽位 ${s.label} 坐标重叠');
      }
    });
  });

  group('立牌姿态', () {
    test('攻击表示不横置，守备表示横置 90°', () {
      expect(Field3DLayout.standeeRoll(posFaceupAttack), 0.0);
      expect(Field3DLayout.standeeRoll(posFacedownAttack), 0.0);
      expect(Field3DLayout.standeeRoll(posFaceupDefense), closeTo(-1.5708, 1e-3));
      expect(Field3DLayout.standeeRoll(posFacedownDefense), closeTo(-1.5708, 1e-3));
    });

    test('里侧判定', () {
      expect(Field3DLayout.isFacedown(posFaceupAttack), isFalse);
      expect(Field3DLayout.isFacedown(posFaceupDefense), isFalse);
      expect(Field3DLayout.isFacedown(posFacedownAttack), isTrue);
      expect(Field3DLayout.isFacedown(posFacedownDefense), isTrue);
    });
  });
}
