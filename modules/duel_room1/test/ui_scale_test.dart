import 'package:duel_room1/field/util/ui_scale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hudScaleForHeight', () {
    test('桌面高度不缩放', () {
      expect(hudScaleForHeight(760), 1.0);
      expect(hudScaleForHeight(1080), 1.0);
    });

    test('手机横屏高度按下限收缩', () {
      expect(hudScaleForHeight(390), kHudMinScale);
      expect(hudScaleForHeight(360), kHudMinScale);
    });

    test('中间高度线性插值', () {
      expect(hudScaleForHeight(608), closeTo(0.8, 1e-9));
    });

    test('非法高度兜底为 1', () {
      expect(hudScaleForHeight(0), 1.0);
      expect(hudScaleForHeight(-1), 1.0);
    });
  });

  group('isCompactHudHeight', () {
    test('低于基准高度进入紧凑模式', () {
      expect(isCompactHudHeight(390), isTrue);
      expect(isCompactHudHeight(759.9), isTrue);
    });

    test('达到基准高度退出紧凑模式', () {
      expect(isCompactHudHeight(760), isFalse);
      expect(isCompactHudHeight(1080), isFalse);
    });

    test('非法高度不进入紧凑模式', () {
      expect(isCompactHudHeight(0), isFalse);
    });
  });
}
