import 'dart:math';
import 'package:flutter/material.dart';

enum CardType { monster, spell, trap }

enum BattlePosition { attack, defense }

class DuelCard {
  final String id;
  final String name;
  final String enName;
  final CardType type;
  final String attr;
  final int level;
  final int atk;
  final int def;
  final String glyph;
  final Color artColor;
  final Color artColor2;

  BattlePosition position = BattlePosition.attack;
  bool faceDown = false;
  bool used = false;
  bool posChanged = false;

  DuelCard({
    required this.id,
    required this.name,
    required this.enName,
    required this.type,
    required this.attr,
    required this.level,
    required this.atk,
    required this.def,
    required this.glyph,
    required this.artColor,
    required this.artColor2,
  });

  bool get isMonster => type == CardType.monster;
  bool get isAttack => position == BattlePosition.attack;
  bool get isFaceUp => !faceDown;

  Color get typeColor => switch (type) {
        CardType.monster => const Color(0xFFD4A843),
        CardType.spell => const Color(0xFF28C878),
        CardType.trap => const Color(0xFFC840D8),
      };

  static DuelCard preview() => DuelCard(
        id: '_back',
        name: '',
        enName: '',
        type: CardType.monster,
        attr: '',
        level: 0,
        atk: 0,
        def: 0,
        glyph: '',
        artColor: const Color(0xFF3A2154),
        artColor2: const Color(0xFF180C28),
      );
}

class _Def {
  final String name;
  final String enName;
  final CardType type;
  final String attr;
  final int level;
  final int atk;
  final int def;
  final String glyph;
  final Color c1;
  final Color c2;

  const _Def(this.name, this.enName, this.type, this.attr, this.level, this.atk,
      this.def, this.glyph, this.c1, this.c2);
}

abstract final class CardDb {
  static const Map<String, _Def> _defs = {
    'ra': _Def('太阳神之翼神龙', 'THE WINGED DRAGON OF RA', CardType.monster, '神', 10, 4000, 4000,
        '☀', Color(0xFFFFD700), Color(0xFF8B4513)),
    'obelisk': _Def('欧贝利斯克之巨神兵', 'OBELISK THE TORMENTOR', CardType.monster, '神', 10, 4000, 4000,
        '▲', Color(0xFF4169E1), Color(0xFF1A1A4A)),
    'slifer': _Def('奥西里斯之天空龙', 'SLIFER THE SKY DRAGON', CardType.monster, '神', 10, 4000, 4000,
        '☁', Color(0xFFDC143C), Color(0xFF4A0A0A)),
    'bmg': _Def('青眼白龙', 'BLUE-EYES WHITE DRAGON', CardType.monster, '光', 8, 3000, 2500,
        '◈', Color(0xFF4A9AFF), Color(0xFF0A1A3A)),
    'dm': _Def('黑魔导', 'DARK MAGICIAN', CardType.monster, '暗', 7, 2500, 2100,
        '✦', Color(0xFF8A2BE2), Color(0xFF1A0A2A)),
    'cel': _Def('青眼精灵龙', 'BLUE-EYES SPIRIT DRAGON', CardType.monster, '光', 9, 2500, 3000,
        '✧', Color(0xFF87CEEB), Color(0xFF1A2A4A)),
    'red': _Def('真红眼黑龙', 'RED-EYES BLACK DRAGON', CardType.monster, '暗', 7, 2400, 2000,
        '◆', Color(0xFFDC143C), Color(0xFF1A0A0A)),
    'kuriboh': _Def('栗子球', 'KURIBOH', CardType.monster, '暗', 1, 300, 200,
        '●', Color(0xFF8B4513), Color(0xFF3A2A1A)),
    'pot': _Def('强欲之壶', 'POT OF GREED', CardType.spell, '', 0, 0, 0,
        '⚱', Color(0xFF28C878), Color(0xFF0A2A1A)),
    'darkhole': _Def('黑洞', 'DARK HOLE', CardType.spell, '', 0, 0, 0,
        '◉', Color(0xFF4A0A6A), Color(0xFF0A0A1A)),
    'monsterreborn': _Def('死者苏生', 'MONSTER REBORN', CardType.spell, '', 0, 0, 0,
        '⚚', Color(0xFF28C878), Color(0xFF1A2A0A)),
    'mystical': _Def('旋风', 'MYSTICAL SPACE TYPHOON', CardType.spell, '', 0, 0, 0,
        '✹', Color(0xFF28C878), Color(0xFF0A1A2A)),
    'mirror': _Def('神圣防护罩-反射镜力-', 'MIRROR FORCE', CardType.trap, '', 0, 0, 0,
        '⬡', Color(0xFFC840D8), Color(0xFF2A0A2A)),
    'trapdust': _Def('落穴', 'TRAP HOLE', CardType.trap, '', 0, 0, 0,
        '◍', Color(0xFFC840D8), Color(0xFF1A0A1A)),
    'solemn': _Def('神之宣告', 'SOLEMN JUDGMENT', CardType.trap, '', 0, 0, 0,
        '⚖', Color(0xFFC840D8), Color(0xFF0A0A2A)),
  };

  static const List<String> _monsterPool = [
    'bmg', 'dm', 'red', 'cel', 'kuriboh',
  ];

  static DuelCard make(String id) {
    final d = _defs[id]!;
    return DuelCard(
      id: id,
      name: d.name,
      enName: d.enName,
      type: d.type,
      attr: d.attr,
      level: d.level,
      atk: d.atk,
      def: d.def,
      glyph: d.glyph,
      artColor: d.c1,
      artColor2: d.c2,
    );
  }

  static List<DuelCard> buildDeck([Random? rng]) {
    final r = rng ?? Random();
    final ids = <String>[];
    for (final id in _monsterPool) {
      ids.add(id);
      ids.add(id);
      ids.add(id);
    }
    ids.add('ra');
    ids.add('obelisk');
    ids.add('slifer');
    for (final id in ['pot', 'darkhole', 'monsterreborn', 'mystical', 'mirror', 'trapdust', 'solemn']) {
      ids.add(id);
      ids.add(id);
    }
    ids.shuffle(r);
    return ids.map(make).toList();
  }
}
