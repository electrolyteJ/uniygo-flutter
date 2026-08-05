import 'dart:developer' as console;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ygo_data/card_info.dart';
import 'package:ygo_data/lf_table.dart';
import 'package:ygo_data/ygo_data.dart';
import 'package:ygo_card_mycard/src/card_dao.dart';
import 'package:ygo_banlist_mycard/ygo_banlist_mycard.dart';
import 'card_database.dart';
import 'env_config.dart';
import 'dart:convert';
import 'httper.dart';

Future<File> _dbPath() async {
  final path = '${(await getApplicationDocumentsDirectory()).path}/cards.cdb';
  return File(path);
}

Future<File> _test_dbPath() async {
  final path =
      '${(await getApplicationDocumentsDirectory()).path}/test_cards.cdb';
  return File(path);
}

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

// =============================================================================
// BaseCardService
// =============================================================================

class BaseCardService implements ICardService {
  EnvConfig config;
  CardDao? _cardDao;
  final BanlistService _banlist = BanlistService();

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
    return _banlist.validateDeck(main, extra, side);
  }

  @override
  Future<Map<int, LfTable>> getAllLfTable() async {
    return _banlist.getAllLfTables();
  }

  @override
  Future<LfTable?> getLfTable(int hash) async {
    return _banlist.getLfTable(hash);
  }

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

  Future<String> fetchPreReleaseVersion() async {
    final version = config.stagingVersion;
    if (version == null) return '';
    final response = await fetch(version);
    return response.body.trim();
  }

  @override
  String getCardImageUrl(int code) => config.getCardImageUrl(code);

  @override
  Future<CardInfo?> getCard(int code) async {
    await _ensureDao();
    final result = await _cardDao!.getCard(code);
    if (result == null) return null;
    return toPackageCard(result);
  }

  @override
  Future<List<CardInfo>> searchCards(String keyword) async {
    await _ensureDao();
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
    await _ensureDao();
    final dbCards = await _cardDao!.searchCombined(
      query: query,
      cardType: cardType,
      attribute: attribute,
      race: race,
      maxResults: maxResults,
    );
    return dbCards.map(toPackageCard).toList();
  }

  Future<void> _ensureDao() async {
    if (_cardDao != null) return;
    final file = envType == EnvType.staging
        ? await _test_dbPath()
        : await _dbPath();
    await initDatabase(file.path);
    _cardDao = CardDatabase.instance.dao;
  }
}
