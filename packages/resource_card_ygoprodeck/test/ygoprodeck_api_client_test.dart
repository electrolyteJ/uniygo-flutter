import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:resource_card_ygoprodeck/src/ygoprodeck_api_client.dart';

/// 真实 API 响应样本（2026-08 取自 db.ygoprodeck.com/api/v7）。
const _blueEyes = '''
{"id":89631139,"name":"Blue-Eyes White Dragon","typeline":["Dragon","Normal"],"type":"Normal Monster","humanReadableCardType":"Normal Monster","frameType":"normal","desc":"This legendary dragon is a powerful engine of destruction.","race":"Dragon","atk":3000,"def":2500,"level":8,"attribute":"LIGHT","archetype":"Blue-Eyes","card_images":[{"id":89631139,"image_url":"https://images.ygoprodeck.com/images/cards/89631139.jpg","image_url_small":"https://images.ygoprodeck.com/images/cards_small/89631139.jpg","image_url_cropped":"https://images.ygoprodeck.com/images/cards_cropped/89631139.jpg"}]}
''';

const _decodeTalker = '''
{"id":1861629,"name":"Decode Talker","type":"Link Monster","typeline":["Cyberse","Link","Effect"],"frameType":"link","desc":"2+ Effect Monsters","race":"Cyberse","atk":2300,"def":null,"linkval":3,"linkmarkers":["Top","Bottom-Left","Bottom-Right"],"attribute":"DARK","archetype":"Decode Talker"}
''';

const _oddEyes = '''
{"id":16178681,"name":"Odd-Eyes Pendulum Dragon","type":"Pendulum Effect Monster","typeline":["Dragon","Pendulum","Effect"],"frameType":"pendulum_effect","desc":"Pendulum Effect... Monster Effect...","race":"Dragon","atk":2500,"def":2000,"level":7,"scale":4,"attribute":"DARK"}
''';

const _raigeki = '''
{"id":12580477,"name":"Raigeki","type":"Spell Card","humanReadableCardType":"Normal Spell","frameType":"spell","desc":"Destroy all monsters your opponent controls.","race":"Normal"}
''';

void main() {
  group('YgoprodeckApiClient.parseCard（真实样本驱动）', () {
    test('青眼白龙：通常怪兽全字段', () {
      final card = YgoprodeckApiClient.parseCardFromJson(_blueEyes);
      expect(card, isNotNull);
      expect(card!.code, 89631139);
      expect(card.name, 'Blue-Eyes White Dragon');
      expect(card.type, 0x1 | 0x10); // MONSTER|NORMAL
      expect(card.level, 8);
      expect(card.attribute, 0x10); // LIGHT
      expect(card.race, 0x2000); // Dragon
      expect(card.attack, 3000);
      expect(card.defense, 2500);
      expect(card.desc, contains('legendary dragon'));
    });

    test('Decode Talker：Link 怪无 def、linkval 作 level、标记位解析', () {
      final card = YgoprodeckApiClient.parseCardFromJson(_decodeTalker);
      expect(card, isNotNull);
      expect(card!.code, 1861629);
      expect(card.type, 0x1 | 0x4000000 | 0x20); // MONSTER|LINK|EFFECT
      expect(card.level, 3); // cdb 惯例：Link 怪的 level 字段存 linkval
      expect(card.defense, 0);
      expect(card.linkMarker, 0x085); // TOP|BOTTOM_LEFT|BOTTOM_RIGHT
      expect(card.race, 0x1000000); // Cyberse
    });

    test('灵摆怪：scale 写入 lscale/rscale', () {
      final card = YgoprodeckApiClient.parseCardFromJson(_oddEyes);
      expect(card, isNotNull);
      expect(card!.type, 0x1 | 0x1000000 | 0x20); // MONSTER|PENDULUM|EFFECT
      expect(card.level, 7);
      expect(card.lscale, 4);
      expect(card.rscale, 4);
    });

    test('魔法卡：race "Normal" 不进 race 字段', () {
      final card = YgoprodeckApiClient.parseCardFromJson(_raigeki);
      expect(card, isNotNull);
      expect(card!.type, 0x2); // TYPE_SPELL
      expect(card.race, 0);
      expect(card.level, 0);
      expect(card.attack, 0);
      expect(card.defense, 0);
    });

    test('错误响应（{"error": ...}）返回 null', () {
      final card = YgoprodeckApiClient.parseCardFromJson(
        '{"error":"No card matching your query was found in the database."}',
      );
      expect(card, isNull);
    });
  });

  group('apiFrameTypeOf（位掩码 → API type 反查）', () {
    test('主类别映射', () {
      expect(YgoprodeckApiClient.apiFrameTypeOf(0x2), 'Spell Card');
      expect(YgoprodeckApiClient.apiFrameTypeOf(0x4), 'Trap Card');
      expect(YgoprodeckApiClient.apiFrameTypeOf(0x4000000), 'Link Monster');
      expect(YgoprodeckApiClient.apiFrameTypeOf(0x800000), 'XYZ Monster');
      expect(YgoprodeckApiClient.apiFrameTypeOf(0x2000), 'Synchro Monster');
      expect(YgoprodeckApiClient.apiFrameTypeOf(0x40), 'Fusion Monster');
      expect(YgoprodeckApiClient.apiFrameTypeOf(0x80), 'Ritual Monster');
    });

    test('通常/效果怪兽严格区分（0x10/0x20）', () {
      expect(YgoprodeckApiClient.apiFrameTypeOf(0x1 | 0x10), 'Normal Monster');
      expect(YgoprodeckApiClient.apiFrameTypeOf(0x1 | 0x20), 'Effect Monster');
    });

    test('泛型无法映射返回 null（不窄化/丢弃过滤条件）', () {
      expect(YgoprodeckApiClient.apiFrameTypeOf(0x1), isNull); // 全部怪兽
      expect(YgoprodeckApiClient.apiFrameTypeOf(0x1000000), isNull); // 全部灵摆
      expect(YgoprodeckApiClient.apiFrameTypeOf(null), isNull);
    });
  });

  group('请求参数（MockClient）', () {
    test('searchCards 传 num 参数（maxResults 生效，默认页大小仅 10）', () async {
      Uri? captured;
      final client = YgoprodeckApiClient(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response('{"data":[]}', 200);
        }),
      );
      await client.searchCards('blue-eyes', maxResults: 42);
      expect(captured!.queryParameters['fname'], 'blue-eyes');
      expect(captured!.queryParameters['num'], '42');
    });

    test('searchCombined 传 num 参数；空条件不发请求', () async {
      Uri? captured;
      final client = YgoprodeckApiClient(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response('{"data":[]}', 200);
        }),
      );
      await client.searchCombined(cardType: 0x1 | 0x10, maxResults: 30);
      expect(captured!.queryParameters['type'], 'Normal Monster');
      expect(captured!.queryParameters['num'], '30');

      captured = null;
      expect(await client.searchCombined(), isEmpty);
      expect(captured, isNull); // 空条件不发请求
    });
  });

  group('卡图 CDN', () {
    test('卡图 URL 按 code 直出（无需请求）', () {
      expect(
        YgoprodeckApiClient.cardImageUrl(89631139),
        'https://images.ygoprodeck.com/images/cards/89631139.jpg',
      );
      expect(
        YgoprodeckApiClient.cardImageUrl(89631139, small: true),
        'https://images.ygoprodeck.com/images/cards_small/89631139.jpg',
      );
    });
  });
}
