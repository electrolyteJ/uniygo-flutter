/// DuelRoomLayoutSpec.resolve 的纯函数契约。
///
/// 与 `modules/duel_room1/test/duel_room_layout_test.dart` 互补：那份只管
/// `fixed` 常量与 InheritedWidget 行为，这份管真实视口推导的边界与不变量
/// （`dockedPanelWidth <= viewport.width`、`dialogMaxSize` 非负等）。
library;

import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试矩阵用的四档屏幕尺寸（与 Widget 尺寸矩阵一致）。
const _matrixSizes = <Size>[
  Size(640, 360),
  Size(800, 450),
  Size(1280, 720),
  Size(1920, 1080),
];

DuelRoomLayoutTier _tier(
  double w,
  double h, [
  EdgeInsets padding = EdgeInsets.zero,
]) =>
    DuelRoomLayoutSpec.resolveTier(Size(w, h), padding);

void main() {
  group('resolveTier 边界（与 AppLayout 同档位规则）', () {
    test('1023/1024 与 599/600', () {
      expect(_tier(1023, 900), DuelRoomLayoutTier.compact);
      expect(_tier(1024, 900), DuelRoomLayoutTier.regular);
      expect(_tier(2000, 599), DuelRoomLayoutTier.compact);
      expect(_tier(2000, 600), DuelRoomLayoutTier.regular);
    });

    test('1599/1600 与 899/900', () {
      expect(_tier(1599, 1000), DuelRoomLayoutTier.regular);
      expect(_tier(1600, 1000), DuelRoomLayoutTier.wide);
      expect(_tier(2000, 899), DuelRoomLayoutTier.regular);
      expect(_tier(2000, 900), DuelRoomLayoutTier.wide);
    });
  });

  group('resolve 非法尺寸兜底', () {
    test('零/负尺寸返回 fixed，不产生负约束', () {
      expect(DuelRoomLayoutSpec.resolve(Size.zero, EdgeInsets.zero),
          DuelRoomLayoutSpec.fixed);
      expect(DuelRoomLayoutSpec.resolve(const Size(-1, 100), EdgeInsets.zero),
          DuelRoomLayoutSpec.fixed);
      expect(DuelRoomLayoutSpec.resolve(const Size(100, -1), EdgeInsets.zero),
          DuelRoomLayoutSpec.fixed);
    });
  });

  group('测试矩阵四尺寸的派生量与不变量', () {
    test('档位符合预期', () {
      final tiers = {
        for (final size in _matrixSizes)
          size: DuelRoomLayoutSpec.resolve(size, EdgeInsets.zero).tier,
      };
      expect(tiers[const Size(640, 360)], DuelRoomLayoutTier.compact);
      expect(tiers[const Size(800, 450)], DuelRoomLayoutTier.compact);
      expect(tiers[const Size(1280, 720)], DuelRoomLayoutTier.regular);
      expect(tiers[const Size(1920, 1080)], DuelRoomLayoutTier.wide);
    });

    test('dockedPanelWidth 不超过视口宽，也不超过安全区宽', () {
      for (final size in _matrixSizes) {
        for (final padding in [
          EdgeInsets.zero,
          const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 12),
        ]) {
          final spec = DuelRoomLayoutSpec.resolve(size, padding);
          expect(
            spec.dockedPanelWidth <= spec.viewport.width,
            isTrue,
            reason: 'dockedPanelWidth=${spec.dockedPanelWidth} 超过视口 '
                '${spec.viewport.width}（$size / $padding）',
          );
          expect(
            spec.dockedPanelWidth <= spec.safeRect.width,
            isTrue,
            reason: 'dockedPanelWidth=${spec.dockedPanelWidth} 超过安全区宽 '
                '${spec.safeRect.width}（$size / $padding）',
          );
        }
      }
    });

    test('dialogMaxSize 非负且不超过安全区', () {
      for (final size in _matrixSizes) {
        final spec = DuelRoomLayoutSpec.resolve(
          size,
          const EdgeInsets.only(left: 30, right: 30, top: 20, bottom: 20),
        );
        expect(spec.dialogMaxSize.width, greaterThan(0));
        expect(spec.dialogMaxSize.height, greaterThan(0));
        expect(spec.dialogMaxSize.width, lessThanOrEqualTo(spec.safeRect.width));
        expect(spec.dialogMaxSize.height, lessThanOrEqualTo(spec.safeRect.height));
      }
    });

    test('safeRect = 视口减安全区，且不为负', () {
      final spec = DuelRoomLayoutSpec.resolve(
        const Size(640, 360),
        const EdgeInsets.only(left: 40, right: 40, top: 24, bottom: 24),
      );
      expect(spec.safeRect.left, 40);
      expect(spec.safeRect.top, 24);
      expect(spec.safeRect.width, 560);
      expect(spec.safeRect.height, 312);

      // 安全区大于视口时钳到 0，不出现负宽高。
      final degenerate = DuelRoomLayoutSpec.resolve(
        const Size(300, 200),
        const EdgeInsets.all(500),
      );
      expect(degenerate.safeRect.width, 0);
      expect(degenerate.safeRect.height, 0);
      expect(degenerate.dialogMaxSize.width, greaterThanOrEqualTo(0));
      expect(degenerate.dialogMaxSize.height, greaterThanOrEqualTo(0));
    });

    test('三档核心派生量（外边距 / 栏数 / HUD / 手牌栏）', () {
      final compact =
          DuelRoomLayoutSpec.resolve(const Size(640, 360), EdgeInsets.zero);
      expect(compact.pagePadding, 12);
      expect(compact.gridColumns, 2);
      expect(compact.topHudHeight, 44);
      expect(compact.handBarHeight, 72);
      expect(compact.panelGap, 12);

      final regular =
          DuelRoomLayoutSpec.resolve(const Size(1280, 720), EdgeInsets.zero);
      expect(regular.pagePadding, 18);
      expect(regular.gridColumns, 4);
      expect(regular.topHudHeight, 52);
      expect(regular.handBarHeight, 96);
      expect(regular.dockedPanelWidth, 440);

      final wide =
          DuelRoomLayoutSpec.resolve(const Size(1920, 1080), EdgeInsets.zero);
      expect(wide.pagePadding, 24);
      expect(wide.gridColumns, 5);
      expect(wide.topHudHeight, 56);
      expect(wide.handBarHeight, 108);
      expect(wide.dockedPanelWidth, 520);
    });

    test('compact 停靠面板宽度夹在 280..360（小屏不塌陷、大屏不挤占）', () {
      for (final width in const [640.0, 800.0, 1023.0]) {
        final spec = DuelRoomLayoutSpec.resolve(
          Size(width, 360),
          EdgeInsets.zero,
        );
        expect(spec.dockedPanelWidth, greaterThanOrEqualTo(280));
        expect(spec.dockedPanelWidth, lessThanOrEqualTo(360));
      }
    });
  });
}
