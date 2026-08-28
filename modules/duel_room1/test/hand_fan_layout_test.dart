/// 手牌扇形排布纯逻辑测试。
///
/// 锁定从 Flutter 版 HandCardsBar 移植的几何行为：
/// 自然间距铺开、超宽压缩（重叠排布）、凸弧升起、放射旋转。
library;

import 'package:duel_room1/field/util/hand_fan_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HandFanLayout', () {
    test('少量手牌按自然间距铺开', () {
      const layout = HandFanLayout(count: 5, maxWidth: 800);
      expect(layout.spacing, HandFanLayout.baseSpacing);
      // 5 张自然铺开总宽 = 4 * 72 + 64 = 352 < 800。
      expect(layout.totalWidth, 352);
    });

    test('手牌超宽时压缩卡心间距（重叠排布）', () {
      const layout = HandFanLayout(count: 10, maxWidth: 500);
      // (500 - 64) / 9 ≈ 48.4 < 72。
      expect(layout.spacing, closeTo(48.44, 0.01));
      expect(layout.totalWidth, closeTo(500, 0.01));
    });

    test('压缩不低于最小间距（极端情况允许继续超出）', () {
      const layout = HandFanLayout(count: 40, maxWidth: 500);
      expect(layout.spacing, HandFanLayout.minSpacing);
    });

    test('单张/零张不除零', () {
      const single = HandFanLayout(count: 1, maxWidth: 800);
      expect(single.spacing, HandFanLayout.baseSpacing);
      expect(single.centerDx(0), 0);
      const empty = HandFanLayout(count: 0, maxWidth: 800);
      expect(empty.totalWidth, 0);
    });

    test('凸弧中心最高、两侧递减、y 轴向上为负', () {
      const layout = HandFanLayout(count: 5, maxWidth: 800);
      final lifts = [for (var i = 0; i < 5; i++) layout.arcLiftAt(i)];
      expect(lifts[2], HandFanLayout.arcLift);
      expect(lifts[0], 0);
      expect(lifts[4], 0);
      expect(lifts[1], lifts[3]);
      expect(lifts[1], lessThan(lifts[2]));
      expect(layout.centerAt(2).dy, -HandFanLayout.arcLift);
    });

    test('放射旋转左右对称', () {
      const layout = HandFanLayout(count: 5, maxWidth: 800);
      expect(layout.angleAt(0), -layout.angleAt(4));
      expect(layout.angleAt(2), 0);
      expect(layout.angleAt(3), closeTo(0.10, 1e-9));
    });

    test('卡心水平偏移以中心对称', () {
      const layout = HandFanLayout(count: 4, maxWidth: 800);
      expect(layout.centerDx(0), -layout.centerDx(3));
      expect(layout.centerDx(1), -layout.centerDx(2));
    });
  });
}
