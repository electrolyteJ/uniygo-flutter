import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:resource_data/deck_info.dart';
import 'package:resource_data/deck_list_page.dart';
import 'package:resource_data/ygo_card_deck_exception.dart';

import 'http_client_factory.dart';

/// 卡组广场 Deck API 客户端
///
/// 负责与卡组广场服务通信，获取/管理卡组。
/// [baseUrl] 为 Deck API 根地址。
///
/// 需要在请求头中设置 [reqSource] 标识来源：
/// - Web 端: `MDPro3`
/// - Android 端: `YGOMobile`
class DeckApiClient {
  final http.Client _client;

  /// API 根地址。默认 MDPro3 卡组广场镜像（zgai.tech:38443，
  /// rarnu.xyz:38383 的 HTTPS 入口，同一后端）；原官方地址
  /// deck.moecube.com 的 DNS 记录已下线（全球 NXDOMAIN）。
  /// 可通过构造参数或 `--dart-define=DECK_SQUARE_URL=...` 指向自建
  /// 服务（如 servers/ygo_deck_server 的 /api/mdpro3 兼容层）。
  final String baseUrl;
  final String reqSource = "MDPro3";
  final Duration timeout;

  DeckApiClient({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 30),
  })  : _client = client ?? createDeckHttpClient(),
        baseUrl = baseUrl ?? const String.fromEnvironment(
          'DECK_SQUARE_URL',
          defaultValue: 'https://zgai.tech:38443',
        );

  // ---------------------------------------------------------------------------
  // 请求头
  // ---------------------------------------------------------------------------

  Map<String, String> get _headers => {
    'ReqSource': reqSource,
    'Content-Type': 'application/json',
  };

  Map<String, String> _authHeaders(String token) => {
    ..._headers,
    'token': token,
  };

  // ---------------------------------------------------------------------------
  // 卡组广场
  // ---------------------------------------------------------------------------

  /// 获取卡组广场分页列表
  ///
  /// [page] 页码（从 1 开始）
  /// [size] 每页数量
  /// [keyword] 搜索关键词（可选）
  /// [sortLike] 按点赞排序
  /// [sortRank] 按排名排序
  /// [contributor] 按贡献者筛选（可选）
  Future<DeckListPage> fetchDeckList({
    int page = 1,
    int size = 20,
    String? keyword,
    bool sortLike = false,
    bool sortRank = false,
    String? contributor,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
        'sortLike': sortLike.toString(),
        'sortRank': sortRank.toString(),
      };
      if (keyword != null && keyword.isNotEmpty) params['keyWord'] = keyword;
      if (contributor != null && contributor.isNotEmpty) {
        params['contributor'] = contributor;
      }

      final uri = Uri.parse(
        '$baseUrl/api/mdpro3/deck/list',
      ).replace(queryParameters: params);
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(timeout);
      _ensureSuccess(response);

      final data = _unwrapEnvelope(jsonDecode(response.body));
      if (data is Map<String, dynamic> && data['records'] is List) {
        // YGOMobile 信封分页：{current, size, total, pages, records}
        final records = (data['records'] as List)
            .whereType<Map<String, dynamic>>()
            .map(_normalizeSummary)
            .toList();
        return DeckListPage.fromJson({
          'decks': records,
          'page': data['current'] ?? 1,
          'size': data['size'] ?? 20,
          'total': data['total'] ?? 0,
        });
      }
      if (data is Map<String, dynamic>) {
        // 平铺格式：{decks, page, size, total}（自建服务）或 {data: [...]}
        return DeckListPage.fromJson(data);
      }
      throw const YgoCardDeckException(
        type: YgoCardDeckErrorType.parseError,
        message: 'Expected a JSON object',
      );
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// 获取单个卡组详情
  ///
  /// [deckId] 卡组 ID
  Future<MdPro3DeckInfo> fetchDeckDetail(String deckId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/mdpro3/deck/$deckId');
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(timeout);
      _ensureSuccess(response);

      final data = _unwrapEnvelope(jsonDecode(response.body));
      if (data is! Map<String, dynamic>) {
        throw const YgoCardDeckException(
          type: YgoCardDeckErrorType.parseError,
          message: 'Expected a JSON object',
        );
      }
      if (data['deckYdk'] is String) {
        // YGOMobile 信封详情：卡表在 deckYdk 纯文本里
        return _detailFromYdkRecord(data);
      }
      return MdPro3DeckInfo.fromJson(data);
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // 卡组 ID 生成
  // ---------------------------------------------------------------------------

  /// 生成新卡组 ID
  ///
  /// 上传卡组前调用此方法获取唯一 ID。
  Future<String> generateDeckId() async {
    try {
      final uri = Uri.parse('$baseUrl/api/mdpro3/deck/deckId');
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(timeout);
      _ensureSuccess(response);

      final data = _unwrapEnvelope(jsonDecode(response.body));
      if (data is String && data.isNotEmpty) return data;
      if (data is Map<String, dynamic>) {
        return (data['deckId'] ?? data['id'] ?? '') as String;
      }
      return data.toString();
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // 云端卡组同步
  // ---------------------------------------------------------------------------

  /// 获取用户云端卡组列表
  ///
  /// [userId] 用户 ID
  /// [token] 认证 token
  Future<List<MdPro3DeckInfo>> fetchUserDecks({
    required int userId,
    required String token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/mdpro3/sync/$userId/nodel');
      final response = await _client
          .get(uri, headers: _authHeaders(token))
          .timeout(timeout);
      _ensureSuccess(response);

      final data = _unwrapEnvelope(jsonDecode(response.body));
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((e) => MdPro3DeckInfo.fromJson(_normalizeSummary(e)))
            .toList();
      }
      if (data is Map<String, dynamic> && data.containsKey('decks')) {
        return (data['decks'] as List)
            .whereType<Map<String, dynamic>>()
            .map((e) => MdPro3DeckInfo.fromJson(_normalizeSummary(e)))
            .toList();
      }
      return [];
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// 上传卡组
  ///
  /// [deck] 要上传的卡组数据
  /// [userId] 用户 ID
  /// [contributor] 贡献者名
  /// [token] 认证 token
  Future<void> uploadDeck({
    required MdPro3DeckInfo deck,
    required int userId,
    required String contributor,
    required String token,
  }) async {
    try {
      final body = jsonEncode({
        'userId': userId,
        'contributor': contributor,
        'deck': {
          'deckId': deck.deckId,
          'name': deck.name,
          'main': deck.mainDeck.map((c) => c.toJson()).toList(),
          'extra': deck.extraDeck.map((c) => c.toJson()).toList(),
          'side': deck.sideDeck.map((c) => c.toJson()).toList(),
          'description': deck.description,
          'coverCode': deck.coverCode,
        },
      });

      final uri = Uri.parse('$baseUrl/api/mdpro3/sync/single');
      final response = await _client
          .post(uri, headers: _authHeaders(token), body: body)
          .timeout(timeout);
      _ensureSuccess(response);
      _checkBusinessCode(response);
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// 删除卡组
  ///
  /// [deckId] 卡组 ID
  /// [userId] 用户 ID
  /// [contributor] 贡献者名
  /// [token] 认证 token
  Future<void> deleteDeck({
    required String deckId,
    required int userId,
    required String contributor,
    required String token,
  }) async {
    try {
      final body = jsonEncode({
        'userId': userId,
        'contributor': contributor,
        'deck': {'deckId': deckId, 'isDelete': true},
      });

      final uri = Uri.parse('$baseUrl/api/mdpro3/sync/single');
      final response = await _client
          .post(uri, headers: _authHeaders(token), body: body)
          .timeout(timeout);
      _ensureSuccess(response);
      _checkBusinessCode(response);
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// 切换卡组公开/私密
  ///
  /// [deckId] 卡组 ID
  /// [userId] 用户 ID
  /// [isPublic] 是否公开
  /// [token] 认证 token
  Future<void> toggleDeckPublic({
    required String deckId,
    required int userId,
    required bool isPublic,
    required String token,
  }) async {
    try {
      final body = jsonEncode({
        'deckId': deckId,
        'userId': userId,
        'isPublic': isPublic,
      });

      final uri = Uri.parse('$baseUrl/api/mdpro3/deck/public');
      final response = await _client
          .post(uri, headers: _authHeaders(token), body: body)
          .timeout(timeout);
      _ensureSuccess(response);
      _checkBusinessCode(response);
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// 点赞卡组
  ///
  /// [deckId] 卡组 ID
  Future<void> likeDeck(String deckId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/mdpro3/deck/like/$deckId');
      final response = await _client
          .post(uri, headers: _headers)
          .timeout(timeout);
      _ensureSuccess(response);
      _checkBusinessCode(response);
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // 内部工具
  // ---------------------------------------------------------------------------

  /// 解包 YGOMobile 风格信封 `{code, message, data}`：code==0 返回
  /// [data]，否则抛出携带服务端 message 的 [YgoCardDeckException]。
  /// 非信封响应（平铺 JSON）原样返回。
  static dynamic _unwrapEnvelope(dynamic body) {
    if (body is Map<String, dynamic> && body['code'] is int) {
      final code = body['code'] as int;
      if (code == 0) return body['data'];
      throw YgoCardDeckException(
        type: YgoCardDeckErrorType.serverError,
        message: (body['message'] as String?)?.isNotEmpty == true
            ? body['message'] as String
            : 'Server rejected request (code=$code)',
      );
    }
    return body;
  }

  /// 对无返回体的写操作（like/upload/delete/public）检查信封业务码，
  /// 例如点赞限流 `{code:10, message:"点赞过于频繁…"}`。非 JSON 响应忽略。
  static void _checkBusinessCode(http.Response response) {
    if (response.body.isEmpty) return;
    try {
      _unwrapEnvelope(jsonDecode(response.body));
    } on FormatException {
      // 非 JSON 响应（如纯文本 "true"）视为成功
    }
  }

  /// 归一化 YGOMobile 风格摘要/详情字段名为 [DeckSummary] /
  /// [MdPro3DeckInfo] 期望的键；平铺格式（自建服务）的键原样保留。
  static Map<String, dynamic> _normalizeSummary(Map<String, dynamic> r) => {
        'deckId': r['deckId'] ?? r['id'] ?? '',
        'name': r['name'] ?? r['deckName'] ?? '',
        'contributor': r['contributor'] ?? r['deckContributor'] ?? '',
        'userId': r['userId'] ?? 0,
        'likeCount': r['likeCount'] ?? r['deckLike'] ?? r['likes'] ?? 0,
        'isPublic': r['isPublic'] ?? true,
        'rank': r['rank'] ?? r['deckRank'] ?? 0,
        'coverCode': _coverOf(r),
        'createdAt': r['createdAt'] ?? _isoOf(r['deckUploadDate']),
        'updatedAt':
            r['updatedAt'] ?? _isoOf(r['deckUpdateDate'] ?? r['lastDate']),
        'description': r['description'] ?? '',
      };

  /// 封面卡：优先 coverCode / deckCoverCard1（都是卡牌编号）。
  ///
  /// 注意：deckCase 是「卡套」饰品编号（非卡牌），其图片走独立 CDN，
  /// 不能当作卡图 URL 使用（会 404 导致封面空白）。这里刻意不退回
  /// deckCase；无封面卡的卡组返回 null，由展示层渲染占位图。
  static int? _coverOf(Map<String, dynamic> r) {
    for (final key in const ['coverCode', 'deckCoverCard1']) {
      final v = r[key];
      if (v is int && v > 0) return v;
    }
    return null;
  }

  static String? _isoOf(dynamic epochMillis) {
    if (epochMillis is int && epochMillis > 0) {
      return DateTime.fromMillisecondsSinceEpoch(epochMillis)
          .toIso8601String();
    }
    return null;
  }

  /// 从 YGOMobile 详情记录构造 [MdPro3DeckInfo]，卡表解析自 deckYdk。
  static MdPro3DeckInfo _detailFromYdkRecord(Map<String, dynamic> r) {
    final (main, extra, side) = _parseYdk(r['deckYdk'] as String);
    final n = _normalizeSummary(r);
    return MdPro3DeckInfo(
      deckId: n['deckId'] as String,
      name: n['name'] as String,
      contributor: n['contributor'] as String,
      userId: n['userId'] as int,
      mainDeck: main,
      extraDeck: extra,
      sideDeck: side,
      likeCount: n['likeCount'] as int,
      rank: n['rank'] as int,
      createdAt: n['createdAt'] as String?,
      updatedAt: n['updatedAt'] as String?,
      description: n['description'] as String,
      coverCode: n['coverCode'] as int?,
    );
  }

  /// 解析 YDK 纯文本为 (main, extra, side) 卡表，重复卡合并数量。
  static (List<DeckCard>, List<DeckCard>, List<DeckCard>) _parseYdk(
    String ydk,
  ) {
    final mainMap = <int, int>{};
    final extraMap = <int, int>{};
    final sideMap = <int, int>{};
    var section = 0;
    for (final raw in ydk.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#') || line.startsWith('!')) {
        final marker = line.toLowerCase();
        if (marker.contains('extra')) {
          section = 1;
        } else if (marker.contains('side')) {
          section = 2;
        } else if (marker.contains('main')) {
          section = 0;
        }
        continue;
      }
      final id = int.tryParse(line);
      if (id != null && id > 0) {
        switch (section) {
          case 0:
            mainMap[id] = (mainMap[id] ?? 0) + 1;
          case 1:
            extraMap[id] = (extraMap[id] ?? 0) + 1;
          case 2:
            sideMap[id] = (sideMap[id] ?? 0) + 1;
        }
      }
    }
    List<DeckCard> toList(Map<int, int> m) =>
        m.entries.map((e) => DeckCard(code: e.key, count: e.value)).toList();
    return (toList(mainMap), toList(extraMap), toList(sideMap));
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw YgoCardDeckException(
        type: YgoCardDeckErrorType.unauthorized,
        message: 'Unauthorized',
        statusCode: response.statusCode,
      );
    }
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
