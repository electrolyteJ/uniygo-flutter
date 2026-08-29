import 'package:test/test.dart';
import 'package:resource_card_ygoprodeck/src/ocg_strings.dart';

void main() {
  group('ocgAttributeOf', () {
    test('标准七属性映射', () {
      expect(ocgAttributeOf('EARTH'), 0x01);
      expect(ocgAttributeOf('WATER'), 0x02);
      expect(ocgAttributeOf('FIRE'), 0x04);
      expect(ocgAttributeOf('WIND'), 0x08);
      expect(ocgAttributeOf('LIGHT'), 0x10);
      expect(ocgAttributeOf('DARK'), 0x20);
      expect(ocgAttributeOf('DIVINE'), 0x40);
    });

    test('未知属性返回 0 而非抛异常', () {
      expect(ocgAttributeOf('LAUGH'), 0);
      expect(ocgAttributeOf(null), 0);
    });
  });

  group('ocgRaceOf（怪兽种族）', () {
    test('常见种族', () {
      expect(ocgRaceOf('Dragon'), 0x2000);
      expect(ocgRaceOf('Warrior'), 0x1);
      expect(ocgRaceOf('Spellcaster'), 0x2);
      expect(ocgRaceOf('Cyberse'), 0x1000000);
      expect(ocgRaceOf('Illusion'), 0x2000000);
      expect(ocgRaceOf('Winged Beast'), 0x200);
      expect(ocgRaceOf('Beast-Warrior'), 0x8000);
    });

    test('未知种族返回 0', () {
      expect(ocgRaceOf('Unknown'), 0);
    });
  });

  group('ocgLinkMarkersOf（以仓库 ocgcore 常量为准）', () {
    test('Decode Talker：Top + Bottom-Left + Bottom-Right', () {
      // TOP 0x080 | BOTTOM_LEFT 0x001 | BOTTOM_RIGHT 0x004
      expect(
        ocgLinkMarkersOf(const ['Top', 'Bottom-Left', 'Bottom-Right']),
        0x085,
      );
    });

    test('空列表/未知标记 → 0', () {
      expect(ocgLinkMarkersOf(const []), 0);
      expect(ocgLinkMarkersOf(const ['Center']), 0);
    });
  });

  group('ocgTypeOf（type 字符串 + typeline 合并推断）', () {
    test('Normal Monster → MONSTER|NORMAL', () {
      expect(
        ocgTypeOf(type: 'Normal Monster', typeline: const ['Dragon', 'Normal']),
        0x1 | 0x10,
      );
    });

    test('Pendulum Effect Monster → MONSTER|PENDULUM|EFFECT', () {
      expect(
        ocgTypeOf(
          type: 'Pendulum Effect Monster',
          typeline: const ['Dragon', 'Pendulum', 'Effect'],
        ),
        0x1 | 0x1000000 | 0x20,
      );
    });

    test('Link Monster（typeline 含 Effect）→ MONSTER|LINK|EFFECT', () {
      expect(
        ocgTypeOf(
          type: 'Link Monster',
          typeline: const ['Cyberse', 'Link', 'Effect'],
        ),
        0x1 | 0x4000000 | 0x20,
      );
    });

    test('Spell Card → TYPE_SPELL（无 MONSTER 位）', () {
      expect(ocgTypeOf(type: 'Spell Card', typeline: null), 0x2);
    });

    test('Trap Card + Counter 属性 → TRAP|COUNTER', () {
      expect(
        ocgTypeOf(type: 'Trap Card', typeline: null, spellTrapRace: 'Counter'),
        0x4 | 0x100000,
      );
    });

    test('Quick-Play 魔法 → SPELL|QUICKPLAY', () {
      expect(
        ocgTypeOf(
          type: 'Spell Card',
          typeline: null,
          spellTrapRace: 'Quick-Play',
        ),
        0x2 | 0x10000,
      );
    });

    test('typeline 中的 Tuner/Flip/Toon/Gemini 等修饰位', () {
      expect(
        ocgTypeOf(
          type: 'Tuner Monster',
          typeline: const ['Warrior', 'Tuner', 'Effect'],
        ),
        0x1 | 0x1000 | 0x20,
      );
      // Gemini → TYPE_DUAL
      expect(
        ocgTypeOf(
          type: 'Gemini Monster',
          typeline: const ['Warrior', 'Gemini', 'Effect'],
        ),
        0x1 | 0x800 | 0x20,
      );
    });
  });
}
