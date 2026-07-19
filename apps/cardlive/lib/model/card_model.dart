class CardData {
  final int code;
  final int alias;
  final String name;
  final String desc;
  final int type;
  final int level;
  final int attribute;
  final int race;
  final int attack;
  final int defense;
  final int lscale;
  final int rscale;
  final int linkMarker;
  final List<int> setcode;

  CardData({
    required this.code,
    required this.alias,
    required this.name,
    required this.desc,
    required this.type,
    required this.level,
    required this.attribute,
    required this.race,
    required this.attack,
    required this.defense,
    required this.lscale,
    required this.rscale,
    required this.linkMarker,
    required this.setcode,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'alias': alias,
      'name': name,
      'desc': desc,
      'type': type,
      'level': level,
      'attribute': attribute,
      'race': race,
      'attack': attack,
      'defense': defense,
      'lscale': lscale,
      'rscale': rscale,
      'linkMarker': linkMarker,
      'setcode': setcode,
    };
  }

  factory CardData.fromJson(Map<String, dynamic> json) {
    return CardData(
      code: json['code'] ?? 0,
      alias: json['alias'] ?? 0,
      name: json['name'] ?? '',
      desc: json['desc'] ?? '',
      type: json['type'] ?? 0,
      level: json['level'] ?? 0,
      attribute: json['attribute'] ?? 0,
      race: json['race'] ?? 0,
      attack: json['attack'] ?? 0,
      defense: json['defense'] ?? 0,
      lscale: json['lscale'] ?? 0,
      rscale: json['rscale'] ?? 0,
      linkMarker: json['linkMarker'] ?? 0,
      setcode: json['setcode'] is List ? List<int>.from(json['setcode']) : [],
    );
  }

  bool get isMonster => (type & 0x1) != 0;
  bool get isSpell => (type & 0x2) != 0;
  bool get isTrap => (type & 0x4) != 0;
  bool get isNormal => (type & 0x10) != 0;
  bool get isEffect => (type & 0x20) != 0;
  bool get isFusion => (type & 0x40) != 0;
  bool get isRitual => (type & 0x80) != 0;
  bool get isSynchro => (type & 0x2000) != 0;
  bool get isXyz => (type & 0x800000) != 0;
  bool get isLink => (type & 0x4000000) != 0;
  bool get isPendulum => (type & 0x1000000) != 0;

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
}