/// 阶段轨道布局的纯几何测试。
library;

import 'package:duel_room1/field/models/duel_field_layout.dart';
import 'package:duel_room1/field/models/phase_rail_layout.dart';
import 'package:duelink/duelink.dart' show DuelPhase;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhaseRailLayout', () {
    test('阶段顺序为 DP→SP→M1→BP→M2→EP，idle 不在轨道上', () {
      expect(PhaseRailLayout.orderIndex(DuelPhase.dp), 0);
      expect(PhaseRailLayout.orderIndex(DuelPhase.sp), 1);
      expect(PhaseRailLayout.orderIndex(DuelPhase.m1), 2);
      expect(PhaseRailLayout.orderIndex(DuelPhase.bp), 3);
      expect(PhaseRailLayout.orderIndex(DuelPhase.m2), 4);
      expect(PhaseRailLayout.orderIndex(DuelPhase.ep), 5);
      expect(PhaseRailLayout.orderIndex(DuelPhase.idle), -1);
    });

    test('短标签与阶段一一对应', () {
      expect(PhaseRailLayout.shortLabels.length, PhaseRailLayout.phases.length);
      expect(PhaseRailLayout.shortLabels, ['DP', 'SP', 'M1', 'BP', 'M2', 'EP']);
    });

    test('胶囊以棋盘中线对称分布且间距均匀', () {
      final ys = List.generate(
        PhaseRailLayout.phases.length,
        PhaseRailLayout.pillCenterY,
      );
      // 对称：首尾关于 y=0 对称
      expect(ys.first, -ys.last);
      expect(ys[1], -ys[4]);
      // 间距均匀 = pillHeight + pillSpacing
      for (var i = 1; i < ys.length; i++) {
        expect(
          ys[i] - ys[i - 1],
          closeTo(
            PhaseRailLayout.pillHeight + PhaseRailLayout.pillSpacing,
            1e-9,
          ),
        );
      }
      // 轨道总高覆盖首尾胶囊
      expect(
        PhaseRailLayout.height,
        closeTo(ys.last - ys.first + PhaseRailLayout.pillHeight, 1e-9),
      );
    });

    test('轨道不与最右卡槽列重叠，且落在相机内容宽度内', () {
      const slotRight =
          DuelFieldLayout.lastColX + DuelFieldLayout.slotWidth / 2;
      expect(
        PhaseRailLayout.centerX - PhaseRailLayout.pillWidth / 2,
        greaterThan(slotRight),
      );
      expect(
        PhaseRailLayout.rightEdge,
        lessThanOrEqualTo(PhaseRailLayout.boardContentWidth / 2),
      );
    });

    test('轨道高度不超棋盘内容高度（510）', () {
      expect(PhaseRailLayout.height, lessThan(510));
    });
  });
}
