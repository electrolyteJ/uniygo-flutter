import 'package:deck_editor3/src/deck_state/editor_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/card_info.dart';

CardInfo monster({int code = 1}) => CardInfo(
      code: code, alias: 0, setcode: const [], type: 0x21, level: 4,
      attribute: 0, race: 0, attack: 1800, defense: 1200,
      lscale: 0, rscale: 0, linkMarker: 0, name: '怪兽$code', desc: '',
    );

CardInfo extraMonster({int code = 100}) => CardInfo(
      code: code, alias: 0, setcode: const [],
      type: 0x2001 | 0x800000, // 融合怪兽
      level: 8, attribute: 0, race: 0, attack: 3000, defense: 2500,
      lscale: 0, rscale: 0, linkMarker: 0, name: '融合$code', desc: '',
    );

void main() {
  group('tryAddCard', () {
    test('同卡最多 3 张', () {
      final state = DeckEditState();
      expect(tryAddCard(state, monster(code: 5), DeckZone.main), AddCardResult.ok);
      expect(tryAddCard(state, monster(code: 5), DeckZone.main), AddCardResult.ok);
      expect(tryAddCard(state, monster(code: 5), DeckZone.main), AddCardResult.ok);
      expect(tryAddCard(state, monster(code: 5), DeckZone.side),
          AddCardResult.copyLimitExceeded);
      expect(state.countOf(5), 3);
    });

    test('融合怪只能进额外卡组', () {
      final state = DeckEditState();
      expect(tryAddCard(state, extraMonster(), DeckZone.main),
          AddCardResult.wrongZone);
      expect(tryAddCard(state, extraMonster(), DeckZone.extra),
          AddCardResult.ok);
    });

    test('额外卡组上限 15 张', () {
      final state = DeckEditState();
      for (var i = 0; i < 15; i++) {
        expect(tryAddCard(state, extraMonster(code: 100 + i), DeckZone.extra),
            AddCardResult.ok);
      }
      expect(tryAddCard(state, extraMonster(code: 999), DeckZone.extra),
          AddCardResult.zoneFull);
    });
  });

  group('tryRemoveCard', () {
    test('减到 0 移除条目', () {
      final state = DeckEditState();
      tryAddCard(state, monster(code: 7), DeckZone.main);
      tryAddCard(state, monster(code: 7), DeckZone.main);
      expect(tryRemoveCard(state, 7, DeckZone.main), isTrue);
      expect(state.countOf(7), 1);
      expect(tryRemoveCard(state, 7, DeckZone.main), isTrue);
      expect(state.main, isEmpty);
      expect(tryRemoveCard(state, 7, DeckZone.main), isFalse);
    });
  });

  group('structuralErrors', () {
    test('主卡组 40 张下限', () {
      final state = DeckEditState();
      expect(structuralErrors(state), isNotEmpty);
      for (var i = 0; i < 40; i++) {
        tryAddCard(state, monster(code: 1000 + i), DeckZone.main);
      }
      expect(structuralErrors(state), isEmpty);
    });
  });

  group('DeckEditState 与 DeckInfo 互转', () {
    test('fromDeckInfo → toDeckInfo 往返', () {
      final state = DeckEditState(name: '测试卡组');
      tryAddCard(state, monster(code: 1), DeckZone.main);
      tryAddCard(state, monster(code: 1), DeckZone.main);
      final deck = state.toDeckInfo();
      expect(deck.deckName, '测试卡组');
      expect(deck.mainCount, 2);
      final restored = DeckEditState.fromDeckInfo(deck);
      expect(restored.name, '测试卡组');
      expect(restored.countOf(1), 2);
    });
  });
}
