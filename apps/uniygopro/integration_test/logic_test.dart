/// 纯逻辑单元测试（模型 / 配置 / 仓库 / 服务），无需 App 启动。
///
/// 放在 integration_test 下以复用同一套覆盖率采集流程；
/// 这些用例确定、无网络、无 UI，是覆盖率的主要来源之一。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:deck_editor1/deck_editor1.dart';
import 'package:resource_data/card_info.dart' as pkg;

pkg.CardInfo _card(int code, {String name = '', int type = 0x1}) =>
    pkg.CardInfo(code: code, type: type, name: name);

void main() {
  group('CardFilter', () {
    test('默认筛选判定与 copyWith 清除', () {
      const filter = CardFilter();
      expect(filter.isDefault, isTrue);
      const withEnv = CardFilter(env: 1);
      expect(withEnv.isDefault, isFalse);
      final cleared = withEnv.copyWith(clearEnv: true);
      expect(cleared.env, isNull);
      expect(cleared.isDefault, isTrue);
      final overridden = withEnv.copyWith(attribute: 0x1);
      expect(overridden.attribute, 0x1);
      expect(overridden.env, 1);
    });
  });

  group('DeckMeta', () {
    test('toJson/fromJson 往返', () {
      final meta = DeckMeta(
        deckName: '卡组A',
        mainCount: 40,
        extraCount: 3,
        sideCount: 5,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1234567),
        isBuiltin: true,
      );
      final restored = DeckMeta.fromJson(meta.toJson());
      expect(restored.deckName, '卡组A');
      expect(restored.mainCount, 40);
      expect(restored.extraCount, 3);
      expect(restored.sideCount, 5);
      expect(restored.isBuiltin, isTrue);
      expect(
        restored.updatedAt?.millisecondsSinceEpoch,
        meta.updatedAt?.millisecondsSinceEpoch,
      );
    });

    test('fromJson 缺省字段', () {
      final meta = DeckMeta.fromJson({'deckName': 'B'});
      expect(meta.mainCount, 0);
      expect(meta.isBuiltin, isFalse);
      expect(meta.updatedAt, isNull);
    });

    test('copyWith', () {
      const meta = DeckMeta(deckName: 'A', mainCount: 1);
      final next = meta.copyWith(mainCount: 60);
      expect(next.mainCount, 60);
      expect(next.deckName, 'A');
    });
  });

  group('EditingDeck', () {
    test('数量统计 / clear / reset / toMeta', () {
      final deck = EditingDeck(
        deckName: 'D',
        main: [_card(1), _card(2)],
        extra: [_card(3)],
        side: [_card(4), _card(5), _card(6)],
      );
      expect(deck.mainCount, 2);
      expect(deck.extraCount, 1);
      expect(deck.sideCount, 3);
      expect(deck.totalCount, 6);
      expect(deck.toMeta().mainCount, 2);

      deck.clear();
      expect(deck.totalCount, 0);
      expect(deck.isDirty, isTrue);

      deck.reset('R', [_card(7)], [], []);
      expect(deck.deckName, 'R');
      expect(deck.mainCount, 1);
      expect(deck.isDirty, isFalse);
    });
  });
}
