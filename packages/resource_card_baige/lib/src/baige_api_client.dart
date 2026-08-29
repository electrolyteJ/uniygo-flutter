import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:resource_data/card_info.dart';
import 'package:resource_data/ygo_card_deck_exception.dart';

final class CardImageCdn {
  CardImageCdn._();

  static const _picBase = 'https://cdn.233.momobako.com/ygopro/pics';
  static const _webpJp = 'https://cdn.233.momobako.com/ygoimg/jp';
  static const _webpEn = 'https://cdn.233.momobako.com/ygoimg/en';
  static const _webpSc = 'https://cdn.233.momobako.com/ygoimg/sc';

  static String pic(int code) => '$_picBase/$code.jpg';

  static String picHalf(int code) => '$_picBase/$code.jpg!half';

  static String picThumb(int code) => '$_picBase/$code.jpg!thumb';

  static String picThumb2(int code) => '$_picBase/$code.jpg!thumb2';

  static String picArt(int code) => '$_picBase/$code.jpg!art';

  static String picArtP(int code) => '$_picBase/$code.jpg!artp';

  static String webpJp(int code) => '$_webpJp/$code.webp';

  static String webpEn(int code) => '$_webpEn/$code.webp';

  static String webpSc(int code) => '$_webpSc/$code.webp';
}

class BaigeApiClient {
  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  BaigeApiClient({
    http.Client? client,
    this.baseUrl = 'https://ygocdb.com',
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  Future<CardInfo?> fetchCard(int code) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v0/card/$code');
      final response =
          await _client.get(uri).timeout(timeout);
      _ensureSuccess(response);
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      return _parseCard(data);
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<CardInfo>> searchCards(String query, {int start = 0}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v0/').replace(
        queryParameters: {
          'search': query,
          if (start > 0) 'start': start.toString(),
        },
      );
      final response =
          await _client.get(uri).timeout(timeout);
      _ensureSuccess(response);
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return [];
      final result = data['result'];
      if (result is! List) return [];
      return result
          .map((e) => _parseSearchResult(e as Map<String, dynamic>))
          .where((c) => c != null)
          .cast<CardInfo>()
          .toList();
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, CardInfo?>> fetchCardset({
    List<int>? ids,
    List<int>? cids,
    List<String>? names,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (ids != null && ids.isNotEmpty) body['ids'] = ids;
      if (cids != null && cids.isNotEmpty) body['cids'] = cids;
      if (names != null && names.isNotEmpty) body['names'] = names;

      final uri = Uri.parse('$baseUrl/api/v0/cardset');
      final response = await _client
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(timeout);
      _ensureSuccess(response);
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return {};
      final map = <String, CardInfo?>{};
      for (final entry in data.entries) {
        if (entry.value is! Map<String, dynamic>) continue;
        map[entry.key] = _parseCard(entry.value as Map<String, dynamic>);
      }
      return map;
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  Future<Uint8List> fetchCardsZip() async {
    try {
      final uri = Uri.parse('$baseUrl/api/v0/cards.zip');
      final response =
          await _client.get(uri).timeout(const Duration(minutes: 5));
      _ensureSuccess(response);
      return response.bodyBytes;
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  Future<String> fetchCardsZipMd5() async {
    try {
      final uri = Uri.parse('$baseUrl/api/v0/cards.zip.md5');
      final response =
          await _client.get(uri).timeout(timeout);
      _ensureSuccess(response);
      return response.body.trim();
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, String>> fetchIdChangelog() async {
    try {
      final uri = Uri.parse('$baseUrl/api/v0/idChangelog.jsonp');
      final response =
          await _client.get(uri).timeout(timeout);
      _ensureSuccess(response);
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return {};
      return data.map((k, v) => MapEntry(k.toString(), v.toString()));
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  static CardInfo? _parseCard(Map<String, dynamic> json) {
    final code = json['id'];
    if (code is! int) return null;
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final text = json['text'] as Map<String, dynamic>? ?? {};
    final setcode = data['setcode'];
    return CardInfo(
      code: code,
      alias: (data['alias'] ?? 0) as int,
      setcode: setcode is List
          ? List<int>.from(setcode)
          : [setcode as int? ?? 0],
      type: (data['type'] ?? 0) as int,
      level: (data['level'] & 0xFFFF) as int,
      attribute: (data['attribute'] ?? 0) as int,
      race: (data['race'] ?? 0) as int,
      attack: (data['atk'] ?? 0) as int,
      defense: (data['def'] ?? 0) as int,
      lscale: ((data['level'] ?? 0) >> 24) & 0xFF,
      rscale: ((data['level'] ?? 0) >> 16) & 0xFF,
      linkMarker: (data['link_marker'] ?? 0) as int,
      name: (text['name'] ?? json['cn_name'] ?? '') as String,
      desc: (text['desc'] ?? '') as String,
    );
  }

  static CardInfo? _parseSearchResult(Map<String, dynamic> json) {
    final code = json['id'];
    if (code is! int) return null;
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final text = json['text'] as Map<String, dynamic>? ?? {};
    final setcode = data['setcode'];
    return CardInfo(
      code: code,
      alias: (data['alias'] ?? 0) as int,
      setcode: setcode is List
          ? List<int>.from(setcode)
          : [setcode as int? ?? 0],
      type: (data['type'] ?? 0) as int,
      level: (data['level'] & 0xFFFF) as int,
      attribute: (data['attribute'] ?? 0) as int,
      race: (data['race'] ?? 0) as int,
      attack: (data['atk'] ?? 0) as int,
      defense: (data['def'] ?? 0) as int,
      lscale: ((data['level'] ?? 0) >> 24) & 0xFF,
      rscale: ((data['level'] ?? 0) >> 16) & 0xFF,
      linkMarker: (data['link_marker'] ?? 0) as int,
      name: (text['name'] ?? json['cn_name'] ?? '') as String,
      desc: (text['desc'] ?? '') as String,
    );
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
    if (e is http.ClientException || e is HandshakeException || e is TlsException) {
      return YgoCardDeckException(
        type: YgoCardDeckErrorType.networkError,
        message: e is HandshakeException
            ? 'TLS handshake failed: ${e.message}'
            : e is TlsException
                ? 'TLS error: ${e.message}'
                : (e as http.ClientException).message,
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
