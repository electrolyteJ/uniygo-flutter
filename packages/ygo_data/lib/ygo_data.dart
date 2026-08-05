import 'package:service_loader/service_loader.dart';
import 'card_info.dart';
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

/// 卡片资源服务
abstract class IDeckService implements IService {}

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
