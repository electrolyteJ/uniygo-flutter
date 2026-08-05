import 'package:duelink_websocket/duelink_websocket.dart'
    show WebSocketDuelService;
import 'package:service_loader/service_loader.dart';
import 'package:uniygopro/services/deck_service.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';
import 'package:ygo_data/ygo_data.dart';


class YgoDataService implements IService {
  final ICardService _cardService;
  final IBanlistService _banlistService;

  YgoDataService({
    required ICardService cardService,
    required IBanlistService banlistService,
  }) : _cardService = cardService,
       _banlistService = banlistService;

  dynamic get envType => _cardService.envType;

  set envType(dynamic value) {
    _cardService.envType = value;
  }

  Future<Map<int, LfTable>> getAllLfTable() async {
    return _banlistService.getAllLfTable();
  }

  Future<LfTable?> getLfTable(int code) {
    return _banlistService.getLfTable(code);
  }

  List<String> validateDeck(
    List<CardInfo> main,
    List<CardInfo> extra,
    List<CardInfo> side,
  ) {
    return _banlistService.validateDeck(main, extra, side);
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
}
