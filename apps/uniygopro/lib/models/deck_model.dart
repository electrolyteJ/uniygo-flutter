import 'package:ygo_card/card_info.dart';

/// 卡组元数据
class DeckMeta {
  final String deckName;
  final int mainCount;
  final int extraCount;
  final int sideCount;
  final DateTime? updatedAt;
  final bool isBuiltin;

  const DeckMeta({
    required this.deckName,
    this.mainCount = 0,
    this.extraCount = 0,
    this.sideCount = 0,
    this.updatedAt,
    this.isBuiltin = false,
  });

  DeckMeta copyWith({
    String? deckName,
    int? mainCount,
    int? extraCount,
    int? sideCount,
    DateTime? updatedAt,
    bool? isBuiltin,
  }) {
    return DeckMeta(
      deckName: deckName ?? this.deckName,
      mainCount: mainCount ?? this.mainCount,
      extraCount: extraCount ?? this.extraCount,
      sideCount: sideCount ?? this.sideCount,
      updatedAt: updatedAt ?? this.updatedAt,
      isBuiltin: isBuiltin ?? this.isBuiltin,
    );
  }

  Map<String, dynamic> toJson() => {
        'deckName': deckName,
        'mainCount': mainCount,
        'extraCount': extraCount,
        'sideCount': sideCount,
        'updatedAt': updatedAt?.toIso8601String(),
        'isBuiltin': isBuiltin,
      };

  factory DeckMeta.fromJson(Map<String, dynamic> json) => DeckMeta(
        deckName: json['deckName'] as String,
        mainCount: json['mainCount'] as int? ?? 0,
        extraCount: json['extraCount'] as int? ?? 0,
        sideCount: json['sideCount'] as int? ?? 0,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        isBuiltin: json['isBuiltin'] as bool? ?? false,
      );
}

/// 编辑中的卡组
class EditingDeck {
  String deckName;
  final List<CardInfo> main;
  final List<CardInfo> extra;
  final List<CardInfo> side;
  bool isDirty;

  EditingDeck({
    required this.deckName,
    List<CardInfo>? main,
    List<CardInfo>? extra,
    List<CardInfo>? side,
    this.isDirty = false,
  })  : main = main != null ? List.from(main) : [],
        extra = extra != null ? List.from(extra) : [],
        side = side != null ? List.from(side) : [];

  /// 主卡组数量
  int get mainCount => main.length;

  /// 额外卡组数量
  int get extraCount => extra.length;

  /// 备牌数量
  int get sideCount => side.length;

  /// 总卡牌数量
  int get totalCount => mainCount + extraCount + sideCount;

  /// 清空所有卡牌
  void clear() {
    main.clear();
    extra.clear();
    side.clear();
    isDirty = true;
  }

  /// 重置为指定卡组
  void reset(
    String name,
    List<CardInfo> mainCards,
    List<CardInfo> extraCards,
    List<CardInfo> sideCards,
  ) {
    deckName = name;
    main
      ..clear()
      ..addAll(mainCards);
    extra
      ..clear()
      ..addAll(extraCards);
    side
      ..clear()
      ..addAll(sideCards);
    isDirty = false;
  }

  /// 转换为 DeckMeta
  DeckMeta toMeta() => DeckMeta(
        deckName: deckName,
        mainCount: mainCount,
        extraCount: extraCount,
        sideCount: sideCount,
      );
}

/// 卡牌筛选条件
class CardFilter {
  final int? attribute;
  final int? race;
  final int? cardType;
  final int? env;

  const CardFilter({
    this.attribute,
    this.race,
    this.cardType,
    this.env,
  });

  /// 是否为默认筛选
  bool get isDefault =>
      attribute == null && race == null && cardType == null && env == null;

  /// 复制并修改
  CardFilter copyWith({
    int? attribute,
    int? race,
    int? cardType,
    int? env,
    bool clearAttribute = false,
    bool clearRace = false,
    bool clearCardType = false,
    bool clearEnv = false,
  }) {
    return CardFilter(
      attribute: clearAttribute ? null : (attribute ?? this.attribute),
      race: clearRace ? null : (race ?? this.race),
      cardType: clearCardType ? null : (cardType ?? this.cardType),
      env: clearEnv ? null : (env ?? this.env),
    );
  }
}
