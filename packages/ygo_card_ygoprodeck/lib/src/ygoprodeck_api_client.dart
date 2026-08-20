import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:ygo_data/card_info.dart';
import 'package:ygo_data/ygo_card_deck_exception.dart';

import 'ocg_strings.dart';

/// YGOPRODeck API v7 客户端（https://db.ygoprodeck.com/api-guide/）。
///
/// 免费、无需鉴权；数据为英文（TCG 侧），卡图 CDN 按卡密直出。
class YgoprodeckApiClient {
  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  YgoprodeckApiClient({
    http.Client? client,
    this.baseUrl = 'https://db.ygoprodeck.com/api/v7',
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  /// 卡图 URL 按卡密直出，无需请求。
  static String cardImageUrl(
    int code, {
    bool small = false,
    bool cropped = false,
  }) {
    final dir = small
        ? 'cards_small'
        : cropped
        ? 'cards_cropped'
        : 'cards';
    return 'https://images.ygoprodeck.com/images/$dir/$code.jpg';
  }

  /// 按卡密精确查询。
  Future<CardInfo?> fetchCard(int code) async {
    final data = await _get({'id': '$code'});
    if (data.isEmpty) return null;
    return parseCard(data.first);
  }

  /// 拉取卡图二进制。
  Future<Uint8List> fetchCardImage(int code, {bool small = false}) async {
    final uri = Uri.parse(cardImageUrl(code, small: small));
    try {
      final response = await _client.get(uri).timeout(timeout);
      _ensureSuccess(response);
      return response.bodyBytes;
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// 模糊搜索（`fname`，匹配卡名片段）。
  Future<List<CardInfo>> searchCards(
    String keyword, {
    int maxResults = 100,
  }) async {
    if (keyword.trim().isEmpty) return [];
    // API 默认每页 10 条，必须显式传 num，否则 maxResults 不生效
    final data = await _get({'fname': keyword.trim(), 'num': '$maxResults'});
    return data.map(parseCard).whereType<CardInfo>().take(maxResults).toList();
  }

  /// 组合条件搜索（type/attribute/race 为 OCG 位掩码，反查为 API 字符串）。
  Future<List<CardInfo>> searchCombined({
    String? query,
    int? cardType,
    int? attribute,
    int? race,
    int maxResults = 100,
  }) async {
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      params['fname'] = query.trim();
    }
    final typeStr = apiFrameTypeOf(cardType);
    if (typeStr != null) params['type'] = typeStr;
    final attrStr = apiAttributeOf(attribute);
    if (attrStr != null) params['attribute'] = attrStr;
    final raceStr = apiRaceOf(race);
    if (raceStr != null) params['race'] = raceStr;
    if (params.isEmpty) return [];
    // API 默认每页 10 条，必须显式传 num，否则 maxResults 不生效
    params['num'] = '$maxResults';
    final data = await _get(params);
    return data.map(parseCard).whereType<CardInfo>().take(maxResults).toList();
  }

  // ── HTTP 层 ──

  Future<List<Map<String, dynamic>>> _get(Map<String, String> params) async {
    final uri = Uri.parse(
      '$baseUrl/cardinfo.php',
    ).replace(queryParameters: params);
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } catch (e) {
      throw _mapError(e);
    }
    // YGOPRODeck 的"无结果"是 HTTP 400 + {"error": ...}
    if (response.statusCode == 400) return const [];
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final data = decoded['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  // ── 解析层（纯函数，便于测试）──

  /// 解析单个卡对象 JSON 字符串；无卡/错误响应返回 null。
  static CardInfo? parseCardFromJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['error'] != null) return null;
    return parseCard(decoded);
  }

  /// 解析单个卡对象（API `data[]` 元素）。
  static CardInfo? parseCard(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! int) return null;

    final typeStr = json['type'] as String? ?? '';
    // 怪兽卡 type 均含 "Monster"（Token 为独立类型值，也算怪兽侧数据）；
    // "Skill Card" 等边缘类型不视为怪兽，避免污染 attribute/race。
    final isMonster = typeStr.contains('Monster') || typeStr == 'Token';
    final isLink = typeStr.contains('Link');
    final frameType = json['frameType'] as String? ?? '';
    final isPendulum =
        frameType.contains('pendulum') || typeStr.contains('Pendulum');

    final typeline = (json['typeline'] as List?)
        ?.map((e) => e.toString())
        .toList();

    final level = isLink
        ? (json['linkval'] as int? ?? 0) // cdb 惯例：Link 怪 level 存 linkval
        : (json['level'] as int? ?? 0);
    final scale = isPendulum ? (json['scale'] as int? ?? 0) : 0;

    return CardInfo(
      code: id,
      alias: 0,
      setcode: const [],
      type: ocgTypeOf(
        type: typeStr,
        typeline: typeline,
        spellTrapRace: isMonster ? null : json['race'] as String?,
      ),
      level: level,
      attribute: isMonster ? ocgAttributeOf(json['attribute'] as String?) : 0,
      race: isMonster ? ocgRaceOf(json['race'] as String?) : 0,
      attack: json['atk'] as int? ?? 0,
      defense: json['def'] as int? ?? 0, // Link 怪 def 为 null
      lscale: scale,
      rscale: scale,
      linkMarker: isLink
          ? ocgLinkMarkersOf(
              (json['linkmarkers'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const [],
            )
          : 0,
      name: json['name'] as String? ?? '',
      desc: json['desc'] as String? ?? '',
    );
  }

  // ── int 位掩码 → API 字符串（searchCombined 反查）──

  static const _attributeStrings = <int, String>{
    0x01: 'EARTH',
    0x02: 'WATER',
    0x04: 'FIRE',
    0x08: 'WIND',
    0x10: 'LIGHT',
    0x20: 'DARK',
    0x40: 'DIVINE',
  };

  static const _raceStrings = <int, String>{
    0x1: 'Warrior',
    0x2: 'Spellcaster',
    0x4: 'Fairy',
    0x8: 'Fiend',
    0x10: 'Zombie',
    0x20: 'Machine',
    0x40: 'Aqua',
    0x80: 'Pyro',
    0x100: 'Rock',
    0x200: 'Winged Beast',
    0x400: 'Plant',
    0x800: 'Insect',
    0x1000: 'Thunder',
    0x2000: 'Dragon',
    0x4000: 'Beast',
    0x8000: 'Beast-Warrior',
    0x10000: 'Dinosaur',
    0x20000: 'Fish',
    0x40000: 'Sea Serpent',
    0x80000: 'Reptile',
    0x100000: 'Psychic',
    0x200000: 'Divine-Beast',
    0x400000: 'Creator God',
    0x800000: 'Wyrm',
    0x1000000: 'Cyberse',
    0x2000000: 'Illusion',
  };

  static String? apiAttributeOf(int? attribute) => _attributeStrings[attribute];
  static String? apiRaceOf(int? race) => _raceStrings[race];

  /// 类型位掩码 → API `type` 参数（取最具区分度的主类别）。
  ///
  /// YGOPRODeck 的 `type` 参数是精确匹配单值，无法表达"全部怪兽"或
  /// "全部灵摆"这类泛型过滤：TYPE_MONSTER/TYPE_PENDULUM 单独出现时
  /// 返回 null（调用方放弃该维度，而不是窄化/丢弃过滤条件）。
  static String? apiFrameTypeOf(int? cardType) {
    if (cardType == null) return null;
    if (cardType & 0x2 != 0) return 'Spell Card';
    if (cardType & 0x4 != 0) return 'Trap Card';
    if (cardType & 0x4000000 != 0) return 'Link Monster';
    if (cardType & 0x800000 != 0) return 'XYZ Monster';
    if (cardType & 0x2000 != 0) return 'Synchro Monster';
    if (cardType & 0x40 != 0) return 'Fusion Monster';
    if (cardType & 0x80 != 0) return 'Ritual Monster';
    if (cardType & 0x10 != 0) return 'Normal Monster';
    if (cardType & 0x20 != 0) return 'Effect Monster';
    return null;
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 404) {
      throw YgoCardDeckException(
        type: YgoCardDeckErrorType.notFound,
        message: 'Not found',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode >= 500) {
      throw YgoCardDeckException(
        type: YgoCardDeckErrorType.serverError,
        message: 'Server error',
        statusCode: response.statusCode,
      );
    }
    throw YgoCardDeckException(
      type: YgoCardDeckErrorType.clientError,
      message: 'HTTP ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  YgoCardDeckException _mapError(Object e) {
    if (e is YgoCardDeckException) return e;
    if (e is http.ClientException) {
      return YgoCardDeckException(
        type: YgoCardDeckErrorType.networkError,
        message: e.message,
        cause: e,
      );
    }
    return YgoCardDeckException(
      type: YgoCardDeckErrorType.unknown,
      message: e.toString(),
      cause: e,
    );
  }

  void dispose() => _client.close();
}
