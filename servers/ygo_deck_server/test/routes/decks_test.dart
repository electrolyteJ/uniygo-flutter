/// 卡组端点 handler 单测：每个端点的成功 / 404 / 400 路径，
/// 存储用临时目录隔离（DeckStore 为真实文件存储）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:ygo_deck_server/services/deck_store.dart';

import '../../routes/decks/index.dart' as decks_index;
import '../../routes/decks/[key]/index.dart' as deck_key;
import '../../routes/decks/[key]/ydk.dart' as deck_ydk;

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  late Directory tmp;
  late DeckStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ygo_deck_server_test');
    store = DeckStore(tmp.path);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  RequestContext ctx(String method, String path, {Object? body}) {
    final context = _MockRequestContext();
    when(() => context.read<DeckStore>()).thenReturn(store);
    when(() => context.request).thenReturn(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: body == null ? const {} : const {'content-type': 'application/json'},
        body: body,
      ),
    );
    return context;
  }

  const sampleDeck = {
    'deckName': '测试卡组',
    'mainDeck': [
      {'code': 89631139, 'count': 2},
      {'code': 46986414, 'count': 1},
    ],
    'extraDeck': [
      {'code': 86066372, 'count': 1},
    ],
    'sideDeck': <dynamic>[],
  };

  group('GET /decks', () {
    test('空列表', () async {
      final resp = await decks_index.onRequest(ctx('GET', '/decks'));
      expect(resp.statusCode, HttpStatus.ok);
      expect(await resp.json(), isEmpty);
    });

    test('保存后列出', () async {
      await store.save(DeckStore(tmp.path).importYdk('#main\n89631139\n', 'A'));
      final resp = await decks_index.onRequest(ctx('GET', '/decks'));
      final list = await resp.json() as List<dynamic>;
      expect(list, hasLength(1));
      expect((list.first as Map)['deckName'], 'A');
    });
  });

  group('POST /decks', () {
    test('保存成功', () async {
      final resp = await decks_index.onRequest(
        ctx('POST', '/decks', body: jsonEncode(sampleDeck)),
      );
      expect(resp.statusCode, HttpStatus.ok);
      final body = await resp.json() as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect(await store.read('测试卡组'), isNotNull);
    });

    test('非法 JSON → 400', () async {
      final resp = await decks_index.onRequest(
        ctx('POST', '/decks', body: '{broken'),
      );
      expect(resp.statusCode, HttpStatus.badRequest);
    });

    test('非对象 → 400', () async {
      final resp = await decks_index.onRequest(
        ctx('POST', '/decks', body: '[1,2]'),
      );
      expect(resp.statusCode, HttpStatus.badRequest);
    });

    test('缺 deckName → 400', () async {
      final resp = await decks_index.onRequest(
        ctx('POST', '/decks', body: jsonEncode({'mainDeck': <dynamic>[]})),
      );
      expect(resp.statusCode, HttpStatus.badRequest);
    });
  });

  group('GET /decks/:key', () {
    test('存在 → 200 + 完整 JSON（含 updatedAt）', () async {
      await decks_index.onRequest(ctx('POST', '/decks', body: jsonEncode(sampleDeck)));
      final resp = await deck_key.onRequest(ctx('GET', '/decks/x'), '测试卡组');
      expect(resp.statusCode, HttpStatus.ok);
      final body = await resp.json() as Map<String, dynamic>;
      expect(body['deckName'], '测试卡组');
      expect(body['mainCount'], 3);
      expect(body['extraCount'], 1);
      expect(body['sideCount'], 0);
      expect(body['updatedAt'], isNotNull);
      expect((body['mainDeck'] as List).first['code'], 89631139);
    });

    test('URL 编码 key（中文卡组名）→ 解码后读写', () async {
      final encoded = Uri.encodeComponent('青眼白龙');
      await deck_key.onRequest(
        ctx('PUT', '/decks/$encoded', body: jsonEncode(sampleDeck)),
        encoded,
      );
      final resp = await deck_key.onRequest(ctx('GET', '/decks/$encoded'), encoded);
      expect(resp.statusCode, HttpStatus.ok);
      final body = await resp.json() as Map<String, dynamic>;
      expect(body['deckName'], '青眼白龙');
      expect(await store.read('青眼白龙'), isNotNull);
    });

    test('不存在 → 404', () async {
      final resp = await deck_key.onRequest(ctx('GET', '/decks/ghost'), 'ghost');
      expect(resp.statusCode, HttpStatus.notFound);
    });

    test('非法 key → 400', () async {
      final resp = await deck_key.onRequest(ctx('GET', '/decks/x'), '..%2Fevil');
      expect(resp.statusCode, HttpStatus.badRequest);
    });
  });

  group('PUT /decks/:key', () {
    test('保存成功（路径 key 覆盖 body deckName）', () async {
      final resp = await deck_key.onRequest(
        ctx('PUT', '/decks/newdeck', body: jsonEncode(sampleDeck)),
        'newdeck',
      );
      expect(resp.statusCode, HttpStatus.ok);
      expect((await resp.json() as Map)['success'], isTrue);
      final saved = await store.read('newdeck');
      expect(saved, isNotNull);
      expect(saved!.deckName, 'newdeck');
      expect(saved.mainCount, 3);
    });

    test('非法 JSON → 400', () async {
      final resp = await deck_key.onRequest(
        ctx('PUT', '/decks/x', body: 'not json'),
        'x',
      );
      expect(resp.statusCode, HttpStatus.badRequest);
    });
  });

  group('DELETE /decks/:key', () {
    test('删除成功', () async {
      await deck_key.onRequest(
        ctx('PUT', '/decks/doomed', body: jsonEncode(sampleDeck)),
        'doomed',
      );
      final resp = await deck_key.onRequest(ctx('DELETE', '/decks/doomed'), 'doomed');
      expect(resp.statusCode, HttpStatus.ok);
      expect(await store.read('doomed'), isNull);
    });

    test('不存在 → 404', () async {
      final resp = await deck_key.onRequest(ctx('DELETE', '/decks/ghost'), 'ghost');
      expect(resp.statusCode, HttpStatus.notFound);
    });
  });

  group('YDK 端点', () {
    test('GET 导出：text/plain + 分段格式', () async {
      await deck_key.onRequest(
        ctx('PUT', '/decks/ydkdeck', body: jsonEncode(sampleDeck)),
        'ydkdeck',
      );
      final resp = await deck_ydk.onRequest(ctx('GET', '/decks/ydkdeck/ydk'), 'ydkdeck');
      expect(resp.statusCode, HttpStatus.ok);
      expect(resp.headers['content-type'], contains('text/plain'));
      final text = await resp.body();
      expect(text, startsWith('#created by uniygopro\n#main\n'));
      expect(text, contains('#extra\n'));
      expect(text, contains('!side\n'));
      // main：89631139×2 + 46986414×1
      expect('\n'.allMatches(text).length, greaterThanOrEqualTo(6));
      expect(text, contains('89631139\n89631139\n46986414'));
    });

    test('GET 不存在 → 404', () async {
      final resp = await deck_ydk.onRequest(ctx('GET', '/decks/ghost/ydk'), 'ghost');
      expect(resp.statusCode, HttpStatus.notFound);
    });

    test('POST 导入：YDK 文本 → 保存并返回卡组 JSON', () async {
      const ydk = '#created by x\n#main\n89631139\n89631139\n#extra\n86066372\n!side\n33396948\n';
      final resp = await deck_ydk.onRequest(
        ctx('POST', '/decks/imported/ydk', body: ydk),
        'imported',
      );
      expect(resp.statusCode, HttpStatus.ok);
      final body = await resp.json() as Map<String, dynamic>;
      expect(body['deckName'], 'imported');
      expect(body['mainCount'], 2);
      expect(body['extraCount'], 1);
      expect(body['sideCount'], 1);
      // 已落盘
      expect(await store.read('imported'), isNotNull);
    });

    test('POST 空 body → 400', () async {
      final resp = await deck_ydk.onRequest(
        ctx('POST', '/decks/x/ydk', body: ''),
        'x',
      );
      expect(resp.statusCode, HttpStatus.badRequest);
    });

    test('导出 → 导入往返一致', () async {
      await deck_key.onRequest(
        ctx('PUT', '/decks/roundtrip', body: jsonEncode(sampleDeck)),
        'roundtrip',
      );
      final exportResp = await deck_ydk.onRequest(
        ctx('GET', '/decks/roundtrip/ydk'),
        'roundtrip',
      );
      final ydk = await exportResp.body();
      final importResp = await deck_ydk.onRequest(
        ctx('POST', '/decks/roundtrip2/ydk', body: ydk),
        'roundtrip2',
      );
      final body = await importResp.json() as Map<String, dynamic>;
      expect(body['mainCount'], 3);
      expect(body['extraCount'], 1);
      expect(body['sideCount'], 0);
    });
  });

  group('方法不允许', () {
    test('PATCH /decks → 405', () async {
      final resp = await decks_index.onRequest(ctx('PATCH', '/decks'));
      expect(resp.statusCode, HttpStatus.methodNotAllowed);
    });
  });
}
