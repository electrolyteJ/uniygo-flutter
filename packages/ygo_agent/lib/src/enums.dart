/// Enums and enum -> feature-id tables, ported 1:1 from ygo-agent
/// `ygoinf/models.py` (string values) and `ygoinf/features.py` (id tables).
library;

/// Parse helper shared by all wire-format enums.
T enumFromValue<T>(Map<String, T> table, String value, String what) {
  final result = table[value];
  if (result == null) {
    throw FormatException('Unknown $what value: "$value"');
  }
  return result;
}

enum Controller {
  me('me'),
  opponent('opponent');

  const Controller(this.value);
  final String value;

  static final Map<String, Controller> _byValue = {
    for (final e in values) e.value: e,
  };
  static Controller fromValue(String v) =>
      enumFromValue(_byValue, v, 'controller');
}

enum Location {
  deck('deck'),
  hand('hand'),
  mzone('mzone'),
  szone('szone'),
  grave('grave'),
  removed('removed'),
  extra('extra');

  const Location(this.value);
  final String value;

  static final Map<String, Location> _byValue = {
    for (final e in values) e.value: e,
  };
  static Location fromValue(String v) =>
      enumFromValue(_byValue, v, 'location');
}

enum Position {
  none('none'),
  faceupAttack('faceup_attack'),
  facedownAttack('facedown_attack'),
  attack('attack'),
  faceupDefense('faceup_defense'),
  faceup('faceup'),
  facedownDefense('facedown_defense'),
  facedown('facedown'),
  defense('defense');

  const Position(this.value);
  final String value;

  static final Map<String, Position> _byValue = {
    for (final e in values) e.value: e,
  };
  static Position fromValue(String v) => enumFromValue(_byValue, v, 'position');
}

enum Attribute {
  none('none'),
  earth('earth'),
  water('water'),
  fire('fire'),
  wind('wind'),
  light('light'),
  dark('dark'),
  divine('divine');

  const Attribute(this.value);
  final String value;

  static final Map<String, Attribute> _byValue = {
    for (final e in values) e.value: e,
  };
  static Attribute fromValue(String v) =>
      enumFromValue(_byValue, v, 'attribute');
}

enum Race {
  none('none'),
  warrior('warrior'),
  spellcaster('spellcaster'),
  fairy('fairy'),
  fiend('fiend'),
  zombie('zombie'),
  machine('machine'),
  aqua('aqua'),
  pyro('pyro'),
  rock('rock'),
  windbeast('windbeast'),
  plant('plant'),
  insect('insect'),
  thunder('thunder'),
  dragon('dragon'),
  beast('beast'),
  beastWarrior('beast_warrior'),
  dinosaur('dinosaur'),
  fish('fish'),
  seaSerpent('sea_serpent'),
  reptile('reptile'),
  psycho('psycho'),
  // Upstream spelling ("devine") kept for wire compatibility.
  devine('devine'),
  creatorGod('creator_god'),
  wyrm('wyrm'),
  cyberse('cyberse'),
  illusion('illusion');

  const Race(this.value);
  final String value;

  static final Map<String, Race> _byValue = {
    for (final e in values) e.value: e,
  };
  static Race fromValue(String v) => enumFromValue(_byValue, v, 'race');
}

/// Named `CardType` because `Type` collides with `dart:core.Type`.
enum CardType {
  monster('monster'),
  spell('spell'),
  trap('trap'),
  normal('normal'),
  effect('effect'),
  fusion('fusion'),
  ritual('ritual'),
  trapMonster('trap_monster'),
  spirit('spirit'),
  union('union'),
  dual('dual'),
  tuner('tuner'),
  synchro('synchro'),
  token('token'),
  quickPlay('quick_play'),
  continuous('continuous'),
  equip('equip'),
  field('field'),
  counter('counter'),
  flip('flip'),
  toon('toon'),
  xyz('xyz'),
  pendulum('pendulum'),
  special('special'),
  link('link');

  const CardType(this.value);
  final String value;

  static final Map<String, CardType> _byValue = {
    for (final e in values) e.value: e,
  };
  static CardType fromValue(String v) => enumFromValue(_byValue, v, 'type');
}

enum Phase {
  draw('draw'),
  standby('standby'),
  main1('main1'),
  battleStart('battle_start'),
  battleStep('battle_step'),
  damage('damage'),
  damageCalculation('damage_calculation'),
  battle('battle'),
  main2('main2'),
  end('end');

  const Phase(this.value);
  final String value;

  static final Map<String, Phase> _byValue = {
    for (final e in values) e.value: e,
  };
  static Phase fromValue(String v) => enumFromValue(_byValue, v, 'phase');
}

enum MsgName {
  selectIdlecmd('select_idlecmd'),
  selectChain('select_chain'),
  selectCard('select_card'),
  selectTribute('select_tribute'),
  selectPosition('select_position'),
  selectEffectyn('select_effectyn'),
  selectYesno('select_yesno'),
  selectBattlecmd('select_battlecmd'),
  selectUnselectCard('select_unselect_card'),
  selectOption('select_option'),
  selectPlace('select_place'),
  selectSum('select_sum'),
  selectDisfield('select_disfield'),
  announceAttrib('announce_attrib'),
  announceNumber('announce_number');

  const MsgName(this.value);
  final String value;

  static final Map<String, MsgName> _byValue = {
    for (final e in values) e.value: e,
  };
  static MsgName fromValue(String v) => enumFromValue(_byValue, v, 'msg_type');
}

enum ActionAct {
  none('none'),
  set('set'),
  reposition('reposition'),
  specialSummon('special_summon'),
  summonFaceupAttack('summon_faceup_attack'),
  summonFacedownDefense('summon_facedown_defense'),
  attack('attack'),
  directAttack('direct_attack'),
  activate('activate'),
  cancel('cancel');

  const ActionAct(this.value);
  final String value;

  static final Map<String, ActionAct> _byValue = {
    for (final e in values) e.value: e,
  };
  static ActionAct fromValue(String v) => enumFromValue(_byValue, v, 'act');
}

enum ActionPhase {
  none('none'),
  battle('battle'),
  main2('main2'),
  end('end');

  const ActionPhase(this.value);
  final String value;

  static final Map<String, ActionPhase> _byValue = {
    for (final e in values) e.value: e,
  };
  static ActionPhase fromValue(String v) =>
      enumFromValue(_byValue, v, 'action_phase');
}

enum ActionPlace {
  none('none'),
  m1('m1'), m2('m2'), m3('m3'), m4('m4'), m5('m5'), m6('m6'), m7('m7'),
  s1('s1'), s2('s2'), s3('s3'), s4('s4'), s5('s5'), s6('s6'), s7('s7'),
  s8('s8'),
  om1('om1'), om2('om2'), om3('om3'), om4('om4'), om5('om5'), om6('om6'),
  om7('om7'),
  os1('os1'), os2('os2'), os3('os3'), os4('os4'), os5('os5'), os6('os6'),
  os7('os7'), os8('os8');

  const ActionPlace(this.value);
  final String value;

  static final Map<String, ActionPlace> _byValue = {
    for (final e in values) e.value: e,
  };
  static ActionPlace fromValue(String v) =>
      enumFromValue(_byValue, v, 'action_place');
}

// ─────────────────────────────────────────────────────────────────────
// Feature id tables (features.py). Values are final; lookups use `!`
// exactly like Python's dict indexing (throws on missing keys).
// ─────────────────────────────────────────────────────────────────────

const Map<Location, int> locationToId = {
  Location.deck: 1,
  Location.hand: 2,
  Location.mzone: 3,
  Location.szone: 4,
  Location.grave: 5,
  Location.removed: 6,
  Location.extra: 7,
};

const Map<Controller, int> controllerToId = {
  Controller.me: 0,
  Controller.opponent: 1,
};

const Map<Position, int> positionToId = {
  Position.none: 0,
  Position.faceupAttack: 1,
  Position.facedownAttack: 2,
  Position.attack: 3,
  Position.faceupDefense: 4,
  Position.faceup: 5,
  Position.facedownDefense: 6,
  Position.facedown: 7,
  Position.defense: 8,
};

const Map<Attribute, int> attributeToId = {
  Attribute.none: 0,
  Attribute.earth: 1,
  Attribute.water: 2,
  Attribute.fire: 3,
  Attribute.wind: 4,
  Attribute.light: 5,
  Attribute.dark: 6,
  Attribute.divine: 7,
};

const Map<Race, int> raceToId = {
  Race.none: 0,
  Race.warrior: 1,
  Race.spellcaster: 2,
  Race.fairy: 3,
  Race.fiend: 4,
  Race.zombie: 5,
  Race.machine: 6,
  Race.aqua: 7,
  Race.pyro: 8,
  Race.rock: 9,
  Race.windbeast: 10,
  Race.plant: 11,
  Race.insect: 12,
  Race.thunder: 13,
  Race.dragon: 14,
  Race.beast: 15,
  Race.beastWarrior: 16,
  Race.dinosaur: 17,
  Race.fish: 18,
  Race.seaSerpent: 19,
  Race.reptile: 20,
  Race.psycho: 21,
  Race.devine: 22,
  Race.creatorGod: 23,
  Race.wyrm: 24,
  Race.cyberse: 25,
  Race.illusion: 26,
};

const Map<CardType, int> typeToId = {
  CardType.monster: 0,
  CardType.spell: 1,
  CardType.trap: 2,
  CardType.normal: 3,
  CardType.effect: 4,
  CardType.fusion: 5,
  CardType.ritual: 6,
  CardType.trapMonster: 7,
  CardType.spirit: 8,
  CardType.union: 9,
  CardType.dual: 10,
  CardType.tuner: 11,
  CardType.synchro: 12,
  CardType.token: 13,
  CardType.quickPlay: 14,
  CardType.continuous: 15,
  CardType.equip: 16,
  CardType.field: 17,
  CardType.counter: 18,
  CardType.flip: 19,
  CardType.toon: 20,
  CardType.xyz: 21,
  CardType.pendulum: 22,
  CardType.special: 23,
  CardType.link: 24,
};

const Map<Phase, int> phaseToId = {
  Phase.draw: 0,
  Phase.standby: 1,
  Phase.main1: 2,
  Phase.battleStart: 3,
  Phase.battleStep: 4,
  Phase.damage: 5,
  Phase.damageCalculation: 6,
  Phase.battle: 7,
  Phase.main2: 8,
  Phase.end: 9,
};

const Map<MsgName, int> msgToId = {
  MsgName.selectIdlecmd: 1,
  MsgName.selectChain: 2,
  MsgName.selectCard: 3,
  MsgName.selectTribute: 4,
  MsgName.selectPosition: 5,
  MsgName.selectEffectyn: 6,
  MsgName.selectYesno: 7,
  MsgName.selectBattlecmd: 8,
  MsgName.selectUnselectCard: 9,
  MsgName.selectOption: 10,
  MsgName.selectPlace: 11,
  MsgName.selectSum: 12,
  MsgName.selectDisfield: 13,
  MsgName.announceAttrib: 14,
  MsgName.announceNumber: 15,
};

const Map<ActionAct, int> actionActToId = {
  ActionAct.none: 0,
  ActionAct.set: 1,
  ActionAct.reposition: 2,
  ActionAct.specialSummon: 3,
  ActionAct.summonFaceupAttack: 4,
  ActionAct.summonFacedownDefense: 5,
  ActionAct.attack: 6,
  ActionAct.directAttack: 7,
  ActionAct.activate: 8,
  ActionAct.cancel: 9,
};

const Map<ActionPhase, int> actionPhaseToId = {
  ActionPhase.none: 0,
  ActionPhase.battle: 1,
  ActionPhase.main2: 2,
  ActionPhase.end: 3,
};

const Map<ActionPlace, int> placeToId = {
  ActionPlace.none: 0,
  ActionPlace.m1: 1,
  ActionPlace.m2: 2,
  ActionPlace.m3: 3,
  ActionPlace.m4: 4,
  ActionPlace.m5: 5,
  ActionPlace.m6: 6,
  ActionPlace.m7: 7,
  ActionPlace.s1: 8,
  ActionPlace.s2: 9,
  ActionPlace.s3: 10,
  ActionPlace.s4: 11,
  ActionPlace.s5: 12,
  ActionPlace.s6: 13,
  ActionPlace.s7: 14,
  ActionPlace.s8: 15,
  ActionPlace.om1: 16,
  ActionPlace.om2: 17,
  ActionPlace.om3: 18,
  ActionPlace.om4: 19,
  ActionPlace.om5: 20,
  ActionPlace.om6: 21,
  ActionPlace.om7: 22,
  ActionPlace.os1: 23,
  ActionPlace.os2: 24,
  ActionPlace.os3: 25,
  ActionPlace.os4: 26,
  ActionPlace.os5: 27,
  ActionPlace.os6: 28,
  ActionPlace.os7: 29,
  ActionPlace.os8: 30,
};

/// Upstream system string table. NOTE: 221 appears twice; the Python dict
/// comprehension keeps the LAST occurrence (i + 16 with the larger i), so
/// this map is built by iterating in order and overwriting duplicates.
const List<int> systemStrings = [
  1050, 1051, 1052, 1054, 1055, 1056, 1057, 1058, 1059, 1060,
  1061, 1062, 1063, 1064, 1066, 1067, 1068, 1069, 1070, 1071,
  1072, 1073, 1074, 1075, 1076, 1080, 1081, 1150, 1151, 1152,
  1153, 1154, 1155, 1156, 1157, 1158, 1159, 1160, 1161, 1162,
  1163, 1164, 1165, 1166, 1167, 1168, 1169, 1190, 1191, 1192,
  1193, 1, 30, 31, 80, 81, 90, 91, 92, 93,
  94, 95, 96, 97, 98, 200, 203, 210, 218, 219,
  220, 221, 222, 221, 1621, 1622,
];

final Map<int, int> systemStringToId = () {
  final map = <int, int>{};
  for (var i = 0; i < systemStrings.length; i++) {
    map[systemStrings[i]] = i + 16; // Later duplicates overwrite (as Python).
  }
  return map;
}();
