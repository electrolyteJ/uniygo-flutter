import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resource_data/ygo_card_deck_exception.dart';
import 'package:resource_deck_mdpro3/services/deck_api_client.dart';
import 'package:test/test.dart';

/// 真实抓取的 YGOMobile 信封格式（zgai.tech:38443 / rarnu.xyz:38383）
const _listEnvelope = {
  'code': 0,
  'message': '',
  'data': {
    'current': 1,
    'size': 2,
    'total': 9133,
    'pages': 4567,
    'records': [
      {
        'deckId': 'f3787c0258',
        'deckContributor': '周顺拐',
        'deckName': '不可见白森俱舍',
        'deckLike': 4,
        'deckCoverCard1': 60145298,
        'deckCoverCard2': 0,
        'deckCoverCard3': 0,
        'deckCase': 0,
        'deckProtector': 0,
        'lastDate': 1788046554000,
        'userId': 1151700,
      },
      {
        'deckId': 'fbcce4fd33',
        'deckContributor': '持恒',
        'deckName': '纯巧40go',
        'deckLike': 0,
        'deckCoverCard1': 0,
        'deckCoverCard2': 0,
        'deckCoverCard3': 0,
        'deckCase': 1080001,
        'deckProtector': 1070001,
        'lastDate': 1788010044321,
        'userId': 1069818,
      },
    ],
  },
};

const _detailEnvelope = {
  'code': 0,
  'message': '',
  'data': {
    'deckId': 'f3787c0258',
    'deckContributor': '周顺拐',
    'deckName': '不可见白森俱舍',
    'deckType': '',
    'deckRank': 0,
    'deckLike': 4,
    'deckUploadDate': 1787994726584,
    'deckUpdateDate': 1788046554000,
    'deckCoverCard1': 60145298,
    'deckCase': 0,
    'deckProtector': 0,
    'deckYdk': '#created by ygomobile\n'
        '#main\n'
        '60145298\n60145298\n21637502\n'
        '#extra\n'
        '80845034\n'
        '#side\n'
        '69540484\n69540484\n',
  },
};

/// 自建服务（servers/ygo_deck_server）平铺格式
const _flatList = {
  'decks': [
    {
      'deckId': 'demo',
      'name': '青眼白龙demo',
      'contributor': 'tester',
      'likeCount': 3,
      'isPublic': true,
      'rank': 0,
      'coverCode': 89631139,
      'updatedAt': '2024-01-01T00:00:00.000',
      'description': '',
    },
  ],
  'page': 1,
  'size': 20,
  'total': 1,
};

DeckApiClient _clientWith(Object body, {int status = 200}) => DeckApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

void main() {
  group('YGOMobile 信封格式', () {
    test('fetchDeckList 解析 records 分页', () async {
      final page = await _clientWith(_listEnvelope).fetchDeckList();
      expect(page.page, 1);
      expect(page.size, 2);
      expect(page.total, 9133);
      expect(page.decks, hasLength(2));

      final first = page.decks[0];
      expect(first.deckId, 'f3787c0258');
      expect(first.name, '不可见白森俱舍');
      expect(first.contributor, '周顺拐');
      expect(first.likeCount, 4);
      expect(first.coverCode, 60145298);
      expect(first.updatedAt, isNotNull);

      // deckCoverCard1 为 0 且只有卡套 deckCase 时：卡套非卡牌编号，
      // 不作为封面卡图使用，coverCode 为 null（展示层渲染占位图）。
      expect(page.decks[1].coverCode, isNull);
    });

    test('fetchDeckDetail 解析 deckYdk 卡表', () async {
      final deck =
          await _clientWith(_detailEnvelope).fetchDeckDetail('f3787c0258');
      expect(deck.deckId, 'f3787c0258');
      expect(deck.name, '不可见白森俱舍');
      expect(deck.contributor, '周顺拐');
      expect(deck.likeCount, 4);
      expect(deck.coverCode, 60145298);
      expect(deck.mainCount, 3);
      expect(deck.extraCount, 1);
      expect(deck.sideCount, 2);
      // 重复卡合并数量
      final white = deck.mainDeck.firstWhere((c) => c.code == 60145298);
      expect(white.count, 2);
      final side = deck.sideDeck.single;
      expect(side.code, 69540484);
      expect(side.count, 2);
    });

    test('generateDeckId 解包字符串 data', () async {
      final id = await _clientWith({
        'code': 0,
        'message': '',
        'data': 'e022e583d5',
      }).generateDeckId();
      expect(id, 'e022e583d5');
    });

    test('fetchUserDecks 解析信封列表', () async {
      final decks = await _clientWith({
        'code': 0,
        'message': '',
        'data': [(_listEnvelope['data']! as Map)['records']![0]],
      }).fetchUserDecks(userId: 1151700, token: 'x');
      expect(decks, hasLength(1));
      expect(decks[0].deckId, 'f3787c0258');
      expect(decks[0].name, '不可见白森俱舍');
      expect(decks[0].contributor, '周顺拐');
    });

    test('likeDeck 业务码非 0 时抛出服务端消息', () async {
      final api = _clientWith({'code': 10, 'message': '点赞过于频繁，请于 10 分钟后再试', 'data': null});
      expect(
        () => api.likeDeck('f3787c0258'),
        throwsA(
          isA<YgoCardDeckException>()
              .having((e) => e.type, 'type', YgoCardDeckErrorType.serverError)
              .having((e) => e.message, 'message', contains('点赞过于频繁')),
        ),
      );
    });
  });

  group('平铺格式（自建服务兼容）', () {
    test('fetchDeckList 解析 {decks, page, size, total}', () async {
      final page = await _clientWith(_flatList).fetchDeckList();
      expect(page.total, 1);
      expect(page.decks.single.name, '青眼白龙demo');
      expect(page.decks.single.coverCode, 89631139);
    });
  });

  group('错误处理', () {
    test('HTTP 5xx 抛 serverError', () {
      final api = _clientWith({}, status: 500);
      expect(
        () => api.fetchDeckList(),
        throwsA(isA<YgoCardDeckException>().having(
            (e) => e.type, 'type', YgoCardDeckErrorType.serverError)),
      );
    });

    test('非 JSON 响应抛 parseError', () {
      final api = DeckApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async => http.Response('ok', 200)),
      );
      expect(
        () => api.fetchDeckList(),
        throwsA(isA<YgoCardDeckException>()),
      );
    });
  });
}
