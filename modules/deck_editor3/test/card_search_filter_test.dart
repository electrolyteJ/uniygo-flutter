import 'package:deck_editor3/src/my_decks/card_search_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/card_info.dart';

CardInfo card(int type, {int attribute = 0, int race = 0}) => CardInfo(
      code: 1,
      type: type,
      attribute: attribute,
      race: race,
    );

void main() {
  group('CardSearchFilter 怪兽（属性+种族）', () {
    const filter = CardSearchFilter(
      monster: true,
      attributes: {0x02}, // 水
      races: {0x1}, // 战士
    );

    test('命中水属性战士族主卡组怪兽', () {
      expect(filter.matches(card(0x21, attribute: 0x02, race: 0x1)), isTrue);
    });

    test('不命中其他属性/种族', () {
      expect(
        filter.matches(card(0x21, attribute: 0x04, race: 0x1)),
        isFalse,
      );
      expect(
        filter.matches(card(0x21, attribute: 0x02, race: 0x2000)),
        isFalse,
      );
    });

    test('不命中融合怪兽（额外卡，非主卡组）', () {
      expect(filter.matches(card(0x41, attribute: 0x02, race: 0x1)), isFalse);
    });
  });

  group('CardSearchFilter 魔法子类', () {
    test('速攻魔法', () {
      const filter = CardSearchFilter(spell: true, spellTypes: {0x10000});
      expect(filter.matches(card(0x10002)), isTrue);
      expect(filter.matches(card(0x2)), isFalse); // 通常
      expect(filter.matches(card(0x20002)), isFalse); // 永续
    });

    test('通常魔法（无子类标志）', () {
      const filter = CardSearchFilter(spell: true, spellTypes: {0});
      expect(filter.matches(card(0x2)), isTrue);
      expect(filter.matches(card(0x10002)), isFalse);
    });

    test('装备魔法', () {
      const filter = CardSearchFilter(spell: true, spellTypes: {0x40000});
      expect(filter.matches(card(0x40002)), isTrue);
      expect(filter.matches(card(0x80002)), isFalse); // 场地
    });
  });

  group('CardSearchFilter 额外卡种类', () {
    test('融合', () {
      const filter = CardSearchFilter(extra: true, extraTypes: {0x40});
      expect(filter.matches(card(0x41)), isTrue);
      expect(filter.matches(card(0x2001)), isFalse); // 同调
      expect(filter.matches(card(0x800001)), isFalse); // 超量
    });

    test('连接', () {
      const filter = CardSearchFilter(extra: true, extraTypes: {0x4000000});
      expect(filter.matches(card(0x4000001)), isTrue);
      expect(filter.matches(card(0x41)), isFalse);
    });
  });

  group('CardSearchFilter 陷阱子类', () {
    test('反击陷阱', () {
      const filter = CardSearchFilter(trap: true, trapTypes: {0x100000});
      expect(filter.matches(card(0x100004)), isTrue);
      expect(filter.matches(card(0x4)), isFalse); // 通常
      expect(filter.matches(card(0x104)), isFalse); // 陷阱怪兽
    });

    test('陷阱怪兽', () {
      const filter = CardSearchFilter(trap: true, trapTypes: {0x100});
      expect(filter.matches(card(0x104)), isTrue);
      expect(filter.matches(card(0x4)), isFalse);
    });
  });

  group('CardSearchFilter 多类并集（同时请求）', () {
    const filter = CardSearchFilter(
      monster: true,
      spell: true,
      attributes: {0x02},
      races: {0x1},
      spellTypes: {0x10000},
    );

    test('怪兽(水+战士) 与 魔法(速攻) 同时命中', () {
      expect(filter.matches(card(0x21, attribute: 0x02, race: 0x1)), isTrue);
      expect(filter.matches(card(0x10002)), isTrue);
      expect(filter.matches(card(0x21, attribute: 0x04, race: 0x1)), isFalse);
      expect(filter.matches(card(0x2)), isFalse); // 通常魔法
    });

    test('魔法子类不影响怪兽筛选（不跨类）', () {
      // 水+战士怪兽命中，即使 spellTypes 只选了速攻
      expect(filter.matches(card(0x21, attribute: 0x02, race: 0x1)), isTrue);
      // 速攻魔法命中，即使 attributes/races 只选了水+战士
      expect(filter.matches(card(0x10002)), isTrue);
    });
  });

  test('空筛选命中一切', () {
    const filter = CardSearchFilter();
    expect(filter.isEmpty, isTrue);
    expect(filter.matches(card(0x21)), isTrue);
    expect(filter.matches(card(0x2)), isTrue);
    expect(filter.matches(card(0x4)), isTrue);
  });

  test('broadTypeMask 各大类粗筛掩码', () {
    expect(const CardSearchFilter(monster: true).broadTypeMask, 0x1);
    expect(const CardSearchFilter(spell: true).broadTypeMask, 0x2);
    expect(const CardSearchFilter(trap: true).broadTypeMask, 0x4);
    expect(
      const CardSearchFilter(extra: true).broadTypeMask,
      0x40 | 0x2000 | 0x800000 | 0x4000000,
    );
    expect(
      const CardSearchFilter(monster: true, spell: true).broadTypeMask,
      0x1 | 0x2,
    );
  });
}
