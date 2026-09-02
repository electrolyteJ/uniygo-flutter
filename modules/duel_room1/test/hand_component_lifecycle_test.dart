/// 手牌组件生命周期回归测试。
///
/// 背景：SpriteComponent 化重构曾引入两处运行时崩溃——
/// 1. HandBarComponent.applySnapshot 在 add(卡) 后同一帧 updateContent，
///    而卡体/装饰子组件在异步 onLoad 才创建（LateInitializationError）；
/// 2. Flame 1.38 的 SpriteComponent 挂载时要求 sprite 非空。
/// 本测试不挂载组件、不依赖游戏实例，直接驱动公开 API 验证时序安全。
library;

import 'package:duel_room1/field/components/hand_card/hand.dart';
import 'package:duel_room1/field/components/hand_card/hand_bar_component.dart';
import 'package:duel_room1/field/components/hand_card/hand_card_component.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('手牌组件生命周期（挂载前安全）', () {
    test('HandCardComponent 构造后即可 updateContent（不等 onLoad）', () {
      final card = HandCardComponent(index: 0, isSelfSide: true);
      // faceUp=false：不触发卡图加载（该路径需要游戏实例，挂载前不可用）。
      expect(
        () => card.updateContent(
          code: 0,
          faceUp: false,
          selected: true,
          highlighted: false,
          checked: false,
          dimmed: false,
          chainOrder: 1,
        ),
        returnsNormally,
      );
      // 状态变化驱动动效（选中→取消）也不应抛异常。
      expect(
        () => card.updateContent(
          code: 0,
          faceUp: false,
          selected: false,
          highlighted: false,
          checked: false,
          dimmed: false,
          chainOrder: null,
        ),
        returnsNormally,
      );
    });

    test('HandBarComponent applySnapshot 增删卡/隐藏揭示不抛异常', () {
      final bar = HandBarComponent(isSelfSide: false);
      HandSnapshot snap(int count) => HandSnapshot(
        codes: List.filled(count, 0),
        faceUp: false,
        selectedIndex: null,
        highlightedIndices: const {},
        checkedIndices: const {},
        chainOrderByIndex: const {},
        shuffleTick: 0,
      );
      expect(() => bar.applySnapshot(snap(5)), returnsNormally);
      // 抽卡隐藏/揭示流程。
      final concealed = bar.concealTrailing(2);
      expect(concealed, [3, 4]);
      expect(() => bar.reveal(3), returnsNormally);
      // 减卡（丢手）后再增卡。
      expect(() => bar.applySnapshot(snap(3)), returnsNormally);
      expect(() => bar.applySnapshot(snap(6)), returnsNormally);
      expect(() => bar.revealAll(), returnsNormally);
    });
  });
}
