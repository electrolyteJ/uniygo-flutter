/// ocgcore 原始位掩码 → duelink_ai_ygo_agent 枚举的映射。
///
/// 位常量取自本工程 ocgcore（与 cards.cdb 及 ygo-agent 训练侧使用的
/// 位约定一致 —— 注意与本仓库 ocgcore 之外的"标准 ocgcore"数值不同，
/// 例如 TYPE_NORMAL=0x10、TYPE_LINK=0x4000000）。
library;

import 'package:ocgcore/ocgcore.dart';
import '../enums.dart';

/// 原始表示形式字节 → [Position]（未知值 → [Position.none]）。
Position positionFromRaw(int raw) => switch (raw & 0xf) {
      POS_FACEUP_ATTACK => Position.faceupAttack,
      POS_FACEDOWN_ATTACK => Position.facedownAttack,
      POS_ATTACK => Position.attack,
      POS_FACEUP_DEFENSE => Position.faceupDefense,
      POS_FACEUP => Position.faceup,
      POS_FACEDOWN_DEFENSE => Position.facedownDefense,
      POS_FACEDOWN => Position.facedown,
      POS_DEFENSE => Position.defense,
      _ => Position.none,
    };

/// 原始属性位 → [Attribute]（非单 bit / 0 → [Attribute.none]）。
Attribute attributeFromRaw(int raw) => switch (raw) {
      ATTRIBUTE_EARTH => Attribute.earth,
      ATTRIBUTE_WATER => Attribute.water,
      ATTRIBUTE_FIRE => Attribute.fire,
      ATTRIBUTE_WIND => Attribute.wind,
      ATTRIBUTE_LIGHT => Attribute.light,
      ATTRIBUTE_DARK => Attribute.dark,
      ATTRIBUTE_DEVINE => Attribute.divine,
      _ => Attribute.none,
    };

/// 原始种族位 → [Race]（非单 bit / 0 → [Race.none]）。
Race raceFromRaw(int raw) => switch (raw) {
      RACE_WARRIOR => Race.warrior,
      RACE_SPELLCASTER => Race.spellcaster,
      RACE_FAIRY => Race.fairy,
      RACE_FIEND => Race.fiend,
      RACE_ZOMBIE => Race.zombie,
      RACE_MACHINE => Race.machine,
      RACE_AQUA => Race.aqua,
      RACE_PYRO => Race.pyro,
      RACE_ROCK => Race.rock,
      RACE_WINDBEAST => Race.windbeast,
      RACE_PLANT => Race.plant,
      RACE_INSECT => Race.insect,
      RACE_THUNDER => Race.thunder,
      RACE_DRAGON => Race.dragon,
      RACE_BEAST => Race.beast,
      RACE_BEASTWARRIOR => Race.beastWarrior,
      RACE_DINOSAUR => Race.dinosaur,
      RACE_FISH => Race.fish,
      RACE_SEASERPENT => Race.seaSerpent,
      RACE_REPTILE => Race.reptile,
      RACE_PSYCHO => Race.psycho,
      RACE_DEVINE => Race.devine,
      RACE_CREATORGOD => Race.creatorGod,
      RACE_WYRM => Race.wyrm,
      RACE_CYBERSE => Race.cyberse,
      RACE_ILLUSION => Race.illusion,
      _ => Race.none,
    };

/// 卡牌类型位掩码中置位的 [CardType]，按 bit 升序（与 env `type_to_ids`
/// 消费的集合一致；编码时按 [typeToId] 落列，顺序不影响结果）。
const List<(int, CardType)> _typeBits = [
  (TYPE_MONSTER, CardType.monster),
  (TYPE_SPELL, CardType.spell),
  (TYPE_TRAP, CardType.trap),
  (TYPE_NORMAL, CardType.normal),
  (TYPE_EFFECT, CardType.effect),
  (TYPE_FUSION, CardType.fusion),
  (TYPE_RITUAL, CardType.ritual),
  (TYPE_TRAPMONSTER, CardType.trapMonster),
  (TYPE_SPIRIT, CardType.spirit),
  (TYPE_UNION, CardType.union),
  (TYPE_DUAL, CardType.dual),
  (TYPE_TUNER, CardType.tuner),
  (TYPE_SYNCHRO, CardType.synchro),
  (TYPE_TOKEN, CardType.token),
  (TYPE_QUICKPLAY, CardType.quickPlay),
  (TYPE_CONTINUOUS, CardType.continuous),
  (TYPE_EQUIP, CardType.equip),
  (TYPE_FIELD, CardType.field),
  (TYPE_COUNTER, CardType.counter),
  (TYPE_FLIP, CardType.flip),
  (TYPE_TOON, CardType.toon),
  (TYPE_XYZ, CardType.xyz),
  (TYPE_PENDULUM, CardType.pendulum),
  (TYPE_SPSUMMON, CardType.special),
  (TYPE_LINK, CardType.link),
];

List<CardType> typesFromRaw(int raw) =>
    [for (final (bit, type) in _typeBits) if ((raw & bit) != 0) type];

/// 原始 location 字节 → [Location]（剥离 OVERLAY 位；未知区域返回 null）。
Location? locationFromRaw(int raw) => switch (raw & ~LOCATION_OVERLAY) {
      LOCATION_DECK => Location.deck,
      LOCATION_HAND => Location.hand,
      LOCATION_MZONE => Location.mzone,
      LOCATION_SZONE => Location.szone,
      LOCATION_GRAVE => Location.grave,
      LOCATION_REMOVED => Location.removed,
      LOCATION_EXTRA => Location.extra,
      _ => null,
    };

/// 原始 phase 值（MSG_NEW_PHASE u16）→ [Phase]（未知值返回 null）。
Phase? phaseFromRaw(int raw) => switch (raw) {
      PHASE_DRAW => Phase.draw,
      PHASE_STANDBY => Phase.standby,
      PHASE_MAIN1 => Phase.main1,
      PHASE_BATTLE_START => Phase.battleStart,
      PHASE_BATTLE_STEP => Phase.battleStep,
      PHASE_DAMAGE => Phase.damage,
      PHASE_DAMAGE_CAL => Phase.damageCalculation,
      PHASE_BATTLE => Phase.battle,
      PHASE_MAIN2 => Phase.main2,
      PHASE_END => Phase.end,
      _ => null,
    };
