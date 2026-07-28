import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:ygo_card/card_info.dart';
import 'package:ygo_card/ygo_card_deck_exception.dart';
import 'package:ygo_card/lflist_info.dart';

import 'env_config.dart';

/// CDN 静态资源接口客户端
///
/// 负责从 CDN 获取卡牌数据库、禁限卡表、字符串、卡图等静态资源。
/// [baseUrl] 为 CDN 根地址，如 `https://cdn02.moecube.com:444`。
class CardApiClient {
  final http.Client _client;
  final EnvConfig config;
  final Duration timeout;

  CardApiClient({
    required this.config,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  // ---------------------------------------------------------------------------
  // 核心静态资源
  // ---------------------------------------------------------------------------

  /// 下载卡牌数据库 (cards.cdb) 原始字节
  ///
  /// 返回 SQLite 格式的数据库文件字节。
  Future<Uint8List> fetchCardDatabase() async {
    try {
      final uri = Uri.parse(config.cardDatabaseUrl);
      final response = await _client.get(uri).timeout(timeout);
      _ensureSuccess(response);
      return response.bodyBytes;
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// 获取禁限卡表
  Future<LflistInfo> fetchLflist() async {
    try {
      final uri = Uri.parse(config.lflistUrl);
      final response = await _client.get(uri).timeout(timeout);
      _ensureSuccess(response);
      return LflistInfo.parse(response.body);
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }



  /// 获取游戏字符串 (strings.conf)
  ///
  /// 按键值对格式返回: key=value 每行一个。
  Future<Map<String, String>> fetchStrings() async {
    try {
      final uri = Uri.parse(config.stringsUrl);
      final response = await _client.get(uri).timeout(timeout);
      _ensureSuccess(response);
      return _parseStrings(response.body);
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// 获取先行卡数据 (test-release.json)
  ///
  /// 路径: /ygopro-super-pre/data/test-release.json
  /// 返回卡牌列表，注意先行卡的数据结构可能与完整卡牌不同。
  Future<List<CardInfo>> fetchPreReleaseCards() async {
    try {
      final uri = Uri.parse(config.stagingCards!);
      final response = await _client.get(uri).timeout(timeout);
      _ensureSuccess(response);
      final list = jsonDecode(response.body);
      if (list is! List) return [];
      return list
          .map((e) => CardInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// 获取先行卡版本号
  ///
  /// 路径: /ygopro-super-pre/data/version.txt
  Future<String> fetchPreReleaseVersion() async {
    try {
      final uri = Uri.parse(config.stagingVersion!);
      final response = await _client.get(uri).timeout(timeout);
      _ensureSuccess(response);
      return response.body.trim();
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // 卡图
  // ---------------------------------------------------------------------------

  String getCardImageUrl(int code) => config.getCardImageUrl(code);

  Future<Uint8List> fetchCardImage(int code) =>
      _fetchBinary(getCardImageUrl(code));


  // ---------------------------------------------------------------------------
  // 内部工具
  // ---------------------------------------------------------------------------

  Future<Uint8List> _fetchBinary(String url) async {
    try {
      final response = await _client.get(Uri.parse(url)).timeout(timeout);
      _ensureSuccess(response);
      return response.bodyBytes;
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  Map<String, String> _parseStrings(String content) {
    final map = <String, String>{};
    for (final line in const LineSplitter().convert(content)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex > 0) {
        final key = trimmed.substring(0, eqIndex).trim();
        final value = trimmed.substring(eqIndex + 1).trim();
        map[key] = value;
      }
    }
    return map;
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
        message: 'Resource not found',
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
