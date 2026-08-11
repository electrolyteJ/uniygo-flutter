import 'dart:typed_data';

import 'package:service_loader/service_loader.dart';
import 'card_info.dart';
import 'deck_info.dart';
import 'lf_table.dart';

export 'card_info.dart';
export 'lf_table.dart';
export 'ygo_card_deck_exception.dart';
export 'deck_info.dart';
export 'deck_list_page.dart';

/// 卡片资源服务
abstract class ICardService implements IService {
  dynamic get envType;

  set envType(dynamic value);

  String getCardImageUrl(int code);
  Future<Uint8List> getCardImage(int code);
  Future<CardInfo?> getCard(int code);

  Future<List<CardInfo>> searchCards(String keyword);

  Future<List<CardInfo>> searchCombined({
    String? query,
    int? cardType,
    int? attribute,
    int? race,
    int maxResults = 100,
  });
}

/// 统一卡组服务接口
abstract class IDeckService implements IService {
  Future<List<DeckInfo>> loadDeckList();

  Future<DeckInfo?> loadDeck(String deckKey) {
    throw UnimplementedError('loadDeck is not implemented in IDeckService');
  }

  Future<bool> saveDeck(DeckInfo deck) {
    throw UnimplementedError('saveDeck is not implemented in IDeckService');
  }

  Future<bool> deleteDeck(String deckKey) {
    throw UnimplementedError('deleteDeck is not implemented in IDeckService');
  }

  /// 导出为 YDK 格式字符串
  String exportToYdk(DeckInfo deck) {
    throw UnimplementedError('exportToYdk is not implemented in IDeckService');
  }

  /// 从 YDK 格式字符串导入卡组
  Future<DeckInfo?> importFromYdk(String content, String deckKey) {
    throw UnimplementedError(
      'importFromYdk is not implemented in IDeckService',
    );
  }
}

abstract class IBanlistService implements IService {
  List<String> validateDeck(
    List<CardInfo> main,
    List<CardInfo> extra,
    List<CardInfo> side,
  ) {
    throw UnimplementedError(
      'validateDeck is not implemented in IBanlistService',
    );
  }

  Future<Map<int, LfTable>> getAllLfTable() async {
    throw UnimplementedError(
      'getAllLfTable is not implemented in IBanlistService',
    );
  }

  Future<LfTable?> getLfTable(int hash) async {
    throw UnimplementedError(
      'getLfTable is not implemented in IBanlistService',
    );
  }
}
