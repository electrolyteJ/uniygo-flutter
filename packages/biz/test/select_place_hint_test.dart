/// MSG_SELECT_PLACE 放置选择窗口的回归测试。
///
/// 背景（线上实测截图 + 日志）：对手回合人类收到
/// MSG_SELECT_PLACE(player:1 count:1 field:0xFFFFE1FF)（可用区域为
/// 己方魔陷区 1-4 号位），duel_room3 的通用横幅对所有窗口类型一律
/// 展示 inlineSelectHint —— 而 inlineSelectHint 的 switch 没有
/// SelectType.place 分支，落到 default 显示「请选择 1 张卡」，
/// 引导用户去点卡而不是点场地槽位，造成「不知道选择哪里」。
library;

import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造一个放置选择窗口（模拟 0xFFFFE1FF 位图解析结果：
/// 己方 SZONE 1-4 号位可选；CARD_ZONE_SZONE = 0x08）。
SelectWindowState _placeWindow({int optionCount = 4, int player = 1}) {
  return SelectWindowState(
    currentSelect: SelectState(
      type: SelectType.place,
      player: player,
      min: 1,
      max: 1,
      options: [
        for (var s = 0; s < optionCount; s++)
          SelectOption(
            code: 0,
            controller: player,
            zone: 0x08, // CARD_ZONE_SZONE
            sequence: s + 1,
          ),
      ],
    ),
  );
}

void main() {
  group('MSG_SELECT_PLACE 放置窗口', () {
    test('文案是放置区域提示（回归：不能落到「请选择 1 张卡」）', () {
      expect(_placeWindow().inlineSelectHint, contains('放置区域'));
      expect(_placeWindow().inlineSelectHint, isNot(contains('张卡')));
    });

    test('多个可选槽位时附带数量', () {
      expect(_placeWindow(optionCount: 4).inlineSelectHint, contains('4'));
    });

    test('单一槽位时不带数量后缀', () {
      expect(_placeWindow(optionCount: 1).inlineSelectHint, '请选择放置区域');
    });

    test('placeTargetFieldKeys 映射为场地槽位 key（controller_zone_seq）', () {
      final keys = _placeWindow(optionCount: 4, player: 1)
          .placeTargetFieldKeys;
      expect(
        keys,
        unorderedEquals({'1_8_1', '1_8_2', '1_8_3', '1_8_4'}),
      );
    });

    test('placeTargetFieldKeys 排除非场上区域（如手牌/墓地）', () {
      final state = SelectWindowState(
        currentSelect: SelectState(
          type: SelectType.place,
          player: 0,
          options: const [
            SelectOption(code: 0, controller: 0, zone: 0x08, sequence: 2),
            SelectOption(code: 0, controller: 0, zone: 0x02, sequence: 0),
          ],
        ),
      );
      expect(state.placeTargetFieldKeys, {'0_8_2'});
    });

    test('回归：card 窗口 max==1 仍显示「请选择 1 张卡」', () {
      const state = SelectWindowState(
        currentSelect: SelectState(
          type: SelectType.card,
          player: 1,
          options: [SelectOption(code: 89631139)],
        ),
      );
      expect(state.inlineSelectHint, '请选择 1 张卡');
    });
  });
}
