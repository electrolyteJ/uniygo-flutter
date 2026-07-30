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
  final String art;
  final String glyph;
  final String flavor;

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
    required this.art,
    required this.glyph,
    required this.flavor,
  });

  bool get isMonster => type == CardType.monster;
}

class _Def {
  final String name;
  final String enName;
  final CardType type;
  final String attr;
  final int level;
  final int atk;
  final int def;
  final String art;
  final String glyph;
  final String flavor;

  const _Def(this.name, this.enName, this.type, this.attr, this.level, this.atk,
      this.def, this.art, this.glyph, this.flavor);
}

abstract final class CardDb {
  static const Map<String, _Def> _defs = {
    'ra': _Def('太阳神之使徒', 'APOSTLE OF RA', CardType.monster, '光', 8, 3000, 2500,
        'sun', '☀', '黎明升起之时,吾主之眼将照彻一切虚妄。'),
    'serpent': _Def('虚空蛇神', 'VOID SERPENT', CardType.monster, '暗', 6, 2400, 1800,
        'void', '☽', '它自星隙游出,吞噬光年如同饮露。'),
    'drake': _Def('星辉龙', 'ASTRAL DRAKE', CardType.monster, '光', 7, 2600, 2000,
        'astral', '✶', '以银河为巢,以彗尾为翼。'),
    'gargoyle': _Def('黑曜石像鬼', 'OBSIDIAN GARGOYLE', CardType.monster, '地', 4, 1700, 1200,
        'obsidian', '◈', '神殿沉睡千年,唯它仍在守望。'),
    'hawk': _Def('雷霆战鹰', 'THUNDER HAWK', CardType.monster, '风', 4, 1800, 1000,
        'storm', 'ϟ', '风暴是它的猎场,雷鸣是它的号角。'),
    'wraith': _Def('沙漠亡魂', 'DESERT WRAITH', CardType.monster, '暗', 3, 1200, 800,
        'dune', '☥', '迷途者啊,随钟声归于流沙。'),
    'crab': _Def('深渊巨蟹', 'ABYSS CRAB', CardType.monster, '水', 2, 800, 1600,
        'abyss', '◬', '深海的钳,夹碎过无数锚与梦。'),
    'solar': _Def('日轮祝福', 'SOLAR BLESSING', CardType.spell, '', 0, 0, 0,
        'spell-sun', '✹', '我回复 1500 点生命值。'),
    'time': _Def('时之砂', 'SANDS OF TIME', CardType.spell, '', 0, 0, 0,
        'spell-time', '⧗', '从卡组抽取两张牌。'),
    'obelisk': _Def('方尖碑之力', 'OBELISK FORCE', CardType.spell, '', 0, 0, 0,
        'spell-obelisk', '▲', '我方场上全部怪兽攻击力上升 800。'),
    'rebirth': _Def('冥界复活', 'NETHER REBIRTH', CardType.spell, '', 0, 0, 0,
        'spell-rebirth', '⚚', '从墓地特殊召唤一只怪兽。'),
    'voidhole': _Def('湮灭黑洞', 'OBLIVION VOID', CardType.spell, '', 0, 0, 0,
        'spell-voidhole', '◉', '破坏场上全部怪兽。'),
    'scarab': _Def('圣甲虫护盾', 'SCARAB SHIELD', CardType.trap, '', 0, 0, 0,
        'trap-scarab', '⬡', '使对手的一次攻击无效。'),
    'quicksand': _Def('流沙咒缚', 'QUICKSAND CURSE', CardType.trap, '', 0, 0, 0,
        'trap-sand', '◍', '破坏一只正在攻击的怪兽。'),
  };

  static const List<String> _monsterPool = [
    'serpent', 'drake', 'gargoyle', 'hawk', 'wraith', 'crab', 'ra',
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
      art: d.art,
      glyph: d.glyph,
      flavor: d.flavor,
    );
  }

  static List<DuelCard> buildDeck([Random? rng]) {
    final r = rng ?? Random();
    final ids = <String>[];
    for (final id in _monsterPool) {
      ids.add(id);
      ids.add(id);
    }
    for (final id in ['solar', 'time', 'obelisk', 'rebirth', 'voidhole', 'scarab', 'quicksand']) {
      ids.add(id);
      ids.add(id);
    }
    ids.add('ra');
    ids.shuffle(r);
    return ids.map(make).toList();
  }

  static List<Gradient> artGradients(String key) {
    switch (key) {
      case 'sun':
        return [
          const RadialGradient(
              center: Alignment(0, -0.12),
              colors: [Color(0xFFFFF7D0), Color(0xFFFFD75E), Color(0xFFFF9A2E), Color(0xFF7A3C10), Color(0xFF3A1C08)],
              stops: [0, 0.28, 0.55, 0.82, 1]),
          const SweepGradient(colors: [
            Color(0x47FFDC78), Color(0x00FFDC78), Color(0x47FFDC78), Color(0x00FFDC78),
            Color(0x47FFDC78), Color(0x00FFDC78), Color(0x47FFDC78), Color(0x00FFDC78), Color(0x47FFDC78),
          ]),
        ];
      case 'void':
        return [
          const LinearGradient(
              begin: Alignment(-0.7, -1),
              end: Alignment(0.7, 1),
              colors: [Color(0xFF1A1038), Color(0xFF080618), Color(0xFF241238)]),
          const RadialGradient(
              center: Alignment(-0.4, -0.44), radius: 0.7,
              colors: [Color(0x803FE0FF), Colors.transparent]),
          const RadialGradient(
              center: Alignment(0.36, 0.4), radius: 0.8,
              colors: [Color(0x8CB45AFF), Colors.transparent]),
        ];
      case 'astral':
        return [
          const RadialGradient(
              center: Alignment(0, -0.2),
              colors: [Color(0xFF3A5BD9), Color(0xFF101A4A), Color(0xFF060A24)]),
          const RadialGradient(
              center: Alignment(-0.5, -0.5), radius: 0.2,
              colors: [Color(0xCCFFFFFF), Colors.transparent]),
          const RadialGradient(
              center: Alignment(0.45, 0.2), radius: 0.16,
              colors: [Color(0x99CFE9FF), Colors.transparent]),
        ];
      case 'obsidian':
        return [
          const LinearGradient(
              begin: Alignment(-1, -1),
              end: Alignment(1, 1),
              colors: [Color(0xFF2A2F3A), Color(0xFF0C0F16), Color(0xFF3A4150), Color(0xFF12151D), Color(0xFF0C0F16)]),
        ];
      case 'storm':
        return [
          const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A4A6A), Color(0xFF1A2438), Color(0xFF0C1220)]),
          const LinearGradient(
              begin: Alignment(-0.6, -1),
              end: Alignment(0.6, 1),
              stops: [0.42, 0.46, 0.52, 0.6, 0.63, 0.68],
              colors: [Colors.transparent, Color(0xBFFFF096), Colors.transparent, Colors.transparent, Color(0x80FFF096), Colors.transparent]),
        ];
      case 'dune':
        return [
          const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8C078), Color(0xFFC9982F), Color(0xFF8A6A2A), Color(0xFF5E4818)]),
          const RadialGradient(
              center: Alignment(0, -0.32), radius: 0.5,
              colors: [Color(0xD9140A1E), Colors.transparent]),
        ];
      case 'abyss':
        return [
          const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0E3A5A), Color(0xFF061A30), Color(0xFF03101E)]),
          const RadialGradient(
              center: Alignment(-0.4, -0.4), radius: 0.4,
              colors: [Color(0x6678DCFF), Colors.transparent]),
          const RadialGradient(
              center: Alignment(0.36, 0.2), radius: 0.3,
              colors: [Color(0x4D78DCFF), Colors.transparent]),
        ];
      case 'spell-sun':
        return [
          const RadialGradient(
              colors: [Color(0xFFFFF7D0), Color(0xFFFFD75E), Color(0xFFB98A2E), Color(0xFF5E4818)],
              stops: [0, 0.3, 0.62, 1]),
          const SweepGradient(colors: [
            Color(0x59FFE9A8), Color(0x00FFE9A8), Color(0x59FFE9A8), Color(0x00FFE9A8),
            Color(0x59FFE9A8), Color(0x00FFE9A8), Color(0x59FFE9A8),
          ]),
        ];
      case 'spell-time':
        return [
          const RadialGradient(colors: [Color(0xFF06231A), Color(0xFF031510)]),
          const SweepGradient(colors: [
            Color(0xFF2EE8A0), Colors.transparent, Color(0xFF2EE8A0), Colors.transparent, Color(0xFF2EE8A0),
          ], stops: [0, 0.3, 0.5, 0.8, 1]),
        ];
      case 'spell-obelisk':
        return [
          const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4A5A7A), Color(0xFF242C44), Color(0xFF10141F)]),
          const LinearGradient(
              begin: Alignment(-0.8, -1),
              end: Alignment(0.8, 1),
              stops: [0.44, 0.5, 0.56],
              colors: [Colors.transparent, Color(0xD9FFE9A8), Colors.transparent]),
        ];
      case 'spell-rebirth':
        return [
          const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1C0C34), Color(0xFF0A0618), Color(0xFF101A12)]),
          const RadialGradient(
              center: Alignment(0, 0.4), radius: 0.7,
              colors: [Color(0x805CFFB0), Colors.transparent]),
          const RadialGradient(
              center: Alignment(0, -0.4), radius: 0.7,
              colors: [Color(0x66B45AFF), Colors.transparent]),
        ];
      case 'spell-voidhole':
        return [
          const RadialGradient(
              colors: [Color(0xFF000000), Color(0xFF2A0C4A), Color(0xFF0A0418)],
              stops: [0.18, 0.55, 1]),
          const SweepGradient(colors: [
            Color(0x80783CC8), Color(0xCC0A0519), Color(0x80783CC8), Color(0xCC0A0519),
            Color(0x80783CC8), Color(0xCC0A0519), Color(0x80783CC8),
          ]),
        ];
      case 'trap-scarab':
        return [
          const RadialGradient(colors: [Color(0xFF3A0C34), Color(0xFF1C061A)]),
          const RadialGradient(colors: [
            Color(0x66E84BD8), Colors.transparent, Color(0x66E84BD8), Colors.transparent,
            Color(0x66E84BD8), Colors.transparent,
          ], stops: [0, 0.2, 0.4, 0.6, 0.8, 1]),
        ];
      case 'trap-sand':
        return [
          const RadialGradient(colors: [Color(0xFF1C1206), Color(0xFF0C0803)]),
          const SweepGradient(colors: [
            Color(0x80C9982F), Color(0x993C280C), Color(0x80C9982F), Color(0x993C280C),
            Color(0x80C9982F), Color(0x993C280C), Color(0x80C9982F),
          ]),
        ];
      default:
        return [const LinearGradient(colors: [Color(0xFF222222), Color(0xFF111111)])];
    }
  }
}
