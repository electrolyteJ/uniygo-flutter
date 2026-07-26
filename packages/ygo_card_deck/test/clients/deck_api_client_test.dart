import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:ygo_card_deck/clients/deck_api_client.dart';
import 'package:ygo_card_deck/exceptions/ygo_card_deck_exception.dart';
import 'package:ygo_card_deck/models/deck_info.dart';

const _testBaseUrl = 'https://deck-api.example.com';
const _testReqSource = 'MDPro3';

/// UTF-8 encoded HTTP 200 response helper.
http.Response _ok(String body) =>
    http.Response.bytes(utf8.encode(body), 200);

void main() {
  group('DeckApiClient', () {
    late http.Client mockClient;

    DeckApiClient createClient(http.Client client) => DeckApiClient(
          baseUrl: _testBaseUrl,
          reqSource: _testReqSource,
          client: client,
        );

    group('fetchDeckList', () {
      test('fetches paginated deck list', () async {
        mockClient = MockClient((request) async {
          expect(request.url.toString(),
              contains('$_testBaseUrl/api/mdpro3/deck/list'));
          expect(request.headers['reqsource'], _testReqSource);
          expect(request.method, 'GET');

          return _ok(jsonEncode({
            'decks': [
              {
                'deckId': 'abc123',
                'name': 'Blue-Eyes Deck',
                'contributor': 'PlayerA',
                'likeCount': 42,
                'isPublic': true,
                'rank': 1500,
                'coverCode': 89631139,
              },
              {
                'deckId': 'def456',
                'name': 'Cyberse Deck',
                'contributor': 'PlayerB',
                'likeCount': 15,
                'isPublic': true,
                'rank': 1480,
              },
            ],
            'page': 1,
            'size': 20,
            'total': 100,
          }));
        });

        final client = createClient(mockClient);
        final page = await client.fetchDeckList(page: 1, size: 20);

        expect(page.decks.length, 2);
        expect(page.decks[0].deckId, 'abc123');
        expect(page.decks[0].name, 'Blue-Eyes Deck');
        expect(page.decks[0].likeCount, 42);
        expect(page.decks[1].deckId, 'def456');
        expect(page.page, 1);
        expect(page.total, 100);
      });

      test('includes keyword search param', () async {
        mockClient = MockClient((request) async {
          final url = request.url.toString();
          expect(url, contains('keyWord=test'));
          return _ok(jsonEncode({'decks': []}));
        });

        final client = createClient(mockClient);
        await client.fetchDeckList(keyword: 'test');
      });

      test('omits empty keyword param', () async {
        mockClient = MockClient((request) async {
          final url = request.url.toString();
          expect(url, isNot(contains('keyWord')));
          return _ok(jsonEncode({'decks': []}));
        });

        final client = createClient(mockClient);
        await client.fetchDeckList(keyword: '');
      });

      test('includes sort params', () async {
        mockClient = MockClient((request) async {
          final url = request.url.toString();
          expect(url, contains('sortLike=true'));
          expect(url, contains('sortRank=false'));
          return _ok(jsonEncode({'decks': []}));
        });

        final client = createClient(mockClient);
        await client.fetchDeckList(sortLike: true, sortRank: false);
      });

      test('includes contributor param', () async {
        mockClient = MockClient((request) async {
          final url = request.url.toString();
          expect(url, contains('contributor=PlayerA'));
          return _ok(jsonEncode({'decks': []}));
        });

        final client = createClient(mockClient);
        await client.fetchDeckList(contributor: 'PlayerA');
      });

      test('throws parseError for non-object response', () async {
        mockClient = MockClient(
          (_) => Future.value(_ok('"string"')),
        );
        final client = createClient(mockClient);

        expect(
          () => client.fetchDeckList(),
          throwsA(
            isA<YgoCardDeckException>()
                .having((e) => e.type, 'type', YgoCardDeckErrorType.parseError),
          ),
        );
      });
    });

    group('fetchDeckDetail', () {
      test('fetches deck by id', () async {
        mockClient = MockClient((request) async {
          expect(request.url.toString(),
              '$_testBaseUrl/api/mdpro3/deck/abc123');
          expect(request.headers['reqsource'], _testReqSource);

          return _ok(jsonEncode({
            'deckId': 'abc123',
            'name': 'Detail Deck',
            'contributor': 'Player',
            'main': [
              {'code': 100, 'count': 3},
            ],
            'extra': [
              {'code': 200, 'count': 1},
            ],
            'side': [],
            'likeCount': 5,
          }));
        });

        final client = createClient(mockClient);
        final deck = await client.fetchDeckDetail('abc123');

        expect(deck.deckId, 'abc123');
        expect(deck.name, 'Detail Deck');
        expect(deck.mainDeck.length, 1);
        expect(deck.mainDeck[0].code, 100);
        expect(deck.mainDeck[0].count, 3);
        expect(deck.extraDeck.length, 1);
      });
    });

    group('generateDeckId', () {
      test('returns deckId from response', () async {
        mockClient = MockClient(
          (_) async => _ok(jsonEncode({'deckId': 'new-deck-001'})),
        );

        final client = createClient(mockClient);
        final id = await client.generateDeckId();

        expect(id, 'new-deck-001');
      });

      test('falls back to id field', () async {
        mockClient = MockClient(
          (_) async => _ok(jsonEncode({'id': 'fallback-id'})),
        );

        final client = createClient(mockClient);
        final id = await client.generateDeckId();

        expect(id, 'fallback-id');
      });

      test('falls back to raw body for non-map json', () async {
        mockClient = MockClient(
          (_) => Future.value(_ok('"raw-string-id"')),
        );
        final client = createClient(mockClient);
        final id = await client.generateDeckId();

        expect(id, 'raw-string-id');
      });
    });

    group('fetchUserDecks', () {
      test('fetches user decks with auth token', () async {
        mockClient = MockClient((request) async {
          expect(request.url.toString(),
              '$_testBaseUrl/api/mdpro3/sync/42/nodel');
          expect(request.headers['token'], 'my-token');
          expect(request.method, 'GET');

          return _ok(jsonEncode([
            {'deckId': 'u1', 'name': 'My Deck 1'},
            {'deckId': 'u2', 'name': 'My Deck 2'},
          ]));
        });

        final client = createClient(mockClient);
        final decks = await client.fetchUserDecks(
          userId: 42,
          token: 'my-token',
        );

        expect(decks.length, 2);
        expect(decks[0].deckId, 'u1');
        expect(decks[1].deckId, 'u2');
      });

      test('handles {"decks": [...]} response format', () async {
        mockClient = MockClient((_) async {
          return _ok(jsonEncode({
            'decks': [
              {'deckId': 'w1'},
            ],
          }));
        });

        final client = createClient(mockClient);
        final decks = await client.fetchUserDecks(
          userId: 1,
          token: 'token',
        );

        expect(decks.length, 1);
        expect(decks[0].deckId, 'w1');
      });

      test('throws unauthorized for 401 on user decks', () async {
        mockClient = MockClient((_) => Future.value(http.Response('', 401)));
        final client = createClient(mockClient);

        expect(
          () => client.fetchUserDecks(userId: 1, token: 'bad'),
          throwsA(
            isA<YgoCardDeckException>()
                .having((e) => e.type, 'type', YgoCardDeckErrorType.unauthorized),
          ),
        );
      });
    });

    group('uploadDeck', () {
      test('sends correct JSON body', () async {
        mockClient = MockClient((request) async {
          expect(request.url.toString(), '$_testBaseUrl/api/mdpro3/sync/single');
          expect(request.method, 'POST');
          expect(request.headers['token'], 'upload-token');
          expect(request.headers['content-type'], contains('application/json'));

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['userId'], 1);
          expect(body['contributor'], 'Uploader');
          expect(body['deck']['deckId'], 'upload-001');
          expect(body['deck']['name'], 'Uploaded Deck');

          return http.Response('', 200);
        });

        final client = createClient(mockClient);
        final deck = DeckInfo(
          deckId: 'upload-001',
          name: 'Uploaded Deck',
          mainDeck: const [DeckCard(code: 100, count: 3)],
        );

        await client.uploadDeck(
          deck: deck,
          userId: 1,
          contributor: 'Uploader',
          token: 'upload-token',
        );
      });
    });

    group('deleteDeck', () {
      test('sends delete request', () async {
        mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['deck']['deckId'], 'delete-me');
          expect(body['deck']['isDelete'], true);
          return http.Response('', 200);
        });

        final client = createClient(mockClient);
        await client.deleteDeck(
          deckId: 'delete-me',
          userId: 1,
          contributor: 'Owner',
          token: 'token',
        );
      });
    });

    group('toggleDeckPublic', () {
      test('sends public toggle request', () async {
        mockClient = MockClient((request) async {
          expect(request.url.toString(),
              '$_testBaseUrl/api/mdpro3/deck/public');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['deckId'], 'toggle-me');
          expect(body['isPublic'], false);
          return http.Response('', 200);
        });

        final client = createClient(mockClient);
        await client.toggleDeckPublic(
          deckId: 'toggle-me',
          userId: 1,
          isPublic: false,
          token: 'token',
        );
      });
    });

    group('likeDeck', () {
      test('sends like request', () async {
        mockClient = MockClient((request) async {
          expect(request.url.toString(),
              '$_testBaseUrl/api/mdpro3/deck/like/like-me');
          expect(request.method, 'POST');
          return http.Response('', 200);
        });

        final client = createClient(mockClient);
        await client.likeDeck('like-me');
      });
    });

    group('error handling', () {
      test('maps server error', () async {
        mockClient = MockClient((_) => Future.value(http.Response('', 503)));
        final client = createClient(mockClient);

        expect(
          () => client.fetchDeckList(),
          throwsA(
            isA<YgoCardDeckException>()
                .having((e) => e.type, 'type', YgoCardDeckErrorType.serverError),
          ),
        );
      });

      test('maps ClientException', () async {
        mockClient = MockClient(
          (_) => throw http.ClientException('No connection'),
        );
        final client = createClient(mockClient);

        expect(
          () => client.fetchDeckDetail('any'),
          throwsA(
            isA<YgoCardDeckException>()
                .having((e) => e.type, 'type', YgoCardDeckErrorType.networkError)
                .having((e) => e.message, 'message', 'No connection'),
          ),
        );
      });
    });
  });
}
