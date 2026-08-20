/// YGOPRODeck API 的英文字符串 → OCG 数值位掩码映射。
///
/// 数值以仓库 `packages/ocgcore/lib/ocgcore.dart` 的常量为准；
/// 本包保持纯数据客户端定位，不依赖 ocgcore（FFI/WASM 插件），
/// 故将所需映射表内联于此（仅字符串→位掩码，无逻辑耦合）。
library;

/// 属性：YGOPRODeck `attribute` 字段（怪兽专有）。
int ocgAttributeOf(String? value) => switch (value) {
  'EARTH' => 0x01,
  'WATER' => 0x02,
  'FIRE' => 0x04,
  'WIND' => 0x08,
  'LIGHT' => 0x10,
  'DARK' => 0x20,
  'DIVINE' => 0x40,
  _ => 0,
};

/// 怪兽种族：YGOPRODeck `race` 字段（怪兽时）。
int ocgRaceOf(String? value) => switch (value) {
  'Warrior' => 0x1,
  'Spellcaster' => 0x2,
  'Fairy' => 0x4,
  'Fiend' => 0x8,
  'Zombie' => 0x10,
  'Machine' => 0x20,
  'Aqua' => 0x40,
  'Pyro' => 0x80,
  'Rock' => 0x100,
  'Winged Beast' => 0x200,
  'Plant' => 0x400,
  'Insect' => 0x800,
  'Thunder' => 0x1000,
  'Dragon' => 0x2000,
  'Beast' => 0x4000,
  'Beast-Warrior' => 0x8000,
  'Dinosaur' => 0x10000,
  'Fish' => 0x20000,
  'Sea Serpent' => 0x40000,
  'Reptile' => 0x80000,
  'Psychic' => 0x100000,
  'Divine-Beast' => 0x200000,
  'Creator God' => 0x400000,
  'Wyrm' => 0x800000,
  'Cyberse' => 0x1000000,
  'Illusion' => 0x2000000,
  _ => 0,
};

/// Link 标记位（YGOPRODeck `linkmarkers` 数组元素 → 位）。
/// 数值与 ocgcore.dart 的 LINK_MARKER_* 一致（注意 0x010 为官方保留位）。
const _linkMarkerBits = <String, int>{
  'Bottom-Left': 0x001,
  'Bottom': 0x002,
  'Bottom-Right': 0x004,
  'Left': 0x008,
  'Right': 0x020,
  'Top-Left': 0x040,
  'Top': 0x080,
  'Top-Right': 0x100,
};

int ocgLinkMarkersOf(List<String> markers) {
  var bits = 0;
  for (final m in markers) {
    bits |= _linkMarkerBits[m] ?? 0;
  }
  return bits;
}

/// 怪兽类型修饰关键词（type 字符串与 typeline 数组合并扫描）。
const _typeKeywords = <String, int>{
  'Normal': 0x10, // TYPE_NORMAL
  'Effect': 0x20, // TYPE_EFFECT
  'Fusion': 0x40, // TYPE_FUSION
  'Ritual': 0x80, // TYPE_RITUAL
  'Spirit': 0x200, // TYPE_SPIRIT
  'Union': 0x400, // TYPE_UNION
  'Gemini': 0x800, // TYPE_DUAL
  'Tuner': 0x1000, // TYPE_TUNER
  'Synchro': 0x2000, // TYPE_SYNCHRO
  'Token': 0x4000, // TYPE_TOKEN
  'Flip': 0x200000, // TYPE_FLIP
  'Toon': 0x400000, // TYPE_TOON
  'Xyz': 0x800000, // TYPE_XYZ（YGOPRODeck 两种拼写都出现）
  'XYZ': 0x800000,
  'Pendulum': 0x1000000, // TYPE_PENDULUM
  'Link': 0x4000000, // TYPE_LINK
};

/// 魔法/陷阱的 property（YGOPRODeck 魔法陷阱的 `race` 字段承载）。
int ocgSpellTrapPropertyOf(String? property) => switch (property) {
  'Quick-Play' => 0x10000, // TYPE_QUICKPLAY
  'Continuous' => 0x20000, // TYPE_CONTINUOUS
  'Equip' => 0x40000, // TYPE_EQUIP
  'Field' => 0x80000, // TYPE_FIELD
  'Counter' => 0x100000, // TYPE_COUNTER
  'Ritual' => 0x80, // TYPE_RITUAL
  _ => 0,
};

/// 合成 CardInfo.type 位掩码。
///
/// - [type]：YGOPRODeck `type` 字段（如 "Pendulum Effect Monster" /
///   "Spell Card"）；
/// - [typeline]：怪兽的类型行（如 ["Cyberse","Link","Effect"]，
///   首元素为种族，扫描时不在关键词表中自然跳过）；
/// - [spellTrapRace]：魔法/陷阱的 `race` 字段（property）。
int ocgTypeOf({String? type, List<String>? typeline, String? spellTrapRace}) {
  final t = type ?? '';
  if (t.contains('Spell')) {
    return 0x2 | ocgSpellTrapPropertyOf(spellTrapRace); // TYPE_SPELL
  }
  if (t.contains('Trap')) {
    return 0x4 | ocgSpellTrapPropertyOf(spellTrapRace); // TYPE_TRAP
  }
  var bits = 0x1; // TYPE_MONSTER
  for (final src in [t, ...?typeline]) {
    for (final entry in _typeKeywords.entries) {
      if (src.contains(entry.key)) bits |= entry.value;
    }
  }
  return bits;
}
