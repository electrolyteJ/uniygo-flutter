import 'dart:developer' as console;
import 'dart:typed_data';
import 'package:resource_data/ygo_data.dart';
import 'package:resource_card_mycard/src/card_dao.dart';
import 'db/card_database.dart';
import 'env_config.dart';
import 'dart:convert';
import 'httper.dart';

// =============================================================================
// CardService
// =============================================================================

class CardService implements ICardService {
  EnvConfig config;
  CardDao? _cardDao;

  CardService({required this.config});

  @override
  get envType => config.type;

  @override
  set envType(dynamic value) {
    config = EnvConfig.fromType(value);
    if (envType == EnvType.staging) {
      console.log('Staging environment detected, checking test database files...');
      // _test_dbPath().then((file) async {
      //   await CardDatabase.instance.dispose();
      //   await initDatabase(file.path);
      //   _cardDao = CardDatabase.instance.dao;
      // });
    } else {
      console.log('Desktop platform detected, checking database files...');
      // _dbPath().then((file) async {
      //   await CardDatabase.instance.dispose();
      //   await initDatabase(file.path);
      //   _cardDao = CardDatabase.instance.dao;
      // });
    }
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
  Future<Uint8List> getCardImage(int code) async {
    final rep = await fetch(getCardImageUrl(code));
    return rep.bodyBytes;
  }

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
    await ensureDao(envType);
    _cardDao = CardDatabase.instance.dao;
  }
}
