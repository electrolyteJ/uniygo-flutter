// =============================================================================
//     ygo_card_deck — Card CDN + Deck Square API
// =============================================================================
//
//   Usage:
//   ```dart
//   import 'package:ygo_card_deck/ygo_card_deck.dart';
//
//   // 卡片 CDN 接口
//   final cardSvc = CardService();
//   final lflist = await cardSvc.fetchLflist();
//   final db = await cardSvc.downloadDatabase();
//   final imageUrl = cardSvc.getCardImageUrl(89631139);
//
//   // 卡组广场接口
//   final deckSvc = DeckService();
//   final page = await deckSvc.fetchDeckList(page: 1, size: 20);
//   final detail = await deckSvc.fetchDeckDetail(page.decks.first.deckId);
//   ```
// 模型
import 'dart:developer' as console;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'db/card_database.dart';
import 'db/dao/card_dao.dart';
import 'db/models/card_info.dart';
import 'models/lflist_info.dart';
import 'services/card_service.dart';
export 'models/card_info.dart';
export 'models/deck_info.dart';
export 'models/deck_list_page.dart';
export 'models/lflist_info.dart';

// 配置
export 'config/ygo_card_deck_config.dart';
export 'config/env_config.dart';

// 客户端 (供需要自定义 http.Client 的场景)
export 'clients/card_api_client.dart';
export 'clients/deck_api_client.dart';

// 服务
export 'services/card_service.dart';
export 'services/deck_service.dart';

// 异常
export 'exceptions/ygo_card_deck_exception.dart';

CardDatabase? _database;

Future<void> _initDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = '${dir.path}/cards.cdb';
  final file = File(dbPath);
  final cardService = CardService();
  if (!await file.exists() || await file.length() == 0) {
    console.log('Database file not found, downloading...');
    final bodyBytes = await cardService.downloadDatabase();
    if (bodyBytes.isNotEmpty) {
      console.log('Database downloaded, saving to $dbPath');
      await file.writeAsBytes(bodyBytes);
    } else {
      throw Exception('HTTP error');
    }
  }
  _database = CardDatabase.instance;
  await _database?.initialize(dbPath);
}

Future<CardInfo?> getCard(int code) async {
  if (_database == null || _database?.isOpen == false) await _initDatabase();
  final results = await _database!.dao.getCard(code);
  return results;
}

Future<List<CardInfo>> searchCards(String keyword) async {
  if (_database == null|| _database?.isOpen == false) await _initDatabase();
  final results = await _database!.dao.searchByName(keyword);
  return results;
}

Future<LflistInfo> fetchLflist() async {
  final cardService = CardService();
  final lflist = await cardService.fetchLflist();
  return lflist;
}
