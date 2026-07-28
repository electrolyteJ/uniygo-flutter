/// Pure Dart model representing a Yu-Gi-Oh! card, combining fields from
/// the `datas` and `texts` tables of a ygopro cards.cdb.
///
/// Mirrors the C-level [CardData] struct in ocgcore_bindings_generated.dart.
class CardInfo {
  /// 8-digit card code (passcode).
  final int code;

  /// Original (alias) code — 0 if this is not an alt-art/reprint.
  final int alias;

  /// 16 × 16-bit setcodes packed into an int. Use [setcodeAt] to extract.
  final int setcode;

  /// Bitmask of card types (monster/spell/trap/pendulum/link/…).
  /// See [CardType] constants in ocgcore_constants.dart.
  final int type;

  /// Attack points (negative for "?").
  final int atk;

  /// Defense / Link rating (negative for "?").
  final int def;

  /// Level (for normal monsters) or Rank (for Xyz) or Link rating (for Links).
  /// The meaning depends on [type].  Pendulum scales are NOT stored here;
  /// ocgcore encodes them separately in lscale / rscale of the CardData struct.
  final int level;

  /// Card race (e.g. dragon, spellcaster).  See common.h in ocgcore.
  final int race;

  /// Card attribute (e.g. DARK, LIGHT).  See common.h in ocgcore.
  final int attribute;

  /// OCG/TCG limit status (0 = OCG, 1 = TCG, 2 = OCG+TCG, …).
  final int ot;

  /// Effect-category bitmask used by some search implementations.
  final int category;

  /// Localised name (from texts.name).
  final String name;

  /// Localised effect / flavour text (from texts.desc).
  final String desc;

  /// Optional effect string parameters (str1…str16).  Most cards leave these
  /// empty; they carry formatted infos like pendulum scales or archetype
  /// conditions for a subset of cards.
  final List<String?> strings;

  const CardInfo({
    required this.code,
    required this.alias,
    required this.setcode,
    required this.type,
    required this.atk,
    required this.def,
    required this.level,
    required this.race,
    required this.attribute,
    required this.ot,
    required this.category,
    required this.name,
    required this.desc,
    required this.strings,
  });

  /// Extract the n-th 16-bit setcode (0 ≤ n < 16).
  int setcodeAt(int n) {
    assert(n >= 0 && n < 16);
    return (setcode >> (n * 16)) & 0xFFFF;
  }

  // ---------------------------------------------------------------------------
  // Type helpers (matches TYPE_* in ocgcore_constants.dart)
  // ---------------------------------------------------------------------------

  bool get isMonster => type & 0x1 != 0;
  bool get isSpell => type & 0x2 != 0;
  bool get isTrap => type & 0x4 != 0;
  bool get isNormal => type & 0x10 != 0;
  bool get isEffect => type & 0x20 != 0;
  bool get isFusion => type & 0x40 != 0;
  bool get isRitual => type & 0x80 != 0;
  bool get isSpirit => type & 0x200 != 0;
  bool get isUnion => type & 0x400 != 0;
  bool get isDual => type & 0x800 != 0;
  bool get isTuner => type & 0x1000 != 0;
  bool get isSynchro => type & 0x2000 != 0;
  bool get isToken => type & 0x4000 != 0;
  bool get isQuickPlay => type & 0x10000 != 0;
  bool get isContinuous => type & 0x20000 != 0;
  bool get isEquip => type & 0x40000 != 0;
  bool get isField => type & 0x80000 != 0;
  bool get isCounter => type & 0x100000 != 0;
  bool get isFlip => type & 0x200000 != 0;
  bool get isToon => type & 0x400000 != 0;
  bool get isXyz => type & 0x800000 != 0;
  bool get isPendulum => type & 0x1000000 != 0;
  bool get isLink => type & 0x4000000 != 0;

  /// Human-readable card kind (for debug / UI labels).
  String get kindLabel {
    if (isLink) return 'Link';
    if (isXyz) return 'Xyz';
    if (isSynchro) return 'Synchro';
    if (isFusion) return 'Fusion';
    if (isRitual) return 'Ritual';
    if (isPendulum && !isMonster) return 'Pendulum';
    if (isMonster) {
      final buf = <String>[];
      if (isNormal) buf.add('Normal');
      if (isEffect) buf.add('Effect');
      if (isTuner) buf.add('Tuner');
      if (isPendulum) buf.add('Pendulum');
      return buf.isEmpty ? 'Monster' : buf.join(' ');
    }
    if (isSpell) {
      if (isQuickPlay) return 'Quick-Play';
      if (isContinuous) return 'Continuous';
      if (isEquip) return 'Equip';
      if (isField) return 'Field';
      if (isRitual) return 'Ritual';
      if (isCounter) return 'Counter';
      return 'Spell';
    }
    if (isTrap) {
      if (isContinuous) return 'Continuous';
      if (isCounter) return 'Counter';
      return 'Trap';
    }
    return '?';
  }

  @override
  String toString() => 'CardInfo($code, $name, $kindLabel)';

  @override
  bool operator ==(Object other) =>
      other is CardInfo && other.code == code;

  @override
  int get hashCode => code.hashCode;

  String get raceText {
    const races = {
      0x1: '战士', 0x2: '魔法师', 0x4: '天使', 0x8: '恶魔',
      0x10: '不死', 0x20: '机械', 0x40: '水族', 0x80: '炎族',
      0x100: '岩石', 0x200: '鸟兽', 0x400: '植物', 0x800: '昆虫',
      0x1000: '雷族', 0x2000: '龙', 0x4000: '兽', 0x8000: '兽战士',
      0x10000: '恐龙', 0x20000: '鱼', 0x40000: '海龙', 0x80000: '爬虫类',
      0x100000: '念动力', 0x200000: '幻神', 0x400000: '创造神',
      0x800000: '幻龙', 0x1000000: '电子界', 0x2000000: '幻兽神',
    };
    return races[race] ?? '未知';
  }

  String get typeText {
    List<String> types = [];
    if (isMonster) types.add('怪兽');
    if (isSpell) types.add('魔法');
    if (isTrap) types.add('陷阱');
    if (isNormal) types.add('通常');
    if (isEffect) types.add('效果');
    if (isFusion) types.add('融合');
    if (isRitual) types.add('仪式');
    if (isSynchro) types.add('同调');
    if (isXyz) types.add('XYZ');
    if (isLink) types.add('连接');
    if (isPendulum) types.add('灵摆');
    return types.join(' ');
  }

  String get attributeText {
    switch (attribute) {
      case 0x01: return '地';
      case 0x02: return '水';
      case 0x04: return '炎';
      case 0x08: return '风';
      case 0x10: return '光';
      case 0x20: return '暗';
      case 0x40: return '神';
      default: return '无';
    }
  }

  // String get attributeText {
  //   switch (attribute) {
  //     case 0x01: return 'EARTH';
  //     case 0x02: return 'WATER';
  //     case 0x04: return 'FIRE';
  //     case 0x08: return 'WIND';
  //     case 0x10: return 'LIGHT';
  //     case 0x20: return 'DARK';
  //     case 0x40: return 'DIVINE';
  //     default: return 'NONE';
  //   }
  // }
  //
  // String get raceText {
  //   const races = {
  //     0x1: 'Warrior', 0x2: 'Spellcaster', 0x4: 'Fairy', 0x8: 'Fiend',
  //     0x10: 'Zombie', 0x20: 'Machine', 0x40: 'Aqua', 0x80: 'Pyro',
  //     0x100: 'Rock', 0x200: 'Winged Beast', 0x400: 'Plant', 0x800: 'Insect',
  //     0x1000: 'Thunder', 0x2000: 'Dragon', 0x4000: 'Beast', 0x8000: 'Beast-Warrior',
  //     0x10000: 'Dinosaur', 0x20000: 'Fish', 0x40000: 'Sea Serpent', 0x80000: 'Reptile',
  //     0x100000: 'Psychic', 0x200000: 'Divine-Beast', 0x400000: 'Creator God',
  //     0x800000: 'Wyrm', 0x1000000: 'Cyberse', 0x2000000: 'Illusion',
  //   };
  //   return races[race] ?? 'Unknown';
  // }
}
