import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:resource_data/ygo_card_deck_exception.dart';

import 'card_table2_parser.dart';

/// Yugipedia MediaWiki API 客户端（https://yugipedia.com/api.php）。
///
/// 免费、无需鉴权；价值在多语言卡名/卡面文本（含简繁中文
/// `sc_name`/`sc_text`）。MW 1.31，响应结构为旧式
/// `revisions[0]['*']`（兼容 slots.main 形式）。
///
/// 卡密反查依赖 Yugipedia 的密码重定向页
/// （`titles=<code>&redirects=1` → 卡页）。
class YugipediaApiClient {
  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  YugipediaApiClient({
    http.Client? client,
    this.baseUrl = 'https://yugipedia.com/api.php',
    this.timeout = const Duration(seconds: 45),
  }) : _client = client ?? http.Client();

  /// 按卡密查询（经密码重定向页解析到卡页）。
  Future<YugipediaCard?> fetchCard(int code) async {
    final uri = _apiUri({
      'action': 'query',
      'format': 'json',
      'titles': '$code',
      'redirects': '1',
      'prop': 'revisions',
      'rvprop': 'content',
      'rvsection': '0',
    });
    final body = await _getBody(uri);
    return parseQueryResponse(body);
  }

  /// 按卡名前缀搜索并批量拉回卡数据。
  Future<List<YugipediaCard>> searchCards(
    String keyword, {
    int maxResults = 20,
  }) async {
    if (keyword.trim().isEmpty) return [];
    final searchUri = _apiUri({
      'action': 'query',
      'format': 'json',
      'list': 'prefixsearch',
      'pssearch': keyword.trim(),
      'pslimit': '$maxResults',
    });
    final titles = parsePrefixSearch(await _getBody(searchUri));
    if (titles.isEmpty) return [];

    // 批量拉取（一次请求多页，`|` 分隔标题）
    final batchUri = _apiUri({
      'action': 'query',
      'format': 'json',
      'titles': titles.join('|'),
      'redirects': '1',
      'prop': 'revisions',
      'rvprop': 'content',
      'rvsection': '0',
    });
    final cards = parseQueryResponseList(await _getBody(batchUri));
    // MW 的 pages 按 pageid 返回，与 prefixsearch 的相关性排序无关；
    // 按标题顺序重排（重定向解析后标题可能变化，未命中的保持原相对序排后）。
    final order = <String, int>{
      for (var i = 0; i < titles.length; i++) titles[i]: i,
    };
    final indexed = cards.asMap().entries.toList()
      ..sort((a, b) {
        final ia = order[a.value.nameEn] ?? titles.length;
        final ib = order[b.value.nameEn] ?? titles.length;
        return ia != ib ? ia.compareTo(ib) : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }

  // ── 响应解析（纯函数，便于测试）──

  /// 解析 query 响应为单卡（取第一个页面）。
  static YugipediaCard? parseQueryResponse(String body) {
    final cards = parseQueryResponseList(body);
    return cards.isEmpty ? null : cards.first;
  }

  /// 解析 query 响应为卡列表（批量 titles 场景）。
  static List<YugipediaCard> parseQueryResponseList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return const [];
    final query = decoded['query'];
    if (query is! Map<String, dynamic>) return const [];
    final pages = query['pages'];
    if (pages is! Map<String, dynamic>) return const [];

    final cards = <YugipediaCard>[];
    for (final page in pages.values) {
      if (page is! Map<String, dynamic>) continue;
      if (page.containsKey('missing')) continue;
      final revisions = page['revisions'];
      if (revisions is! List || revisions.isEmpty) continue;
      final rev = revisions.first;
      if (rev is! Map<String, dynamic>) continue;
      // MW 1.31：内容在 rev['*']；1.32+ slots 结构做兼容兜底。
      final content = rev['*'] ?? (rev['slots'] as Map?)?['main']?['*'];
      if (content is! String) continue;
      final card = CardTable2Parser.parse(
        content,
        pageTitle: page['title'] as String?,
      );
      if (card != null) cards.add(card);
    }
    return cards;
  }

  /// 解析 prefixsearch 响应为标题列表。
  static List<String> parsePrefixSearch(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return const [];
    final query = decoded['query'];
    if (query is! Map<String, dynamic>) return const [];
    final results = query['prefixsearch'];
    if (results is! List) return const [];
    return results
        .whereType<Map<String, dynamic>>()
        .map((e) => e['title'] as String? ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
  }

  // ── HTTP 层 ──

  Uri _apiUri(Map<String, String> params) =>
      Uri.parse(baseUrl).replace(queryParameters: params);

  Future<String> _getBody(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': 'uniygo-flutter/1.0'})
          .timeout(timeout);
      _ensureSuccess(response);
      return response.body;
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw YgoCardDeckException(
      type: response.statusCode >= 500
          ? YgoCardDeckErrorType.serverError
          : YgoCardDeckErrorType.clientError,
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
