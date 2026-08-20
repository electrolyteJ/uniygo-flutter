/// 「单一必选项自动代答」判定逻辑测试。
///
/// 背景：发动卡片效果后若选择窗口只有一个必选项（没得选、也不能取消），
/// 弹窗让玩家点是毫无意义的操作。isForcedSingleSelect 判定命中后由
/// SelectWindowNotifier._tryAutoAnswer 直接代为应答、不弹窗。
///
/// 此处只测纯判定函数；发回包的副作用（selectMulti([0])）由
/// _tryAutoAnswer 承担，依赖 IDuelService，不在本单测范围。
library;

import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:flutter_test/flutter_test.dart';

SelectState _window({
  SelectType type = SelectType.card,
  int optionCount = 1,
  int min = 1,
  bool cancelable = false,
  int player = 0,
}) {
  return SelectState(
    type: type,
    player: player,
    min: min,
    max: 1,
    cancelable: cancelable,
    options: [
      for (int i = 0; i < optionCount; i++)
        SelectOption(code: 89631139 + i, controller: 0, zone: 0x10, sequence: i),
    ],
  );
}

void main() {
  group('isForcedSingleSelect 单一必选项判定', () {
    test('恰好 1 个选项 + 必选 + 不可取消 → 命中', () {
      expect(isForcedSingleSelect(_window(), 0), isTrue);
    });

    test('tribute 窗口同样命中', () {
      expect(isForcedSingleSelect(_window(type: SelectType.tribute), 0), isTrue);
    });

    test('多个选项（有的选）→ 不命中', () {
      expect(isForcedSingleSelect(_window(optionCount: 2), 0), isFalse);
    });

    test('没有选项 → 不命中', () {
      expect(isForcedSingleSelect(_window(optionCount: 0), 0), isFalse);
    });

    test('可取消（玩家可不选）→ 不命中', () {
      expect(isForcedSingleSelect(_window(cancelable: true), 0), isFalse);
    });

    test('min=0（非必选）→ 不命中', () {
      expect(isForcedSingleSelect(_window(min: 0), 0), isFalse);
    });

    test('对方玩家的窗口 → 不命中（防御性校验）', () {
      expect(isForcedSingleSelect(_window(player: 1), 0), isFalse);
    });

    test('非 card/tribute 类型（option）→ 不命中', () {
      expect(isForcedSingleSelect(_window(type: SelectType.option), 0), isFalse);
    });

    test('非 card/tribute 类型（position）→ 不命中', () {
      expect(isForcedSingleSelect(_window(type: SelectType.position), 0), isFalse);
    });

    test('非 card/tribute 类型（chain）→ 不命中', () {
      expect(isForcedSingleSelect(_window(type: SelectType.chain), 0), isFalse);
    });
  });
}
