import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ygo_data/deck_info.dart';
import 'package:ygo_data/deck_list_page.dart';
import 'package:ygo_data/ygo_card_deck_exception.dart';

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
  final String baseUrl = "https://deck.moecube.com";
  final String reqSource = "MDPro3";
  final Duration timeout;

  DeckApiClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

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

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw const YgoCardDeckException(
          type: YgoCardDeckErrorType.parseError,
          message: 'Expected a JSON object',
        );
      }
      return DeckListPage.fromJson(data);
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

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw const YgoCardDeckException(
          type: YgoCardDeckErrorType.parseError,
          message: 'Expected a JSON object',
        );
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

      final data = jsonDecode(response.body);
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

      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .map((e) => MdPro3DeckInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data is Map<String, dynamic> && data.containsKey('decks')) {
        return (data['decks'] as List)
            .map((e) => MdPro3DeckInfo.fromJson(e as Map<String, dynamic>))
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
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // 内部工具
  // ---------------------------------------------------------------------------

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
