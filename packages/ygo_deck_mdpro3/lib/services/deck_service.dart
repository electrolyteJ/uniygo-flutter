import 'package:service_loader/service_loader.dart';
import 'package:ygo_data/ygo_data.dart';

import 'deck_api_client.dart';

/// 云端卡组广场服务
///
/// 实现 [IDeckService]：仅提供格式转换（YDK ↔ [DeckInfo]），
/// 云端操作由 [DeckApiClient] 提供。
///
class DeckService implements IDeckService {
  final DeckApiClient _client;

  DeckService({DeckApiClient? client}) : _client = client ?? DeckApiClient();

  @override
  Future<List<DeckInfo>> loadDeckList() {
    // int page = 1,
    //     int size = 20,
    // String? keyword,
    // bool sortLike = false,
    // bool sortRank = false,
    // String? contributor,
    // return _client.fetchDeckList(
    //   page: page,
    //   size: size,
    //   keyword: keyword,
    //   sortLike: sortLike,
    //   sortRank: sortRank,
    //   contributor: contributor,
    // );

    throw UnimplementedError(
      'loadDeckList is not supported, use ygo_deck_mycard',
    );
  }

  @override
  Future<DeckInfo?> loadDeck(String deckName) {
    throw UnimplementedError('loadDeck is not supported, use ygo_deck_mycard');
  }

  @override
  Future<bool> saveDeck(DeckInfo deck) {
    // required MdPro3DeckInfo deck,
    // required int userId,
    // required String contributor,
    // required String token,
    // return _client.uploadDeck(
    //   deck: deck,
    //   userId: userId,
    //   contributor: contributor,
    //   token: token,
    // );
    // required int userId,
    // required String token,
    // return _client.fetchUserDecks(userId: userId, token: token);
    throw UnimplementedError('loadDeck is not supported, use ygo_deck_mycard');
  }

  @override
  Future<bool> deleteDeck(String deckName) {
    //    required String deckId,
    //    required int userId,
    //    required String contributor,
    //    required String token,
    // return  _client.deleteDeck(
    //  deckId: deckId,
    //  userId: userId,
    //  contributor: contributor,
    //  token: token,
    //  );
    throw UnimplementedError(
      'deleteDeck is not supported, use ygo_deck_mycard',
    );
  }

  // ---------------------------------------------------------------------------
  // IDeckService — 格式转换（无依赖，直接实现）
  // ---------------------------------------------------------------------------

  @override
  String exportToYdk(DeckInfo deck) {
    final buffer = StringBuffer();
    buffer.writeln('#created by uniygopro');
    buffer.writeln('#main');
    for (final card in deck.mainDeck) {
      for (var i = 0; i < card.count; i++) {
        buffer.writeln(card.code);
      }
    }
    buffer.writeln('#extra');
    for (final card in deck.extraDeck) {
      for (var i = 0; i < card.count; i++) {
        buffer.writeln(card.code);
      }
    }
    buffer.writeln('!side');
    for (final card in deck.sideDeck) {
      for (var i = 0; i < card.count; i++) {
        buffer.writeln(card.code);
      }
    }
    return buffer.toString();
  }

  @override
  Future<DeckInfo?> importFromYdk(String content, String deckName) async {
    try {
      return _parseYdk(content, deckName);
    } catch (_) {
      return null;
    }
  }

  Future<MdPro3DeckInfo> fetchDeckDetail(String deckId) =>
      _client.fetchDeckDetail(deckId);

  Future<String> generateDeckId() => _client.generateDeckId();

  Future<void> toggleDeckPublic({
    required String deckId,
    required int userId,
    required bool isPublic,
    required String token,
  }) => _client.toggleDeckPublic(
    deckId: deckId,
    userId: userId,
    isPublic: isPublic,
    token: token,
  );

  Future<void> likeDeck(String deckId) => _client.likeDeck(deckId);

  // ---------------------------------------------------------------------------
  // YDK 解析
  // ---------------------------------------------------------------------------

  DeckInfo _parseYdk(String content, String deckName) {
    final lines = content.split('\n').map((l) => l.trim()).toList();
    final mainMap = <int, int>{};
    final extraMap = <int, int>{};
    final sideMap = <int, int>{};
    var section = 0;

    for (final line in lines) {
      if (line.startsWith('#') || line.startsWith('!')) {
        if (line.toLowerCase().contains('extra')) {
          section = 1;
        } else if (line.toLowerCase().contains('side')) {
          section = 2;
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

    return DeckInfo(
      deckName: deckName,
      mainDeck: mainMap.entries
          .map((e) => DeckCard(code: e.key, count: e.value))
          .toList(),
      extraDeck: extraMap.entries
          .map((e) => DeckCard(code: e.key, count: e.value))
          .toList(),
      sideDeck: sideMap.entries
          .map((e) => DeckCard(code: e.key, count: e.value))
          .toList(),
    );
  }
}
