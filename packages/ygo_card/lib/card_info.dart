/// 卡牌数据模型
///
/// 独立于 ocgcore 的 CardData，用于 CDN 接口的数据传输。
/// 字段与 cards.cdb 的 datas + texts 表对应。
class CardInfo {
  /// 卡牌编号（唯一标识）
  final int code;

  /// 卡牌别名编号
  final int alias;

  /// 卡组代码数组（最多 16 个元素）
  final List<int> setcode;

  /// 卡牌类型标志位（位掩码）
  final int type;

  /// 等级/阶级（XYZ 怪兽为负值）
  final int level;

  /// 属性（位掩码）
  final int attribute;

  /// 种族（位掩码）
  final int race;

  /// 攻击力
  final int attack;

  /// 守备力
  final int defense;

  /// 灵摆左刻度（非灵摆为 0）
  final int lscale;

  /// 灵摆右刻度（非灵摆为 0）
  final int rscale;

  /// 连接标记（位掩码，非连接为 0）
  final int linkMarker;

  /// 卡牌中文名
  final String name;

  /// 卡牌效果/描述文本
  final String desc;

  const CardInfo({
    required this.code,
    this.alias = 0,
    this.setcode = const [],
    required this.type,
    this.level = 0,
    this.attribute = 0,
    this.race = 0,
    this.attack = 0,
    this.defense = 0,
    this.lscale = 0,
    this.rscale = 0,
    this.linkMarker = 0,
    this.name = '',
    this.desc = '',
  });

  // ---------------------------------------------------------------------------
  // 类型判断
  // ---------------------------------------------------------------------------

  static const int _typeMonster = 0x1;
  static const int _typeSpell = 0x2;
  static const int _typeTrap = 0x4;
  static const int _typeNormal = 0x10;
  static const int _typeEffect = 0x20;
  static const int _typeFusion = 0x40;
  static const int _typeRitual = 0x80;
  static const int _typeSynchro = 0x2000;
  static const int _typeXyz = 0x800000;
  static const int _typeLink = 0x4000000;
  static const int _typePendulum = 0x1000000;
  static const int _typeQuickPlay = 0x10000;
  static const int _typeContinuous = 0x20000;
  static const int _typeEquip = 0x40000;
  static const int _typeField = 0x80000;
  static const int _typeCounter = 0x100000;

  bool get isMonster => (type & _typeMonster) != 0;
  bool get isSpell => (type & _typeSpell) != 0;
  bool get isTrap => (type & _typeTrap) != 0;
  bool get isNormal => (type & _typeNormal) != 0;
  bool get isEffect => (type & _typeEffect) != 0;
  bool get isFusion => (type & _typeFusion) != 0;
  bool get isRitual => (type & _typeRitual) != 0;
  bool get isSynchro => (type & _typeSynchro) != 0;
  bool get isXyz => (type & _typeXyz) != 0;
  bool get isLink => (type & _typeLink) != 0;
  bool get isPendulum => (type & _typePendulum) != 0;
  bool get isQuickPlay => (type & _typeQuickPlay) != 0;
  bool get isContinuous => (type & _typeContinuous) != 0;
  bool get isEquip => (type & _typeEquip) != 0;
  bool get isField => (type & _typeField) != 0;
  bool get isCounter => (type & _typeCounter) != 0;

  /// 类型可读文本
  String get typeText {
    final types = <String>[];
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
    if (isQuickPlay) types.add('速攻');
    if (isContinuous) types.add('永续');
    if (isEquip) types.add('装备');
    if (isField) types.add('场地');
    if (isCounter) types.add('反击');
    return types.join(' ');
  }
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
      // if (isTuner) buf.add('Tuner');
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
  // ---------------------------------------------------------------------------
  // 属性 / 种族 文本
  // ---------------------------------------------------------------------------

  String get attributeText {
    const attrs = {
      0x01: '地', 0x02: '水', 0x04: '炎', 0x08: '风',
      0x10: '光', 0x20: '暗', 0x40: '神',
    };
    return attrs[attribute] ?? '无';
  }

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

  // ---------------------------------------------------------------------------
  // 序列化
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'code': code,
        'alias': alias,
        'setcode': setcode,
        'type': type,
        'level': level,
        'attribute': attribute,
        'race': race,
        'attack': attack,
        'defense': defense,
        'lscale': lscale,
        'rscale': rscale,
        'linkMarker': linkMarker,
        'name': name,
        'desc': desc,
      };

  factory CardInfo.fromJson(Map<String, dynamic> json) => CardInfo(
        code: (json['code'] ?? json['id'] ?? 0) as int,
        alias: (json['alias'] ?? 0) as int,
        setcode: json['setcode'] is List
            ? List<int>.from(json['setcode'])
            : [json['setcode'] as int? ?? 0],
        type: (json['type'] ?? 0) as int,
        level: (json['level'] ?? 0) as int,
        attribute: (json['attribute'] ?? 0) as int,
        race: (json['race'] ?? 0) as int,
        attack: (json['attack'] ?? json['atk'] ?? 0) as int,
        defense: (json['defense'] ?? json['def'] ?? 0) as int,
        lscale: (json['lscale'] ?? 0) as int,
        rscale: (json['rscale'] ?? 0) as int,
        linkMarker: (json['linkMarker'] ?? json['link_marker'] ?? 0) as int,
        name: (json['name'] ?? '') as String,
        desc: (json['desc'] ?? '') as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardInfo && code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'CardInfo($code, $name)';
}
