import 'package:resource_data/card_info.dart';

/// 卡池搜索的四大类。
enum CardCategory { monster, extra, spell, trap }

/// 卡池搜索的类别筛选（不可变）。
///
/// 四个大类（怪兽/额外卡/魔法/陷阱）可多选，各大类带各自子筛选项：
/// - 怪兽：属性 + 种族（主卡组怪兽，不含融合/同调/超量/连接）
/// - 额外卡：融合 / 同调 / 超量 / 连接
/// - 魔法：通常 / 速攻 / 永续 / 装备 / 场地 / 仪式
/// - 陷阱：通常 / 永续 / 反击 / 陷阱怪兽
///
/// 各大类之间是「或」关系（可同时请求，结果取并集），
/// 但子筛选项只作用于其所属大类，不会跨类生效。
class CardSearchFilter {
  final bool monster;
  final bool extra;
  final bool spell;
  final bool trap;

  /// 怪兽属性（attribute 值集合）。
  final Set<int> attributes;

  /// 怪兽种族（race 值集合）。
  final Set<int> races;

  /// 额外卡种类（type 标志位：融合/同调/超量/连接）。
  final Set<int> extraTypes;

  /// 魔法子类（0 = 通常魔法，其余为 type 标志位）。
  final Set<int> spellTypes;

  /// 陷阱子类（0 = 通常陷阱，其余为 type 标志位）。
  final Set<int> trapTypes;

  const CardSearchFilter({
    this.monster = false,
    this.extra = false,
    this.spell = false,
    this.trap = false,
    this.attributes = const {},
    this.races = const {},
    this.extraTypes = const {},
    this.spellTypes = const {},
    this.trapTypes = const {},
  });

  static const CardSearchFilter none = CardSearchFilter();

  /// 默认筛选：初始只选中「怪兽」大类。
  static const CardSearchFilter defaults = CardSearchFilter(monster: true);

  /// 是否未激活任何大类（仅关键字搜索）。
  bool get isEmpty => !monster && !extra && !spell && !trap;

  /// 是否为默认状态（仅选中怪兽，且无任何子筛选）。
  bool get isDefault =>
      monster &&
      !extra &&
      !spell &&
      !trap &&
      attributes.isEmpty &&
      races.isEmpty &&
      extraTypes.isEmpty &&
      spellTypes.isEmpty &&
      trapTypes.isEmpty;

  /// 各大类的粗粒度 type 掩码（用于 SQL 侧预筛，OR 语义）。
  int get broadTypeMask {
    var mask = 0;
    if (monster) mask |= 0x1;
    if (extra) mask |= 0x40 | 0x2000 | 0x800000 | 0x4000000;
    if (spell) mask |= 0x2;
    if (trap) mask |= 0x4;
    return mask;
  }

  /// 判断卡是否命中任一已激活大类。
  bool matches(CardInfo c) {
    if (isEmpty) return true;
    if (monster && _isMainMonster(c) && _matchAttrRace(c)) return true;
    if (extra && _isExtra(c) && _matchExtraType(c)) return true;
    if (spell && c.isSpell && _matchSpellType(c)) return true;
    if (trap && c.isTrap && _matchTrapType(c)) return true;
    return false;
  }

  CardSearchFilter copyWith({
    bool? monster,
    bool? extra,
    bool? spell,
    bool? trap,
    Set<int>? attributes,
    Set<int>? races,
    Set<int>? extraTypes,
    Set<int>? spellTypes,
    Set<int>? trapTypes,
  }) {
    return CardSearchFilter(
      monster: monster ?? this.monster,
      extra: extra ?? this.extra,
      spell: spell ?? this.spell,
      trap: trap ?? this.trap,
      attributes: attributes ?? this.attributes,
      races: races ?? this.races,
      extraTypes: extraTypes ?? this.extraTypes,
      spellTypes: spellTypes ?? this.spellTypes,
      trapTypes: trapTypes ?? this.trapTypes,
    );
  }

  // -------------------------------------------------------------------------
  // 各大类判定
  // -------------------------------------------------------------------------

  bool _isMainMonster(CardInfo c) =>
      c.isMonster && !c.isFusion && !c.isSynchro && !c.isXyz && !c.isLink;

  bool _matchAttrRace(CardInfo c) {
    if (attributes.isNotEmpty && !attributes.contains(c.attribute)) {
      return false;
    }
    if (races.isNotEmpty && !races.contains(c.race)) return false;
    return true;
  }

  bool _isExtra(CardInfo c) =>
      c.isFusion || c.isSynchro || c.isXyz || c.isLink;

  bool _matchExtraType(CardInfo c) {
    if (extraTypes.isEmpty) return true;
    return (extraTypes.contains(0x40) && c.isFusion) ||
        (extraTypes.contains(0x2000) && c.isSynchro) ||
        (extraTypes.contains(0x800000) && c.isXyz) ||
        (extraTypes.contains(0x4000000) && c.isLink);
  }

  bool _matchSpellType(CardInfo c) {
    if (spellTypes.isEmpty) return true;
    return spellTypes.any((t) => _isSpellType(c, t));
  }

  bool _isSpellType(CardInfo c, int t) {
    switch (t) {
      case 0:
        return !c.isQuickPlay &&
            !c.isContinuous &&
            !c.isEquip &&
            !c.isField &&
            !c.isRitual;
      case 0x10000:
        return c.isQuickPlay;
      case 0x20000:
        return c.isContinuous;
      case 0x40000:
        return c.isEquip;
      case 0x80000:
        return c.isField;
      case 0x80:
        return c.isRitual;
      default:
        return false;
    }
  }

  bool _matchTrapType(CardInfo c) {
    if (trapTypes.isEmpty) return true;
    return trapTypes.any((t) => _isTrapType(c, t));
  }

  bool _isTrapType(CardInfo c, int t) {
    switch (t) {
      case 0:
        return !c.isContinuous && !c.isCounter && (c.type & 0x100) == 0;
      case 0x20000:
        return c.isContinuous;
      case 0x100000:
        return c.isCounter;
      case 0x100:
        return (c.type & 0x100) != 0;
      default:
        return false;
    }
  }
}
