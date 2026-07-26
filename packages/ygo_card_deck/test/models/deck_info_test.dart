import 'package:test/test.dart';
import 'package:ygo_card_deck/models/deck_info.dart';
import 'package:ygo_card_deck/models/deck_list_page.dart';

void main() {
  group('DeckCard', () {
    group('fromJson', () {
      test('parses with count', () {
        final card = DeckCard.fromJson({'code': 89631139, 'count': 3});
        expect(card.code, 89631139);
        expect(card.count, 3);
      });

      test('defaults count to 1', () {
        final card = DeckCard.fromJson({'code': 12345});
        expect(card.count, 1);
      });

      test('defaults code to 0', () {
        final card = DeckCard.fromJson({});
        expect(card.code, 0);
        expect(card.count, 1);
      });
    });

    group('toJson', () {
      test('roundtrips correctly', () {
        final original = const DeckCard(code: 12345, count: 2);
        final restored = DeckCard.fromJson(original.toJson());
        expect(restored.code, 12345);
        expect(restored.count, 2);
      });
    });
  });

  group('DeckInfo', () {
    group('fromJson', () {
      test('parses complete deck', () {
        final json = <String, dynamic>{
          'deckId': 'abc123',
          'name': '青眼卡组',
          'contributor': '玩家A',
          'userId': 42,
          'main': [
            {'code': 89631139, 'count': 3},
            {'code': 89631139, 'count': 2}, // 另一张
          ],
          'extra': [
            {'code': 12345, 'count': 1},
          ],
          'side': [
            {'code': 67890, 'count': 2},
          ],
          'likeCount': 10,
          'isPublic': true,
          'rank': 1500,
          'createdAt': '2024-01-01T00:00:00Z',
          'description': '标准青眼卡组',
          'coverCode': 89631139,
        };

        final deck = DeckInfo.fromJson(json);

        expect(deck.deckId, 'abc123');
        expect(deck.name, '青眼卡组');
        expect(deck.contributor, '玩家A');
        expect(deck.userId, 42);
        expect(deck.mainDeck.length, 2);
        expect(deck.extraDeck.length, 1);
        expect(deck.sideDeck.length, 1);
        expect(deck.mainCount, 5);
        expect(deck.extraCount, 1);
        expect(deck.sideCount, 2);
        expect(deck.likeCount, 10);
        expect(deck.isPublic, isTrue);
        expect(deck.rank, 1500);
        expect(deck.createdAt, '2024-01-01T00:00:00Z');
        expect(deck.description, '标准青眼卡组');
        expect(deck.coverCode, 89631139);
      });

      test('handles alternative field names', () {
        final json = <String, dynamic>{
          'id': 'deck-456',
          'mainDeck': [],
          'extraDeck': [],
          'sideDeck': [],
          'likes': 5,
        };

        final deck = DeckInfo.fromJson(json);

        expect(deck.deckId, 'deck-456');
        expect(deck.likeCount, 5);
      });

      test('defaults for empty json', () {
        final deck = DeckInfo.fromJson({});

        expect(deck.deckId, '');
        expect(deck.name, '');
        expect(deck.mainDeck, isEmpty);
        expect(deck.extraDeck, isEmpty);
        expect(deck.sideDeck, isEmpty);
        expect(deck.likeCount, 0);
        expect(deck.isPublic, isTrue);
        expect(deck.rank, 0);
      });

      test('handles null deck lists', () {
        final json = <String, dynamic>{'deckId': 'test'};

        final deck = DeckInfo.fromJson(json);

        expect(deck.mainDeck, isEmpty);
        expect(deck.extraDeck, isEmpty);
        expect(deck.sideDeck, isEmpty);
      });
    });

    group('allCodes', () {
      test('collects unique codes from all decks', () {
        final deck = DeckInfo(
          deckId: 'test',
          mainDeck: const [
            DeckCard(code: 1, count: 3),
            DeckCard(code: 2, count: 2),
          ],
          extraDeck: const [
            DeckCard(code: 3, count: 1),
            DeckCard(code: 1, count: 1), // duplicate
          ],
          sideDeck: const [
            DeckCard(code: 4, count: 2),
          ],
        );

        expect(deck.allCodes, {1, 2, 3, 4});
      });
    });

    group('toJson/fromJson', () {
      test('roundtrips correctly', () {
        final original = DeckInfo(
          deckId: 'abc',
          name: 'Test Deck',
          contributor: 'Tester',
          userId: 1,
          mainDeck: const [DeckCard(code: 100, count: 3)],
          extraDeck: const [DeckCard(code: 200, count: 1)],
          sideDeck: const [DeckCard(code: 300, count: 2)],
          likeCount: 5,
          coverCode: 100,
          description: 'A test deck',
        );

        final restored = DeckInfo.fromJson(original.toJson());

        expect(restored.deckId, original.deckId);
        expect(restored.name, original.name);
        expect(restored.mainDeck.length, original.mainDeck.length);
        expect(restored.mainDeck[0].code, 100);
      });
    });
  });

  group('DeckSummary', () {
    group('fromJson', () {
      test('parses summary', () {
        final json = <String, dynamic>{
          'deckId': 'sum123',
          'name': '概要卡组',
          'contributor': 'User',
          'likeCount': 5,
          'isPublic': true,
          'rank': 1500,
        };

        final summary = DeckSummary.fromJson(json);

        expect(summary.deckId, 'sum123');
        expect(summary.name, '概要卡组');
        expect(summary.likeCount, 5);
      });

      test('handles alternative field names', () {
        final json = <String, dynamic>{
          'id': 'alt123',
          'likes': 10,
        };

        final summary = DeckSummary.fromJson(json);
        expect(summary.deckId, 'alt123');
        expect(summary.likeCount, 10);
      });
    });
  });

  group('DeckListPage', () {
    group('fromJson', () {
      test('parses page from "decks" field', () {
        final json = <String, dynamic>{
          'decks': [
            {'deckId': 'd1', 'name': 'Deck 1'},
            {'deckId': 'd2', 'name': 'Deck 2'},
          ],
          'page': 1,
          'size': 20,
          'total': 100,
        };

        final page = DeckListPage.fromJson(json);

        expect(page.decks.length, 2);
        expect(page.decks[0].deckId, 'd1');
        expect(page.page, 1);
        expect(page.size, 20);
        expect(page.total, 100);
        expect(page.hasMore, isTrue);
      });

      test('parses page from "data" field', () {
        final json = <String, dynamic>{
          'data': [
            {'deckId': 'd3'},
          ],
          'page': 2,
          'size': 10,
          'total': 15,
        };

        final page = DeckListPage.fromJson(json);

        expect(page.decks.length, 1);
        expect(page.decks[0].deckId, 'd3');
        expect(page.hasMore, isFalse); // 2 * 10 >= 15
      });

      test('parses page from "list" field', () {
        final json = <String, dynamic>{
          'list': [
            {'id': 'd4'},
          ],
          'total': 1,
        };

        final page = DeckListPage.fromJson(json);

        expect(page.decks.length, 1);
        expect(page.decks[0].deckId, 'd4');
      });

      test('handles emptpy', () {
        final page = DeckListPage.fromJson({});
        expect(page.decks, isEmpty);
        expect(page.page, 1);
        expect(page.total, 0);
        expect(page.hasMore, isFalse);
      });
    });

    group('hasMore', () {
      test('true when more pages available', () {
        final page = DeckListPage(page: 1, size: 10, total: 25);
        expect(page.hasMore, isTrue);
      });

      test('false when on last page', () {
        final page = DeckListPage(page: 3, size: 10, total: 30);
        expect(page.hasMore, isFalse);
      });

      test('false when total is unknown (0)', () {
        final page = DeckListPage(page: 1, size: 10, total: 0);
        expect(page.hasMore, isFalse);
      });
    });
  });
}
