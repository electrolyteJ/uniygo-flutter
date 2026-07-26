import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:ygo_card_deck/clients/card_api_client.dart';
import 'package:ygo_card_deck/exceptions/ygo_card_deck_exception.dart';

const _testBaseUrl = 'https://cdn.example.com';

/// UTF-8 encoded HTTP 200 response helper.
http.Response _ok(String body) =>
    http.Response.bytes(utf8.encode(body), 200);

void main() {
  group('CardApiClient', () {
    late http.Client mockClient;

    CardApiClient createClient(http.Client client) =>
        CardApiClient(baseUrl: _testBaseUrl, client: client);

    group('fetchLflist', () {
      test('returns LflistInfo on success', () async {
        mockClient = MockClient((request) async {
          expect(request.url.toString(),
              '$_testBaseUrl/ygopro-database/zh-CN/lflist.conf');
          expect(request.method, 'GET');
          return _ok('#name 2024.01 OCG\n#date 2024-01-01\n12345678 0\n89631139 1\n');
        });

        final client = createClient(mockClient);
        final lflist = await client.fetchLflist();

        expect(lflist.name, '2024.01 OCG');
        expect(lflist.date, '2024-01-01');
        expect(lflist.entries.length, 2);
        expect(lflist.entries[0].code, 12345678);
        expect(lflist.entries[0].limit, 0);
        expect(lflist.entries[1].code, 89631139);
        expect(lflist.entries[1].limit, 1);
      });

      test('throws notFound for 404', () async {
        mockClient = MockClient((_) => Future.value(http.Response('', 404)));
        final client = createClient(mockClient);

        expect(
          () => client.fetchLflist(),
          throwsA(
            isA<YgoCardDeckException>()
                .having((e) => e.type, 'type', YgoCardDeckErrorType.notFound)
                .having((e) => e.statusCode, 'statusCode', 404),
          ),
        );
      });

      test('throws serverError for 500', () async {
        mockClient = MockClient((_) => Future.value(http.Response('', 500)));
        final client = createClient(mockClient);

        expect(
          () => client.fetchLflist(),
          throwsA(
            isA<YgoCardDeckException>()
                .having((e) => e.type, 'type', YgoCardDeckErrorType.serverError),
          ),
        );
      });

      test('throws unauthorized for 401', () async {
        mockClient = MockClient((_) => Future.value(http.Response('', 401)));
        final client = createClient(mockClient);

        expect(
          () => client.fetchLflist(),
          throwsA(
            isA<YgoCardDeckException>()
                .having((e) => e.type, 'type', YgoCardDeckErrorType.unauthorized),
          ),
        );
      });
    });

    group('fetchLflist408', () {
      test('fetches from 408 URL', () async {
        mockClient = MockClient((request) async {
          expect(request.url.toString(),
              '$_testBaseUrl/cn-database/env408-zh-CN/expansions/lflist.conf');
          return _ok('#name 408 Banlist\n');
        });

        final client = createClient(mockClient);
        final lflist = await client.fetchLflist408();

        expect(lflist.name, '408 Banlist');
      });
    });

    group('fetchStrings', () {
      test('parses key=value pairs', () async {
        mockClient = MockClient((_) async {
          return _ok('!system\n# comment line\nsystem_100=duel\nsystem_101=deck\n');
        });

        final client = createClient(mockClient);
        final strings = await client.fetchStrings();

        expect(strings['system_100'], 'duel');
        expect(strings['system_101'], 'deck');
        expect(strings.containsKey('system'), isFalse);
        expect(strings.containsKey('# comment'), isFalse);
      });

      test('handles empty content', () async {
        mockClient = MockClient((_) => Future.value(_ok('')));
        final client = createClient(mockClient);
        final strings = await client.fetchStrings();
        expect(strings, isEmpty);
      });
    });

    group('fetchPreReleaseCards', () {
      test('parses JSON array', () async {
        mockClient = MockClient((_) async {
          return _ok(jsonEncode([
            {'code': 100, 'name': 'PreRelease A', 'type': 0x11},
            {'code': 200, 'name': 'PreRelease B', 'type': 0x21},
          ]));
        });

        final client = createClient(mockClient);
        final cards = await client.fetchPreReleaseCards();

        expect(cards.length, 2);
        expect(cards[0].code, 100);
        expect(cards[0].name, 'PreRelease A');
        expect(cards[1].code, 200);
        expect(cards[1].name, 'PreRelease B');
      });

      test('returns empty list when response is not array', () async {
        mockClient = MockClient(
          (_) => Future.value(_ok(jsonEncode({'msg': 'ok'}))),
        );
        final client = createClient(mockClient);
        final cards = await client.fetchPreReleaseCards();
        expect(cards, isEmpty);
      });
    });

    group('fetchPreReleaseVersion', () {
      test('returns version string', () async {
        mockClient = MockClient(
          (_) => Future.value(_ok('v2024.01.01\n')),
        );
        final client = createClient(mockClient);
        final version = await client.fetchPreReleaseVersion();

        expect(version, 'v2024.01.01');
      });
    });

    group('fetchCardDatabase', () {
      test('returns binary bytes', () async {
        final bytes = [0x53, 0x51, 0x4C, 0x69, 0x74, 0x65]; // "SQLite"
        mockClient = MockClient(
          (_) => Future.value(http.Response.bytes(bytes, 200)),
        );
        final client = createClient(mockClient);
        final result = await client.fetchCardDatabase();

        expect(result, bytes);
      });
    });

    group('getCardImageUrl', () {
      test('returns correct URL', () {
        final client = createClient(MockClient((_) async => _ok('')));
        expect(client.getCardImageUrl(89631139),
            '$_testBaseUrl/images/ygopro-images-zh-CN/89631139.jpg');
      });
    });

    group('getPreReleaseCardImageUrl', () {
      test('returns correct URL', () {
        final client = createClient(MockClient((_) async => _ok('')));
        expect(client.getPreReleaseCardImageUrl(12345),
            '$_testBaseUrl/ygopro-super-pre/data/pics/12345.jpg');
      });
    });

    group('network error handling', () {
      test('maps ClientException to networkError', () async {
        mockClient = MockClient((_) => throw http.ClientException('Connection refused'));
        final client = createClient(mockClient);

        expect(
          () => client.fetchLflist(),
          throwsA(
            isA<YgoCardDeckException>()
                .having((e) => e.type, 'type', YgoCardDeckErrorType.networkError)
                .having((e) => e.message, 'message', 'Connection refused'),
          ),
        );
      });

      test('maps generic exception to unknown', () async {
        mockClient = MockClient((_) => throw Exception('Something wrong'));
        final client = createClient(mockClient);

        expect(
          () => client.fetchStrings(),
          throwsA(
            isA<YgoCardDeckException>()
                .having((e) => e.type, 'type', YgoCardDeckErrorType.unknown),
          ),
        );
      });
    });

    group('constructor defaults', () {
      test('accepts custom timeout', () {
        final client = CardApiClient(
          baseUrl: _testBaseUrl,
          timeout: const Duration(seconds: 5),
        );
        expect(client.timeout.inSeconds, 5);
      });

      test('dispose closes http client', () async {
        mockClient = MockClient((_) async => _ok(''));
        final client = createClient(mockClient);
        client.dispose();
      });
    });
  });
}
