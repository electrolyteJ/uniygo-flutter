import 'dart:developer' as console;
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:ygo_card/card_info.dart';
import 'package:ygo_card/lflist_info.dart';
import 'package:ygo_card/ygo_card.dart';
import 'package:ygo_card_mycard/src/card_dao.dart';
import 'card_database.dart';
import 'env_config.dart';
import 'dart:convert';

import 'package:ygo_card/ygo_card_deck_exception.dart';


/// 卡片资源服务
///
/// 封装 [CardApiClient]，提供高层级的卡片数据获取能力。
/// 管理 CDN 配置，支持多环境切换。
class BaseCardService implements ICardService {
  http.Client _client = http.Client();
  EnvConfig config;
  final Duration timeout;
  CardDao? _cardDao;
  BaseCardService({
    required this.config,
    this.timeout = const Duration(seconds: 30),
  }) {
    predownloadDatabase();
  }

  Future<File> _dbPath() async{
    final path = '${(await getApplicationDocumentsDirectory()).path}/cards.cdb';
    final file = File(path);
    return file;
  }
  Future<File> _test_dbPath() async {
    final path = '${(await getApplicationDocumentsDirectory()).path}/test_cards.cdb';
    final file = File(path);
    return file;
  }

  @override
  get envType => config.type;

  @override
  set envType(dynamic value) {
    config = EnvConfig.fromType(value);

    if (envType == EnvType.staging) {
      _test_dbPath().then((file) async {
        await CardDatabase.instance.dispose();
        await initDatabase(file.path);
        _cardDao = CardDatabase.instance.dao;
      });
    } else {
      _dbPath().then((file) async {
        await CardDatabase.instance.dispose();
        await initDatabase(file.path);
        _cardDao = CardDatabase.instance.dao;
      });
    }
  }


  void predownloadDatabase() {
    /// 下载完整的 cards.cdb 数据库文件
    ///
    /// 返回 SQLite 格式的字节数据，调用方可使用 sqflite 等库打开。
    ///
    _dbPath().then((file) async {
      console.log('Checking database file at ${file.path}');
      if (!await file.exists() || await file.length() == 0) {
        final bodyBytes = await fetchCardDatabase(
            EnvConfig.production.cardDatabaseUrl);
        console.log('Database file not found, downloading...');
        if (bodyBytes.isNotEmpty) {
          console.log('Database downloaded, saving to ${file.path}');
          await file.writeAsBytes(bodyBytes);
        } else {
          throw Exception('HTTP error');
        }
      }
      await initDatabase(file.path);
      _cardDao = CardDatabase.instance.dao;
    });
    _test_dbPath().then((file) async {
      console.log('Checking test database file at ${file.path}');
      if (!await file.exists() || await file.length() == 0) {
        final bodyBytes = await fetchCardDatabase(
            EnvConfig.staging.cardDatabaseUrl);
        final file = await _test_dbPath();
        console.log('Database file not found, downloading...');
        if (bodyBytes.isNotEmpty) {
          await file.writeAsBytes(bodyBytes);
          console.log('Database downloaded, saving to ${file.path}');
        } else {
          throw Exception('HTTP error');
        }
      }
    });


  }

  // ---------------------------------------------------------------------------
  // 核心静态资源
  // ---------------------------------------------------------------------------

  /// 下载卡牌数据库 (cards.cdb) 原始字节
  ///
  /// 返回 SQLite 格式的数据库文件字节。
  Future<Uint8List> fetchCardDatabase(String cardDatabaseUrl) async {
    try {
      final uri = Uri.parse(cardDatabaseUrl);
      final response = await _client.get(uri).timeout(timeout);
      _ensureSuccess(response);
      return response.bodyBytes;
    } on YgoCardDeckException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // 禁限卡表
  // ---------------------------------------------------------------------------

  /// 获取标准禁限卡表
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

  // ---------------------------------------------------------------------------
  // 字符串
  // ---------------------------------------------------------------------------

  /// 获取系统字符串表（系统提示、类别名称等）
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

  // ---------------------------------------------------------------------------
  // 先行卡
  // ---------------------------------------------------------------------------

  /// 获取先行卡/预发布卡列表
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
  /// 获取正式卡图 URL
  // ---------------------------------------------------------------------------
  // 卡图
  // ---------------------------------------------------------------------------

  String getCardImageUrl(int code) => config.getCardImageUrl(code);
  /// 下载卡图
  @override
  Future<Uint8List> downloadCardImage(int code) => _fetchBinary(getCardImageUrl(code));
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



  @override
  Future<CardInfo?> getCard(int code) async {
    if (_cardDao == null) {
      throw Exception('CardService not initialized. Call initDatabase() first.');
    }
    // _cardDao ??= await initDatabase();
    final result = await _cardDao!.getCard(code);
    if (result == null) return null;
    console.log('searchCards: found ${result} results for "$code ${envType}"');
    return toPackageCard(result);
  }

  @override
  Future<List<CardInfo>> searchCards(String keyword) async {
    if (_cardDao == null) {
      throw Exception('CardService not initialized. Call initDatabase() first.');
    }
    final results = await _cardDao!.searchByName(keyword);
    console.log('searchCards: found ${results.length} results for "$keyword ${envType}"');
    return results.map(toPackageCard).toList();
  }

  @override
  Future<List<CardInfo>> searchCombined({
    String? query,
    int? cardType,
    int? attribute,
    int? race,
    int maxResults = 100,
  }) async {
    if (_cardDao == null) {
      throw Exception('CardService not initialized. Call initDatabase() first.');
    }
    // _cardDao ??= await initDatabase();
    final dbCards = await _cardDao!.searchCombined(
      query: query,
      cardType: cardType,
      attribute: attribute,
      race: race,
      maxResults: maxResults,
    );
    console.log('searchCards: found ${dbCards.length} results for "$query ${envType}"');
    return dbCards.map(toPackageCard).toList();
  }
}
