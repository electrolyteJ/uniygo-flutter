/// 阶段轨道布局的纯几何测试。
library;

import 'package:duel_room1/field/util/duel_field_layout.dart';
import 'package:duel_room1/field/components/phase_rail/phase_rail_layout.dart';
import 'package:duel_room1/field/components/player_status/player_status_layout.dart';
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

    test('阶段菜单按钮挂在 EP 胶囊下方且不越界', () {
      // 按钮在末位胶囊之下、互不重叠。
      final lastPillBottom =
          PhaseRailLayout.pillCenterY(PhaseRailLayout.phases.length - 1) +
          PhaseRailLayout.pillHeight / 2;
      final buttonTop =
          PhaseRailLayout.actionButtonCenterY -
          PhaseRailLayout.actionButtonHeight / 2;
      expect(buttonTop, greaterThan(lastPillBottom));
      // 含按钮总高 = 胶囊区 + 间距 + 按钮。
      expect(
        PhaseRailLayout.heightWithButton,
        closeTo(
          PhaseRailLayout.height +
              PhaseRailLayout.actionButtonGap +
              PhaseRailLayout.actionButtonHeight,
          1e-9,
        ),
      );
      // 组件中心净偏移 =（底部按钮块 − 顶部徽章块 − 顶部投降块）/ 2：
      // 上方 60、下方 30 → 净上移 15，胶囊区保持居中棋盘中线。
      expect(
        PhaseRailLayout.actionButtonShift,
        closeTo(
          ((PhaseRailLayout.actionButtonGap +
                      PhaseRailLayout.actionButtonHeight) -
                  (PhaseRailLayout.turnBadgeGap +
                      PhaseRailLayout.turnBadgeHeight +
                      PhaseRailLayout.surrenderButtonGap +
                      PhaseRailLayout.surrenderButtonHeight)) /
              2,
          1e-9,
        ),
      );
      // 按钮不超出相机内容高度（510 的一半）。
      expect(
        PhaseRailLayout.actionButtonCenterY +
            PhaseRailLayout.actionButtonHeight / 2,
        lessThan(255),
      );
    });

    test('回合徽章挂在 DP 胶囊上方且不越界', () {
      // 徽章在首位胶囊之上、互不重叠。
      final firstPillTop =
          PhaseRailLayout.pillCenterY(0) - PhaseRailLayout.pillHeight / 2;
      final badgeBottom =
          PhaseRailLayout.turnBadgeCenterY + PhaseRailLayout.turnBadgeHeight / 2;
      expect(badgeBottom, lessThan(firstPillTop));
      // 含徽章总高 = 徽章 + 间距 + 胶囊区与按钮。
      expect(
        PhaseRailLayout.heightWithBadgeAndButton,
        closeTo(
          PhaseRailLayout.turnBadgeHeight +
              PhaseRailLayout.turnBadgeGap +
              PhaseRailLayout.heightWithButton,
          1e-9,
        ),
      );
      // 徽章上沿不超出相机内容高度（510 的一半）。
      expect(-PhaseRailLayout.turnBadgeTop, lessThan(255));
    });

    test('投降按钮挂在回合徽章上方（轨道最顶端）且不越界', () {
      // 投降按钮在徽章之上、互不重叠。
      final surrenderBottom =
          PhaseRailLayout.surrenderButtonCenterY +
          PhaseRailLayout.surrenderButtonHeight / 2;
      expect(surrenderBottom, lessThan(PhaseRailLayout.turnBadgeTop));
      // 含投降按钮总高 = 投降块 + 徽章块 + 胶囊区与按钮。
      expect(
        PhaseRailLayout.heightWithSurrenderBadgeAndButton,
        closeTo(
          PhaseRailLayout.surrenderButtonHeight +
              PhaseRailLayout.surrenderButtonGap +
              PhaseRailLayout.heightWithBadgeAndButton,
          1e-9,
        ),
      );
      // 投降按钮上沿即轨道内容顶沿：-总高/2 + 组件净偏移
      // （-240/2 + (-15) = -135）。
      expect(
        PhaseRailLayout.surrenderButtonTop,
        closeTo(
          -PhaseRailLayout.heightWithSurrenderBadgeAndButton / 2 +
              PhaseRailLayout.actionButtonShift,
          1e-9,
        ),
      );
      // 投降按钮不超出相机内容高度（510 的一半）。
      expect(-PhaseRailLayout.surrenderButtonTop, lessThan(255));
    });

    test('内容宽度同时覆盖右侧轨道与左侧状态卡', () {
      // 左右附件都在相机内容半宽内（左侧状态卡左缘比轨道右沿更远）。
      expect(
        PhaseRailLayout.contentHalfExtent,
        greaterThanOrEqualTo(PhaseRailLayout.rightEdge),
      );
      expect(
        PhaseRailLayout.contentHalfExtent,
        greaterThanOrEqualTo(-PlayerStatusLayout.leftEdge),
      );
      expect(
        PhaseRailLayout.boardContentWidth,
        closeTo(2 * (PhaseRailLayout.contentHalfExtent + 8), 1e-9),
      );
    });
  });
}
