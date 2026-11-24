/// AppLayoutSpec 的纯函数契约：档位边界、零尺寸兜底、档位派生量。
///
/// 边界规则（来自 spec）：可用宽 `<1024` 或可用高 `<600` 为 compact；
/// 非 compact 且宽 `<1600` 或高 `<900` 为 regular；否则 wide。
/// 恰好等于阈值的归入更大档位。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/layout/app_layout.dart';

/// 便于阅读的断言：直接比较档位。
AppLayoutTier _tier(double w, double h, [EdgeInsets padding = EdgeInsets.zero]) =>
    AppLayoutSpec.resolveTier(Size(w, h), padding);

void main() {
  group('resolveTier 宽度边界', () {
    test('1023 → compact，1024 → regular（阈值归大档）', () {
      expect(_tier(1023, 900), AppLayoutTier.compact);
      expect(_tier(1024, 900), AppLayoutTier.regular);
    });

    test('1599 → regular，1600 → wide', () {
      expect(_tier(1599, 1000), AppLayoutTier.regular);
      expect(_tier(1600, 1000), AppLayoutTier.wide);
    });
  });

  group('resolveTier 高度边界', () {
    test('599 → compact，600 → regular（宽已足够）', () {
      expect(_tier(2000, 599), AppLayoutTier.compact);
      expect(_tier(2000, 600), AppLayoutTier.regular);
    });

    test('899 → regular，900 → wide（宽已足够）', () {
      expect(_tier(2000, 899), AppLayoutTier.regular);
      expect(_tier(2000, 900), AppLayoutTier.wide);
    });
  });

  group('resolveTier 安全区参与判定', () {
    test('像素宽 1100 但左右安全区吃掉 100 → 可用 1000 归 compact', () {
      expect(_tier(1100, 700), AppLayoutTier.regular);
      expect(
        _tier(1100, 700, const EdgeInsets.only(left: 50, right: 50)),
        AppLayoutTier.compact,
      );
    });

    test('像素高 1000 但上下安全区吃掉 120 → 可用 880 归 regular', () {
      expect(_tier(2000, 1000), AppLayoutTier.wide);
      expect(
        _tier(2000, 1000, const EdgeInsets.only(top: 60, bottom: 60)),
        AppLayoutTier.regular,
      );
    });
  });

  group('resolve 零/负尺寸兜底', () {
    test('零尺寸返回 fallback（1280×800 regular）', () {
      final spec = AppLayoutSpec.resolve(Size.zero, EdgeInsets.zero);
      expect(spec, AppLayoutSpec.fallback);
      expect(spec.tier, AppLayoutTier.regular);
      expect(spec.viewport, const Size(1280, 800));
    });

    test('负尺寸同样返回 fallback，不产生负约束', () {
      expect(
        AppLayoutSpec.resolve(const Size(-10, 100), EdgeInsets.zero),
        AppLayoutSpec.fallback,
      );
      expect(
        AppLayoutSpec.resolve(const Size(100, -1), EdgeInsets.zero),
        AppLayoutSpec.fallback,
      );
    });
  });

  group('resolve 档位派生量', () {
    test('compact：单栏、无 Rail、外边距 12、最大宽=视口宽', () {
      final spec = AppLayoutSpec.resolve(
        const Size(640, 360),
        const EdgeInsets.only(left: 12, right: 12),
      );
      expect(spec.tier, AppLayoutTier.compact);
      expect(spec.contentColumns, 1);
      expect(spec.usesRail, isFalse);
      expect(spec.railWidth, 0);
      expect(spec.pagePadding, 12);
      expect(spec.gutter, 12);
      expect(spec.maxContentWidth, 640);
      expect(spec.bottomTabHeight, 56);
    });

    test('regular：双栏、Rail 88、外边距 20、最大宽 1600', () {
      final spec = AppLayoutSpec.resolve(const Size(1280, 720), EdgeInsets.zero);
      expect(spec.tier, AppLayoutTier.regular);
      expect(spec.contentColumns, 2);
      expect(spec.usesRail, isTrue);
      expect(spec.railWidth, 88);
      expect(spec.pagePadding, 20);
      expect(spec.gutter, 16);
      expect(spec.maxContentWidth, 1600);
    });

    test('wide：三栏、Rail 104、外边距 28', () {
      final spec = AppLayoutSpec.resolve(const Size(1920, 1080), EdgeInsets.zero);
      expect(spec.tier, AppLayoutTier.wide);
      expect(spec.contentColumns, 3);
      expect(spec.railWidth, 104);
      expect(spec.pagePadding, 28);
      expect(spec.gutter, 22);
    });

    test('viewport / safePadding 原样带出（不改写 MediaQuery）', () {
      const padding = EdgeInsets.only(top: 24, bottom: 12, left: 8, right: 8);
      final spec = AppLayoutSpec.resolve(const Size(1920, 1080), padding);
      expect(spec.viewport, const Size(1920, 1080));
      expect(spec.safePadding, padding);
    });

    test('isTouch 可显式覆盖，默认按短边 < 900 判定', () {
      expect(
        AppLayoutSpec.resolve(const Size(1920, 1080), EdgeInsets.zero).isTouch,
        isFalse,
      );
      expect(
        AppLayoutSpec.resolve(const Size(640, 360), EdgeInsets.zero).isTouch,
        isTrue,
      );
      expect(
        AppLayoutSpec.resolve(
          const Size(1920, 1080),
          EdgeInsets.zero,
          isTouch: true,
        ).isTouch,
        isTrue,
      );
    });

    test('最小命中尺寸恒为 44', () {
      for (final size in const [Size(640, 360), Size(1280, 720), Size(1920, 1080)]) {
        expect(AppLayoutSpec.resolve(size, EdgeInsets.zero).minimumTapExtent, 44);
      }
    });
  });

  test('value equality 与 hashCode 一致（供 InheritedWidget 短路）', () {
    const a = Size(1280, 720);
    final x = AppLayoutSpec.resolve(a, EdgeInsets.zero);
    final y = AppLayoutSpec.resolve(a, EdgeInsets.zero);
    expect(x, y);
    expect(x.hashCode, y.hashCode);
    expect(x == AppLayoutSpec.resolve(const Size(1920, 1080), EdgeInsets.zero),
        isFalse);
  });
}
