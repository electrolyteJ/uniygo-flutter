import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:ygo_card_yugipedia/src/card_table2_parser.dart';
import 'package:ygo_card_yugipedia/src/yugipedia_api_client.dart';

/// 真实 wikitext 样本（2026-08 取自 yugipedia.com/api.php，节选核心字段）。
const _blueEyesWikitext = '''
{{CardTable2
| fr_name               = Dragon Blanc aux Yeux Bleus
| ja_name               = {{Ruby|青眼の白龍|ブルーアイズ・ホワイト・ドラゴン}}
| tc_name               = 青眼白龍
| sc_name               = 青眼白龙
| attribute             = LIGHT
| types                 = Dragon / Normal
| level                 = 8
| atk                   = 3000
| def                   = 2500
| password              = 89631139
| text                  = ''This legendary [[dragon]] is a powerful engine of [[Burst Stream of Destruction|destruction]].''
| tc_text               = 以高攻擊力著稱的傳說之龍。任何對手都能夠粉碎，其破壞力不可估量。
| sc_text               = 以高攻击力著称的传说之龙。任何对手都能粉碎，其破坏力不可估量。
| database_id           = 4040
}}
''';

const _raigekiWikitext = '''
{{CardTable2
| sc_name               = 雷击
| card_type             = Spell
| property              = Normal
| password              = 12580477
| text                  = ''Destroy all [[Monster Card|monsters]] your opponent [[control]]s.''
| sc_text               = 对方场上的怪兽全部破坏。
}}
''';

const _decodeTalkerWikitext = '''
{{CardTable2
| sc_name               = 解码语者
| attribute             = DARK
| types                 = Cyberse / Link / Effect
| link_arrows           = Top, Bottom-Left, Bottom-Right
| atk                   = 2300
| password              = 01861629
| text                  = ''2+ [[Effect Monster]]s''
| sc_text               = 效果怪兽２只以上
}}
''';

void main() {
  group('CardTable2Parser（真实 wikitext 驱动）', () {
    test('青眼白龙：字段/中文名/中文文本/类型映射', () {
      final card = CardTable2Parser.parse(
        _blueEyesWikitext,
        pageTitle: 'Blue-Eyes White Dragon',
      );
      expect(card, isNotNull);
      expect(card!.info.code, 89631139);
      expect(card.info.name, '青眼白龙'); // 优先简体中文名
      expect(card.nameEn, 'Blue-Eyes White Dragon'); // 页面标题传入
      expect(card.info.desc, '以高攻击力著称的传说之龙。任何对手都能粉碎，其破坏力不可估量。');
      expect(card.info.type, 0x1 | 0x10); // MONSTER|NORMAL
      expect(card.info.level, 8);
      expect(card.info.attribute, 0x10); // LIGHT
      expect(card.info.race, 0x2000); // Dragon
      expect(card.info.attack, 3000);
      expect(card.info.defense, 2500);
    });

    test('Raigeki：card_type=Spell + property=Normal', () {
      final card = CardTable2Parser.parse(_raigekiWikitext);
      expect(card, isNotNull);
      expect(card!.info.code, 12580477);
      expect(card.info.name, '雷击');
      expect(card.info.type, 0x2); // TYPE_SPELL
      expect(card.info.race, 0);
      expect(card.info.desc, '对方场上的怪兽全部破坏。');
    });

    test('解码语者：Link 怪（link_arrows、无 def/level、密码补零）', () {
      final card = CardTable2Parser.parse(_decodeTalkerWikitext);
      expect(card, isNotNull);
      expect(card!.info.code, 1861629); // 前导零剥除
      expect(card.info.type, 0x1 | 0x4000000 | 0x20); // MONSTER|LINK|EFFECT
      expect(card.info.linkMarker, 0x085);
      expect(card.info.defense, 0);
      expect(card.info.race, 0x1000000); // Cyberse
    });

    test('非卡页（无 CardTable2）返回 null', () {
      expect(CardTable2Parser.parse('{{About|the card}}'), isNull);
      expect(CardTable2Parser.parse(''), isNull);
    });

    test('英文 text 中的 wiki 标记被清洗（[[x|y]]→y、斜体）', () {
      final card = CardTable2Parser.parse(
        _blueEyesWikitext,
        pageTitle: 'Blue-Eyes White Dragon',
        preferChinese: false,
      );
      expect(card, isNotNull);
      expect(card!.info.name, 'Blue-Eyes White Dragon');
      expect(
        card.info.desc,
        'This legendary dragon is a powerful engine of destruction.',
      );
    });

    test('中文文本中的 wiki 标记同样被清洗', () {
      final card = CardTable2Parser.parse('''
{{CardTable2
| sc_name               = 测试卡
| card_type             = Spell
| password              = 1
| sc_text               = 破坏对方场上的[[Monster Card|怪兽]]。
| tc_text               = 破壞對方場上的[[Monster Card|怪獸]]。
}}
''');
      expect(card, isNotNull);
      expect(card!.info.desc, '破坏对方场上的怪兽。');
      expect(card.nameSc, '测试卡');
    });
  });

  group('YugipediaApiClient 响应解析（MW 1.31 结构）', () {
    // JSON 字符串不能含裸换行：wikitext 为真实样本，外层 JSON 用
    // jsonEncode 构造（结构与 MW 1.31 响应一致）。
    String wrapQuery({
      String title = 'Blue-Eyes White Dragon',
      String wikitext = _blueEyesWikitext,
      List<Map<String, String>>? redirects,
    }) {
      return jsonEncode({
        'batchcomplete': '',
        'query': {
          'redirects': ?redirects,
          'pages': {
            '30': {
              'pageid': 30,
              'ns': 0,
              'title': title,
              'revisions': [
                {'contentformat': 'text/x-wiki', '*': wikitext},
              ],
            },
          },
        },
      });
    }

    test('redirects=1：卡密重定向到卡页并解析', () {
      final response = wrapQuery(
        redirects: [
          {'from': '89631139', 'to': 'Blue-Eyes White Dragon'},
        ],
      );
      final card = YugipediaApiClient.parseQueryResponse(response);
      expect(card, isNotNull);
      expect(card!.info.code, 89631139);
      expect(card.info.name, '青眼白龙');
    });

    test('页面不存在（missing）返回 null', () {
      const response =
          '{"batchcomplete":"","query":{"pages":{"-1":{"ns":0,"title":"Nocard","missing":""}}}}';
      expect(YugipediaApiClient.parseQueryResponse(response), isNull);
    });

    test('prefixsearch 结果提取标题列表', () {
      const response = '''
{"batchcomplete":"","query":{"prefixsearch":[{"ns":0,"title":"Blue-Eyes"},{"ns":0,"title":"Blue-Eyes Abyss Dragon"}]}}
''';
      expect(YugipediaApiClient.parsePrefixSearch(response), [
        'Blue-Eyes',
        'Blue-Eyes Abyss Dragon',
      ]);
    });

    test('searchCards 结果按 prefixsearch 顺序重排（pages 按 pageid 返回）', () async {
      const abyssWikitext = '''
{{CardTable2
| sc_name               = 渊眼白龙
| attribute             = LIGHT
| types                 = Dragon / Effect
| level                 = 10
| password              = 22804410
}}
''';
      final client = YugipediaApiClient(
        client: MockClient((request) async {
          final params = request.url.queryParameters;
          if (params['list'] == 'prefixsearch') {
            return http.Response(
              jsonEncode({
                'query': {
                  'prefixsearch': [
                    {'ns': 0, 'title': 'Blue-Eyes Abyss Dragon'},
                    {'ns': 0, 'title': 'Blue-Eyes White Dragon'},
                  ],
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          // 批量拉取：pages 故意按 pageid 反序（与 prefixsearch 顺序相反）
          return http.Response(
            jsonEncode({
              'query': {
                'pages': {
                  '30': {
                    'pageid': 30,
                    'ns': 0,
                    'title': 'Blue-Eyes White Dragon',
                    'revisions': [
                      {'*': _blueEyesWikitext},
                    ],
                  },
                  '9': {
                    'pageid': 9,
                    'ns': 0,
                    'title': 'Blue-Eyes Abyss Dragon',
                    'revisions': [
                      {'*': abyssWikitext},
                    ],
                  },
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final cards = await client.searchCards('Blue-Eyes');
      expect(cards.map((c) => c.nameEn), [
        'Blue-Eyes Abyss Dragon',
        'Blue-Eyes White Dragon',
      ]);
      // 中文名随排序一起保持对应
      expect(cards.map((c) => c.info.name), ['渊眼白龙', '青眼白龙']);
    });
  });
}
