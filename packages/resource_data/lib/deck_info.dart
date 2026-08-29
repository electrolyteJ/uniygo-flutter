/// 卡组主卡组/额外卡组/副卡组中的卡牌条目
class DeckCard {
  /// 卡牌编号
  final int code;

  /// 数量
  final int count;

  const DeckCard({required this.code, this.count = 1});

  Map<String, dynamic> toJson() => {'code': code, 'count': count};

  factory DeckCard.fromJson(Map<String, dynamic> json) => DeckCard(
    code: (json['code'] ?? 0) as int,
    count: (json['count'] ?? 1) as int,
  );

  @override
  String toString() => 'DeckCard($code x$count)';
}

class DeckInfo {
  String deckName;

  /// 主卡组
  final List<DeckCard> mainDeck;

  /// 额外卡组
  final List<DeckCard> extraDeck;

  /// 副卡组
  final List<DeckCard> sideDeck;

  /// 是否为内置卡组
  bool isBuiltin;

  DeckInfo({
    required this.deckName,
    this.mainDeck = const [],
    this.extraDeck = const [],
    this.sideDeck = const [],
    this.isBuiltin = false,
  });

  int get mainCount => mainDeck.fold(0, (s, c) => s + c.count);
  int get extraCount => extraDeck.fold(0, (s, c) => s + c.count);
  int get sideCount => sideDeck.fold(0, (s, c) => s + c.count);
  int get totalCount => mainCount + extraCount + sideCount;

  DeckInfo copyWith({String? deckName, bool? isBuiltin}) {
    return DeckInfo(
      deckName: deckName ?? this.deckName,
      mainDeck: mainDeck,
      extraDeck: extraDeck,
      sideDeck: sideDeck,
      isBuiltin: isBuiltin ?? this.isBuiltin,
    );
  }

  Map<String, dynamic> toJson() => {
    'deckName': deckName,
    'mainDeck': mainDeck.map((c) => c.toJson()).toList(),
    'extraDeck': extraDeck.map((c) => c.toJson()).toList(),
    'sideDeck': sideDeck.map((c) => c.toJson()).toList(),
    'mainCount': mainCount,
    'extraCount': extraCount,
    'sideCount': sideCount,
    'isBuiltin': isBuiltin,
  };

  factory DeckInfo.fromJson(Map<String, dynamic> json) {
    return DeckInfo(
      deckName: (json['deckName'] ?? '') as String,
      mainDeck: _parseDeckCards(json['mainDeck'] ?? json['main']),
      extraDeck: _parseDeckCards(json['extraDeck'] ?? json['extra']),
      sideDeck: _parseDeckCards(json['sideDeck'] ?? json['side']),
      isBuiltin: (json['isBuiltin'] ?? false) as bool,
    );
  }

  static List<DeckCard> _parseDeckCards(dynamic list) {
    if (list is List) {
      final grouped = <int, int>{};
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          final code = (e['code'] ?? 0) as int;
          final count = (e['count'] ?? 1) as int;
          if (code > 0) {
            grouped[code] = (grouped[code] ?? 0) + count;
          }
        }
      }
      return grouped.entries
          .map((e) => DeckCard(code: e.key, count: e.value))
          .toList();
    }
    return [];
  }

  @override
  String toString() =>
      'DeckInfo($deckName, 主:$mainCount 额:$extraCount 副:$sideCount)';
}

/// 卡组详情
class MdPro3DeckInfo {
  /// 卡组 ID
  final String deckId;

  /// 卡组名称
  final String name;

  /// 贡献者
  final String contributor;

  /// 用户 ID
  final int userId;

  /// 主卡组
  final List<DeckCard> mainDeck;

  /// 额外卡组
  final List<DeckCard> extraDeck;

  /// 副卡组
  final List<DeckCard> sideDeck;

  /// 点赞数
  final int likeCount;

  /// 是否公开
  final bool isPublic;

  /// 排名
  final int rank;

  /// 创建时间 (ISO 8601)
  final String? createdAt;

  /// 更新时间 (ISO 8601)
  final String? updatedAt;

  /// 卡组描述
  final String description;

  /// 封面卡牌编号
  final int? coverCode;

  const MdPro3DeckInfo({
    required this.deckId,
    this.name = '',
    this.contributor = '',
    this.userId = 0,
    this.mainDeck = const [],
    this.extraDeck = const [],
    this.sideDeck = const [],
    this.likeCount = 0,
    this.isPublic = true,
    this.rank = 0,
    this.createdAt,
    this.updatedAt,
    this.description = '',
    this.coverCode,
  });

  /// 总卡牌数
  int get mainCount => mainDeck.fold(0, (s, c) => s + c.count);
  int get extraCount => extraDeck.fold(0, (s, c) => s + c.count);
  int get sideCount => sideDeck.fold(0, (s, c) => s + c.count);

  /// 提取所有卡牌编码（去重）
  Set<int> get allCodes => {
    ...mainDeck.map((c) => c.code),
    ...extraDeck.map((c) => c.code),
    ...sideDeck.map((c) => c.code),
  };

  Map<String, dynamic> toJson() => {
    'deckId': deckId,
    'name': name,
    'contributor': contributor,
    'userId': userId,
    'mainDeck': mainDeck.map((c) => c.toJson()).toList(),
    'extraDeck': extraDeck.map((c) => c.toJson()).toList(),
    'sideDeck': sideDeck.map((c) => c.toJson()).toList(),
    'likeCount': likeCount,
    'isPublic': isPublic,
    'rank': rank,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'description': description,
    'coverCode': coverCode,
  };

  factory MdPro3DeckInfo.fromJson(Map<String, dynamic> json) {
    List<DeckCard> parseDeckList(dynamic list) {
      if (list is List) {
        return list
            .map((e) => DeckCard.fromJson(e is Map<String, dynamic> ? e : {}))
            .toList();
      }
      return [];
    }

    return MdPro3DeckInfo(
      deckId: (json['deckId'] ?? json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      contributor: (json['contributor'] ?? '') as String,
      userId: (json['userId'] ?? 0) as int,
      mainDeck: parseDeckList(json['mainDeck'] ?? json['main']),
      extraDeck: parseDeckList(json['extraDeck'] ?? json['extra']),
      sideDeck: parseDeckList(json['sideDeck'] ?? json['side']),
      likeCount: (json['likeCount'] ?? json['likes'] ?? 0) as int,
      isPublic: (json['isPublic'] ?? true) as bool,
      rank: (json['rank'] ?? 0) as int,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      description: (json['description'] ?? '') as String,
      coverCode: json['coverCode'] as int?,
    );
  }

  @override
  String toString() => 'DeckInfo($deckId, $name)';
}

/// 卡组广场列表摘要（轻量版，不含完整卡表）
class DeckSummary {
  /// 卡组 ID
  final String deckId;

  /// 卡组名称
  final String name;

  /// 贡献者
  final String contributor;

  /// 点赞数
  final int likeCount;

  /// 公开/私密
  final bool isPublic;

  /// 排名
  final int rank;

  /// 封面卡牌编号
  final int? coverCode;

  /// 创建/更新时间
  final String? createdAt;
  final String? updatedAt;

  /// 描述
  final String description;

  const DeckSummary({
    required this.deckId,
    this.name = '',
    this.contributor = '',
    this.likeCount = 0,
    this.isPublic = true,
    this.rank = 0,
    this.coverCode,
    this.createdAt,
    this.updatedAt,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
    'deckId': deckId,
    'name': name,
    'contributor': contributor,
    'likeCount': likeCount,
    'isPublic': isPublic,
    'rank': rank,
    'coverCode': coverCode,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'description': description,
  };

  factory DeckSummary.fromJson(Map<String, dynamic> json) => DeckSummary(
    deckId: (json['deckId'] ?? json['id'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    contributor: (json['contributor'] ?? '') as String,
    likeCount: (json['likeCount'] ?? json['likes'] ?? 0) as int,
    isPublic: (json['isPublic'] ?? true) as bool,
    rank: (json['rank'] ?? 0) as int,
    coverCode: json['coverCode'] as int?,
    createdAt: json['createdAt'] as String?,
    updatedAt: json['updatedAt'] as String?,
    description: (json['description'] ?? '') as String,
  );

  @override
  String toString() => 'DeckSummary($deckId, $name)';
}
