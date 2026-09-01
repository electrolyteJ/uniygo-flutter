/// MSG_SELECT_CARD 选卡选项卡密回查测试。
///
/// 背景：服务端在选卡载荷里对候选卡可能下发 code=0（客户端需自行按位置
/// 回查本地已同步的公开区域卡密）。墓穴的指名者选墓地怪兽是典型场景——
/// 若不回查，CardSelector 会把 code=0 的选项渲染成空白占位卡。
///
/// 此处只测纯函数 resolveSelectOptionCode；发回包副作用由
/// applySelectCard 承担，依赖 Riverpod/IDuelService，不在本单测范围。
library;

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter_test/flutter_test.dart';

DuelFieldState _board({
  int myController = 0,
  List<int> selfGrave = const [],
  List<int> oppGrave = const [],
  List<int> selfRemoved = const [],
  List<int> oppRemoved = const [],
  List<int> selfExtra = const [],
  List<int> oppExtra = const [],
}) {
  return DuelFieldState(
    myController: myController,
    selfGraveCodes: selfGrave,
    opponentGraveCodes: oppGrave,
    selfRemovedCodes: selfRemoved,
    opponentRemovedCodes: oppRemoved,
    selfExtraCodes: selfExtra,
    opponentExtraCodes: oppExtra,
  );
}

void main() {
  group('resolveSelectOptionCode 选卡卡密回查', () {
    test('code>0 原样返回，不回查', () {
      final board = _board(oppGrave: [11111111]);
      expect(
        resolveSelectOptionCode(89631139, 1, CARD_ZONE_GRAVE, 0, board),
        89631139,
      );
    });

    test('墓地 code=0 → 按对方墓地下标回查', () {
      final board = _board(oppGrave: [11111111, 0, 0, 14558127]);
      expect(
        resolveSelectOptionCode(0, 1, CARD_ZONE_GRAVE, 0, board),
        11111111,
      );
      expect(
        resolveSelectOptionCode(0, 1, CARD_ZONE_GRAVE, 3, board),
        14558127,
      );
    });

    test('墓地 code=0 → 按己方墓地下标回查', () {
      final board = _board(selfGrave: [22222222, 33333333]);
      expect(
        resolveSelectOptionCode(0, 0, CARD_ZONE_GRAVE, 1, board),
        33333333,
      );
    });

    test('除外/额外区域同样回查', () {
      final board = _board(
        oppRemoved: [44444444],
        oppExtra: [55555555, 66666666],
      );
      expect(
        resolveSelectOptionCode(0, 1, CARD_ZONE_REMOVED, 0, board),
        44444444,
      );
      expect(
        resolveSelectOptionCode(0, 1, CARD_ZONE_EXTRA, 1, board),
        66666666,
      );
    });

    test('卡组/手牌（隐私区）不回查，保持 0', () {
      final board = _board();
      expect(resolveSelectOptionCode(0, 1, CARD_ZONE_DECK, 0, board), 0);
      expect(resolveSelectOptionCode(0, 1, CARD_ZONE_HAND, 0, board), 0);
    });

    test('场上怪兽区不在回查范围（内联点选承载），保持 0', () {
      final board = _board();
      expect(resolveSelectOptionCode(0, 1, CARD_ZONE_MZONE, 0, board), 0);
    });

    test('序列越界 → 保持 0', () {
      final board = _board(oppGrave: [11111111]);
      expect(resolveSelectOptionCode(0, 1, CARD_ZONE_GRAVE, 5, board), 0);
      expect(resolveSelectOptionCode(0, 1, CARD_ZONE_GRAVE, -1, board), 0);
    });

    test('本地快照该位置也是 0（占位）→ 保持 0', () {
      final board = _board(oppGrave: [0, 11111111]);
      expect(resolveSelectOptionCode(0, 1, CARD_ZONE_GRAVE, 0, board), 0);
    });
  });
}
