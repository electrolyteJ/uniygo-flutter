/// 卡组 DTO：与 packages/ygo_data/lib/deck_info.dart 的 DeckInfo/DeckCard
/// JSON 结构完全一致（纯 Dart 版，服务端不能依赖 ygo_data 的 Flutter 插件）。
///
/// 存储格式同时与 packages/ygo_deck_mycard/lib/src/deck_service.dart 的
/// saveDeck 一致：
/// {deckName, mainCount, extraCount, sideCount, updatedAt,
///  mainDeck, extraDeck, sideDeck}
library;

/// 卡组中的卡牌条目（对齐 DeckCard）。
class DeckCardDto {
  const DeckCardDto({required this.code, this.count = 1});

  /// 卡牌编号。
  final int code;

  /// 数量。
  final int count;

  Map<String, dynamic> toJson() => {'code': code, 'count': count};

  factory DeckCardDto.fromJson(Map<String, dynamic> json) => DeckCardDto(
    code: (json['code'] ?? 0) as int,
    count: (json['count'] ?? 1) as int,
  );
}

/// 卡组（对齐 DeckInfo）。
class DeckDto {
  DeckDto({
    required this.deckName,
    this.mainDeck = const [],
    this.extraDeck = const [],
    this.sideDeck = const [],
    this.isBuiltin = false,
    this.updatedAt,
  });

  String deckName;
  final List<DeckCardDto> mainDeck;
  final List<DeckCardDto> extraDeck;
  final List<DeckCardDto> sideDeck;
  bool isBuiltin;

  /// 更新时间（ISO 8601，保存时由服务端写入）。
  String? updatedAt;

  int get mainCount => mainDeck.fold(0, (s, c) => s + c.count);
  int get extraCount => extraDeck.fold(0, (s, c) => s + c.count);
  int get sideCount => sideDeck.fold(0, (s, c) => s + c.count);

  /// 与 ygo_deck_mycard DeckService.saveDeck 相同的存储格式。
  Map<String, dynamic> toJson() => {
    'deckName': deckName,
    'mainCount': mainCount,
    'extraCount': extraCount,
    'sideCount': sideCount,
    'updatedAt': ?updatedAt,
    'mainDeck': mainDeck.map((c) => c.toJson()).toList(),
    'extraDeck': extraDeck.map((c) => c.toJson()).toList(),
    'sideDeck': sideDeck.map((c) => c.toJson()).toList(),
  };

  /// 容错解析（对齐 DeckInfo.fromJson：兼容 main/extra/side 别名，
  /// 重复 code 合并计数）。
  factory DeckDto.fromJson(Map<String, dynamic> json) => DeckDto(
    deckName: (json['deckName'] ?? '') as String,
    mainDeck: _parseDeckCards(json['mainDeck'] ?? json['main']),
    extraDeck: _parseDeckCards(json['extraDeck'] ?? json['extra']),
    sideDeck: _parseDeckCards(json['sideDeck'] ?? json['side']),
    isBuiltin: (json['isBuiltin'] ?? false) as bool,
    updatedAt: json['updatedAt'] as String?,
  );

  static List<DeckCardDto> _parseDeckCards(dynamic list) {
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
          .map((e) => DeckCardDto(code: e.key, count: e.value))
          .toList();
    }
    return [];
  }
}
