import 'package:test/test.dart';
import 'package:ygo_card_deck/models/card_info.dart';

void main() {
  group('CardInfo', () {
    group('fromJson', () {
      test('parses complete monster card', () {
        final json = <String, dynamic>{
          'code': 89631139,
          'alias': 0,
          'setcode': [0x3008, 0x0],
          'type': 0x11, // Monster + Normal
          'level': 8,
          'attribute': 0x10, // LIGHT
          'race': 0x2000, // Dragon
          'attack': 3000,
          'defense': 2500,
          'name': '青眼白龙',
          'desc': '以高攻击力著称的传说之龙。',
        };

        final card = CardInfo.fromJson(json);

        expect(card.code, 89631139);
        expect(card.alias, 0);
        expect(card.setcode, [0x3008, 0x0]);
        expect(card.type, 0x11);
        expect(card.level, 8);
        expect(card.attribute, 0x10);
        expect(card.race, 0x2000);
        expect(card.attack, 3000);
        expect(card.defense, 2500);
        expect(card.lscale, 0);
        expect(card.rscale, 0);
        expect(card.linkMarker, 0);
        expect(card.name, '青眼白龙');
        expect(card.desc, '以高攻击力著称的传说之龙。');
      });

      test('parses spell card', () {
        final json = <String, dynamic>{
          'code': 83764718,
          'type': 0x02 | 0x10000, // Spell + QuickPlay
          'name': '禁忌的一滴',
          'desc': '从自己手卡·场上把任意数量的卡送去墓地才能发动。',
        };

        final card = CardInfo.fromJson(json);

        expect(card.isSpell, isTrue);
        expect(card.isMonster, isFalse);
        expect(card.typeText, contains('魔法'));
      });

      test('parses trap card', () {
        final json = <String, dynamic>{
          'code': 5318639,
          'type': 0x04 | 0x20000, // Trap + Continuous
          'name': '技能抽取',
        };

        final card = CardInfo.fromJson(json);

        expect(card.isTrap, isTrue);
        expect(card.isMonster, isFalse);
      });

      test('parses link monster', () {
        final json = <String, dynamic>{
          'code': 82044279,
          'type': 0x01 | 0x20 | 0x4000000, // Monster + Effect + Link
          'attack': 3000,
          'linkMarker': 0x002 | 0x008 | 0x020, // bottom + left + right
          'link_marker': null, // null fallback
          'name': '解码语者',
        };

        final card = CardInfo.fromJson(json);

        expect(card.isLink, isTrue);
        // linkMarker obtained from json via linkMarker first, then link_marker
        expect(card.linkMarker, 0x02A);
        expect(card.level, 0); // Links have no level
      });

      test('parses xyz monster', () {
        final json = <String, dynamic>{
          'code': 48905153,
          'type': 0x01 | 0x20 | 0x800000, // Monster + Effect + XYZ
          'level': -4, // Rank 4
          'name': 'No.39 希望皇霍普',
        };

        final card = CardInfo.fromJson(json);

        expect(card.isXyz, isTrue);
        expect(card.level, -4);
      });

      test('parses pendulum monster', () {
        final json = <String, dynamic>{
          'code': 16195942,
          'type': 0x01 | 0x20 | 0x1000000, // Monster + Effect + Pendulum
          'lscale': 8,
          'rscale': 1,
          'level': 4,
          'name': '娱乐伙伴 骷髅杂技小丑',
        };

        final card = CardInfo.fromJson(json);

        expect(card.isPendulum, isTrue);
        expect(card.lscale, 8);
        expect(card.rscale, 1);
      });

      test('handles null / missing fields gracefully', () {
        final json = <String, dynamic>{};

        final card = CardInfo.fromJson(json);

        expect(card.code, 0);
        expect(card.name, '');
        expect(card.desc, '');
        expect(card.setcode, [0]); // single-element fallback when not List
        expect(card.type, 0);
        expect(card.level, 0);
        expect(card.attack, 0);
        expect(card.defense, 0);
      });

      test('handles setcode as single int', () {
        final json = <String, dynamic>{
          'code': 12345,
          'setcode': 0x86,
          'name': 'Test',
        };

        final card = CardInfo.fromJson(json);
        expect(card.setcode, [0x86]);
      });

      test('handles atk/def field names', () {
        final json = <String, dynamic>{
          'code': 100,
          'atk': 1800,
          'def': 1200,
          'name': 'Test Monster',
        };

        final card = CardInfo.fromJson(json);

        expect(card.attack, 1800);
        expect(card.defense, 1200);
      });
    });

    group('toJson', () {
      test('roundtrips through toJson/fromJson', () {
        final original = CardInfo(
          code: 89631139,
          alias: 0,
          setcode: [0x3008],
          type: 0x11,
          level: 8,
          attribute: 0x10,
          race: 0x2000,
          attack: 3000,
          defense: 2500,
          lscale: 0,
          rscale: 0,
          linkMarker: 0,
          name: '青眼白龙',
          desc: '传说之龙',
        );

        final json = original.toJson();
        final restored = CardInfo.fromJson(json);

        expect(restored.code, original.code);
        expect(restored.name, original.name);
        expect(restored.type, original.type);
        expect(restored.attack, original.attack);
        expect(restored.defense, original.defense);
      });
    });

    group('type helpers', () {
      test('normal monster', () {
        final card = CardInfo(code: 1, type: 0x11); // Monster + Normal
        expect(card.isMonster, isTrue);
        expect(card.isNormal, isTrue);
        expect(card.isEffect, isFalse);
        expect(card.typeText, contains('通常'));
      });

      test('effect fusion monster', () {
        final card = CardInfo(code: 2, type: 0x01 | 0x20 | 0x40); // M+E+Fusion
        expect(card.isMonster, isTrue);
        expect(card.isEffect, isTrue);
        expect(card.isFusion, isTrue);
        expect(card.isSynchro, isFalse);
        expect(card.typeText, contains('融合'));
      });

      test('synchro tuner monster', () {
        final card = CardInfo(
          code: 3,
          type: 0x01 | 0x20 | 0x2000 | 0x1000, // M+E+Synchro+Tuner
        );
        expect(card.isSynchro, isTrue);
      });

      test('spell field card', () {
        final card = CardInfo(
          code: 4,
          type: 0x02 | 0x80000, // Spell + Field
        );
        expect(card.isSpell, isTrue);
        expect(card.isMonster, isFalse);
        expect(card.typeText, contains('场地'));
      });
    });

    group('attributeText', () {
      test('returns correct Chinese name', () {
        expect(CardInfo(code: 1, type: 0, attribute: 0x01).attributeText, '地');
        expect(CardInfo(code: 2, type: 0, attribute: 0x02).attributeText, '水');
        expect(CardInfo(code: 3, type: 0, attribute: 0x04).attributeText, '炎');
        expect(CardInfo(code: 4, type: 0, attribute: 0x08).attributeText, '风');
        expect(CardInfo(code: 5, type: 0, attribute: 0x10).attributeText, '光');
        expect(CardInfo(code: 6, type: 0, attribute: 0x20).attributeText, '暗');
        expect(CardInfo(code: 7, type: 0, attribute: 0x40).attributeText, '神');
        expect(CardInfo(code: 8, type: 0, attribute: 0).attributeText, '无');
        expect(CardInfo(code: 9, type: 0, attribute: 0xFF).attributeText, '无');
      });
    });

    group('raceText', () {
      test('returns correct Chinese name', () {
        expect(
          CardInfo(code: 1, type: 0, race: 0x1).raceText,
          '战士',
        );
        expect(
          CardInfo(code: 2, type: 0, race: 0x2000).raceText,
          '龙',
        );
        expect(
          CardInfo(code: 3, type: 0, race: 0x2).raceText,
          '魔法师',
        );
        expect(
          CardInfo(code: 4, type: 0, race: 0x1000000).raceText,
          '电子界',
        );
        expect(
          CardInfo(code: 5, type: 0, race: 0).raceText,
          '未知',
        );
        expect(
          CardInfo(code: 6, type: 0, race: 0xDEADBEEF).raceText,
          '未知',
        );
      });
    });

    group('equality', () {
      test('two cards with same code are equal', () {
        final a = CardInfo(code: 100, name: 'A', type: 1);
        final b = CardInfo(code: 100, name: 'B', type: 2);
        expect(a, equals(b));
      });

      test('two cards with different code are not equal', () {
        final a = CardInfo(code: 100, name: 'A', type: 1);
        final b = CardInfo(code: 200, name: 'A', type: 1);
        expect(a, isNot(equals(b)));
      });
    });
  });
}
