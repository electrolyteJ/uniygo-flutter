import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/models/deck_model.dart';
import 'package:ygo_card/card_info.dart';

void main() {
  group('DeckMeta', () {
    test('should create DeckMeta with default values', () {
      const deck = DeckMeta(deckName: 'Test Deck');

      expect(deck.deckName, 'Test Deck');
      expect(deck.mainCount, 0);
      expect(deck.extraCount, 0);
      expect(deck.sideCount, 0);
      expect(deck.isBuiltin, false);
    });

    test('should serialize to JSON correctly', () {
      const deck = DeckMeta(
        deckName: 'Test Deck',
        mainCount: 40,
        extraCount: 15,
        sideCount: 15,
        isBuiltin: true,
      );

      final json = deck.toJson();

      expect(json['deckName'], 'Test Deck');
      expect(json['mainCount'], 40);
      expect(json['extraCount'], 15);
      expect(json['sideCount'], 15);
      expect(json['isBuiltin'], true);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'deckName': 'Test Deck',
        'mainCount': 40,
        'extraCount': 15,
        'sideCount': 15,
        'isBuiltin': false,
      };

      final deck = DeckMeta.fromJson(json);

      expect(deck.deckName, 'Test Deck');
      expect(deck.mainCount, 40);
      expect(deck.extraCount, 15);
      expect(deck.sideCount, 15);
      expect(deck.isBuiltin, false);
    });

    test('should copy with new values', () {
      const deck = DeckMeta(deckName: 'Original');
      final copied = deck.copyWith(deckName: 'Modified', isBuiltin: true);

      expect(copied.deckName, 'Modified');
      expect(copied.isBuiltin, true);
    });
  });

  group('EditingDeck', () {
    test('should initialize with empty lists', () {
      final deck = EditingDeck(deckName: 'Test');

      expect(deck.deckName, 'Test');
      expect(deck.main, isEmpty);
      expect(deck.extra, isEmpty);
      expect(deck.side, isEmpty);
      expect(deck.isDirty, false);
    });

    test('should calculate counts correctly', () {
      final deck = EditingDeck(
        deckName: 'Test',
        main: List.filled(40, _mockCard(100)),
        extra: List.filled(15, _mockCard(200)),
        side: List.filled(15, _mockCard(300)),
      );

      expect(deck.mainCount, 40);
      expect(deck.extraCount, 15);
      expect(deck.sideCount, 15);
      expect(deck.totalCount, 70);
    });

    test('should clear all cards', () {
      final deck = EditingDeck(
        deckName: 'Test',
        main: List.filled(40, _mockCard(100)),
        extra: List.filled(15, _mockCard(200)),
        side: List.filled(15, _mockCard(300)),
        isDirty: false,
      );

      deck.clear();

      expect(deck.main, isEmpty);
      expect(deck.extra, isEmpty);
      expect(deck.side, isEmpty);
      expect(deck.isDirty, true);
    });

    test('should reset to new deck', () {
      final deck = EditingDeck(
        deckName: 'Old',
        main: List.filled(10, _mockCard(100)),
      );

      final newMain = List.filled(5, _mockCard(999));
      deck.reset('New', newMain, [], []);

      expect(deck.deckName, 'New');
      expect(deck.main.length, 5);
      expect(deck.main.first.code, 999);
      expect(deck.isDirty, false);
    });

    test('toMeta should create correct metadata', () {
      final deck = EditingDeck(
        deckName: 'Test',
        main: List.filled(40, _mockCard(100)),
        extra: List.filled(10, _mockCard(200)),
        side: List.filled(5, _mockCard(300)),
      );

      final meta = deck.toMeta();

      expect(meta.deckName, 'Test');
      expect(meta.mainCount, 40);
      expect(meta.extraCount, 10);
      expect(meta.sideCount, 5);
    });
  });

  group('CardFilter', () {
    test('should be default when all fields are null', () {
      const filter = CardFilter();
      expect(filter.isDefault, true);
    });

    test('should not be default when any field is set', () {
      const filter = CardFilter(attribute: 0x01);
      expect(filter.isDefault, false);
    });

    test('should copy with new values', () {
      const filter = CardFilter(attribute: 0x01);
      final newFilter = filter.copyWith(race: 0x10);

      expect(newFilter.attribute, 0x01);
      expect(newFilter.race, 0x10);
    });

    test('should clear fields when specified', () {
      const filter = CardFilter(attribute: 0x01, race: 0x10);
      final newFilter = filter.copyWith(clearAttribute: true);

      expect(newFilter.attribute, null);
      expect(newFilter.race, 0x10);
    });
  });
}

CardInfo _mockCard(int code) {
  return CardInfo(
    code: code,
    alias: 0,
    setcode: [],
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
