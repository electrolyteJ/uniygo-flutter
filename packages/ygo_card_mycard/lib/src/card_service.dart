import 'dart:developer' as console;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ygo_card/card_info.dart';
import 'package:ygo_card/lf_table.dart';
import 'package:ygo_card/ygo_card.dart';
import 'package:ygo_card_mycard/src/card_dao.dart';
import 'card_database.dart';
import 'parse_lf_table.dart';
import 'deck_validator.dart';
import 'env_config.dart';
import 'dart:convert';
import 'httper.dart';


Future<File> _dbPath() async {
  final path = '${(await getApplicationDocumentsDirectory()).path}/cards.cdb';
  final file = File(path);
  return file;
}

Future<File> _test_dbPath() async {
  final path =
      '${(await getApplicationDocumentsDirectory()).path}/test_cards.cdb';
  final file = File(path);
  return file;
}
bool _banlistLoaded = false;

/// 下载完整的 cards.cdb 数据库文件到本地。
///
/// 同时下载生产环境和 staging 环境的数据库。已存在且非空的文件会跳过下载。
/// 完成后初始化 SQLite 数据库连接。
Future<void> preDownloadDatabase() async {
  final productionFile = await _dbPath();
  console.log('Checking database file at ${productionFile.path}');
  if (!await productionFile.exists() || await productionFile.length() == 0) {
    final response = await fetch(EnvConfig.production.cardDatabaseUrl);
    final bodyBytes = response.bodyBytes;
    console.log('Database file not found, downloading...');
    if (bodyBytes.isNotEmpty) {
      console.log('Database downloaded, saving to ${productionFile.path}');
      await productionFile.writeAsBytes(bodyBytes);
    } else {
      throw Exception('HTTP error');
    }
  }
  await initDatabase(productionFile.path);

  final stagingFile = await _test_dbPath();
  console.log('Checking test database file at ${stagingFile.path}');
  if (!await stagingFile.exists() || await stagingFile.length() == 0) {
    final response = await fetch(EnvConfig.staging.cardDatabaseUrl);
    final bodyBytes = response.bodyBytes;
    console.log('Database file not found, downloading...');
    if (bodyBytes.isNotEmpty) {
      console.log('Database downloaded, saving to ${stagingFile.path}');
      await stagingFile.writeAsBytes(bodyBytes);
    } else {
      throw Exception('HTTP error');
    }
  }
}

/// 加载禁限卡表到模块级缓存。
///
/// 应在应用启动时调用一次。后续 [BaseCardService.validateDeck] 会
/// 自动使用缓存数据，无需每个实例重复加载。
///
/// 同时建立 [lflistHashToName] 映射，用于将服务端返回的 hash 值
/// 转换为可读禁限卡表名称。
Future<void> preloadBanlist() async {
  if (_banlistLoaded) return;
  try {
    console.log('加载禁限卡表中...', name: 'DuelRoomStore');
    final raw = await fetch(EnvConfig.production.lflistUrl);
    parseLflistConf(raw.body);
    _banlistLoaded = true;
  } catch (e) {
    console.log('加载禁限卡表失败: $e', name: 'DuelRoomStore');
    _banlistLoaded = false;
  }
}

// =============================================================================
// BaseCardService
// =============================================================================

/// 卡片资源服务
///
/// 封装 [CardApiClient]，提供高层级的卡片数据获取能力。
/// 管理 CDN 配置，支持多环境切换。
class BaseCardService implements ICardService {
  EnvConfig config;
  CardDao? _cardDao;

  BaseCardService({required this.config});

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

  @override
  List<String> validateDeck(
    List<CardInfo> main,
    List<CardInfo> extra,
    List<CardInfo> side,
  ) {
    if (!_banlistLoaded) {
      throw Exception('Banlist not loaded. Call preloadBanlist() first.');
    }
    // 默认使用第一个卡表（当前最新 OCG 表）
    final lfInfos = lflistHashToTable.isNotEmpty ? lflistHashToTable.values.first.lfInfos : <int, LfInfo>{};
    final validator = DeckValidator(lfInfos: lfInfos);
    final result = validator.validate(main, extra, side);
    return result;
  }

  // ---------------------------------------------------------------------------
  // 禁限卡表
  // ---------------------------------------------------------------------------

  @override
  Future<Map<int,LfTable>> getAllLfTable() async {
      throw Exception('Not implemented');
  }

  @override
  Future<LfTable?> getLfTable(int hash) async {
    return getLflist(hash);
  }

  // ---------------------------------------------------------------------------
  // 字符串
  // ---------------------------------------------------------------------------

  /// 获取系统字符串表（系统提示、类别名称等）
  /// 获取游戏字符串 (strings.conf)
  ///
  /// 按键值对格式返回: key=value 每行一个。
  Future<Map<String, String>> fetchStrings() async {
    final response = await fetch(config.stringsUrl);
    return _parseStrings(response.body);
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
  // ---------------------------------------------------------------------------
  // 先行卡
  // ---------------------------------------------------------------------------

  /// 获取先行卡/预发布卡列表
  /// 获取先行卡数据 (test-release.json)
  ///
  /// 路径: /ygopro-super-pre/data/test-release.json
  /// 返回卡牌列表，注意先行卡的数据结构可能与完整卡牌不同。
  Future<List<CardInfo>> fetchPreReleaseCards() async {
    final cards = config.stagingCards;
    if (cards == null) return [];
    final response = await fetch(cards);
    final list = jsonDecode(response.body);
    if (list is! List) return [];
    return list
        .map((e) => CardInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取先行卡版本号
  /// 获取先行卡版本号
  ///
  /// 路径: /ygopro-super-pre/data/version.txt
  Future<String> fetchPreReleaseVersion() async {
    final version = config.stagingVersion;
    if (version == null) return '';
    final response = await fetch(version);
    return response.body.trim();
  }

  // ---------------------------------------------------------------------------
  // 卡图
  // ---------------------------------------------------------------------------
  /// 获取正式卡图 URL
  // ---------------------------------------------------------------------------
  // 卡图
  // ---------------------------------------------------------------------------

  String getCardImageUrl(int code) => config.getCardImageUrl(code);

  @override
  Future<CardInfo?> getCard(int code) async {
    if (_cardDao == null) {
      final File file;
      if (envType == EnvType.staging) {
        file = await _test_dbPath();
      } else {
        file = await _dbPath();
      }
      await initDatabase(file.path);
      _cardDao = CardDatabase.instance.dao;
    }
    if (_cardDao == null) {
      throw Exception(
        'CardService not initialized. Call initDatabase() first.',
      );
    }
    final result = await _cardDao!.getCard(code);
    if (result == null) return null;
    return toPackageCard(result);
  }

  @override
  Future<List<CardInfo>> searchCards(String keyword) async {
    if (_cardDao == null) {
      final File file;
      if (envType == EnvType.staging) {
        file = await _test_dbPath();
      } else {
        file = await _dbPath();
      }
      await initDatabase(file.path);
      _cardDao = CardDatabase.instance.dao;
    }
    if (_cardDao == null) {
      throw Exception(
        'CardService not initialized. Call initDatabase() first.',
      );
    }
    final results = await _cardDao!.searchByName(keyword);
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
      final File file;
      if (envType == EnvType.staging) {
        file = await _test_dbPath();
      } else {
        file = await _dbPath();
      }
      await initDatabase(file.path);
      _cardDao = CardDatabase.instance.dao;
    }
    if (_cardDao == null) {
      throw Exception(
        'CardService not initialized. Call initDatabase() first.',
      );
    }
    final dbCards = await _cardDao!.searchCombined(
      query: query,
      cardType: cardType,
      attribute: attribute,
      race: race,
      maxResults: maxResults,
    );
    return dbCards.map(toPackageCard).toList();
  }
}
