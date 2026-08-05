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

  Future<Map<int, LfTable>> getAllLfTable() async {
    throw Exception('Not implemented');
  }

  Future<LfTable?> getLfTable(int code);

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

  List<String> validateDeck(
    List<CardInfo> main,
    List<CardInfo> extra,
    List<CardInfo> side,
  );
}

/// 卡片资源服务
abstract class IDeckService implements IService {}

@Service(YgoDataService)
class YgoDataService implements IService {
  dynamic get envType => _cardService.envType;

  ICardService _cardService = ServiceFactory.create<ICardService>();
  IDeckService _deckService = ServiceFactory.create<IDeckService>();

  set envType(dynamic value) {
    _cardService.envType = value;
  }

  Future<Map<int, LfTable>> getAllLfTable() async {
    return _cardService.getAllLfTable();
  }

  Future<LfTable?> getLfTable(int code) {
    return _cardService.getLfTable(code);
  }

  String getCardImageUrl(int code) {
    return _cardService.getCardImageUrl(code);
  }

  Future<CardInfo?> getCard(int code) {
    return _cardService.getCard(code);
  }

  Future<List<CardInfo>> searchCards(String keyword) {
    return _cardService.searchCards(keyword);
  }

  Future<List<CardInfo>> searchCombined({
    String? query,
    int? cardType,
    int? attribute,
    int? race,
    int maxResults = 100,
  }) {
    return _cardService.searchCombined(
      query: query,
      cardType: cardType,
      attribute: attribute,
      race: race,
      maxResults: maxResults,
    );
  }

  List<String> validateDeck(
    List<CardInfo> main,
    List<CardInfo> extra,
    List<CardInfo> side,
  ) {
    return _cardService.validateDeck(main, extra, side);
  }
}
