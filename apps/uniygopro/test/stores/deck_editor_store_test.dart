import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/pages/deck_editor/deck_editor_store.dart';
import 'package:ygo_data/card_info.dart';

void main() {
  group('DeckEditorStore', () {
    test('renameEditingDeck updates name, marks dirty, and notifies', () {
      final store = DeckEditorStore();
      var notifyCount = 0;
      store.addListener(() => notifyCount++);

      store.renameEditingDeck('Renamed Deck');

      expect(store.editingDeck.deckName, 'Renamed Deck');
      expect(store.editingDeck.isDirty, true);
      expect(notifyCount, 1);
    });

    test('replaceEditingDeck swaps deck contents and keeps dirty flag configurable', () {
      final store = DeckEditorStore();
      var notifyCount = 0;
      store.addListener(() => notifyCount++);

      store.replaceEditingDeck(
        deckName: 'Imported Deck',
        main: [_mockCard(1001), _mockCard(1002)],
        extra: [_mockCard(2001)],
        side: [_mockCard(3001)],
        markDirty: true,
      );

      expect(store.editingDeck.deckName, 'Imported Deck');
      expect(store.editingDeck.main.map((card) => card.code), [1001, 1002]);
      expect(store.editingDeck.extra.map((card) => card.code), [2001]);
      expect(store.editingDeck.side.map((card) => card.code), [3001]);
      expect(store.editingDeck.isDirty, true);
      expect(notifyCount, 1);
    });
  });
}

CardInfo _mockCard(int code) {
  return CardInfo(
    code: code,
    alias: 0,
    setcode: const [],
    type: 0x1,
    level: 4,
    attribute: 0x10,
    race: 0x1,
    attack: 1000,
    defense: 1000,
    lscale: 0,
    rscale: 0,
    linkMarker: 0,
    name: '测试卡牌 $code',
    desc: '这是一张测试卡牌',
  );
}
