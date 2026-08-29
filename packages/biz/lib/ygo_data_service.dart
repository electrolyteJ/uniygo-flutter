import 'dart:typed_data';

import 'package:service_loader/service_loader.dart';
import 'package:resource_data/ygo_data.dart';


class YgoDataService implements IService,IDeckService, ICardService, IBanlistService {
  final ICardService _cardService;
  final IDeckService _deckService;
  final IBanlistService _banlistService;

  /// 卡片信息缓存：code → CardInfo，由 [getCard] 填充，卡片数据按 code 不可变。
  final Map<int, CardInfo> _cardInfoCache = {};

  YgoDataService({
    required ICardService cardService,
    required IDeckService deckService,
    required IBanlistService banlistService,
  }) : _cardService = cardService,
       _deckService = deckService,
       _banlistService = banlistService;

  dynamic get envType => _cardService.envType;

  set envType(dynamic value) {
    _cardService.envType = value;
  }

  @override
  Future<Map<int, LfTable>> getAllLfTable() async {
    return _banlistService.getAllLfTable();
  }

  @override
  Future<LfTable?> getLfTable(int code) {
    return _banlistService.getLfTable(code);
  }

  @override
  List<String> validateDeck(
    List<CardInfo> main,
    List<CardInfo> extra,
    List<CardInfo> side,
  ) {
    return _banlistService.validateDeck(main, extra, side);
  }

  @override
  Future<Uint8List> getCardImage(int code) {
    return _cardService.getCardImage(code);
  }

  @override
  String getCardImageUrl(int code) {
    return _cardService.getCardImageUrl(code);
  }

  /// 获取卡片信息，命中缓存直接返回，未命中则查询底层服务并写入缓存。
  Future<CardInfo?> getCard(int code) async {
    final cached = _cardInfoCache[code];
    if (cached != null) return cached;
    final info = await _cardService.getCard(code);
    if (info != null) {
      _cardInfoCache[code] = info;
    }
    return info;
  }

  /// 同步读取已缓存的卡片信息，未缓存时返回 null。
  CardInfo? getCardCached(int code) => _cardInfoCache[code];

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

  @override
  Future<bool> deleteDeck(String deckKey) {
    return _deckService.deleteDeck(deckKey);
  }

  @override
  String exportToYdk(DeckInfo deck) {
    return _deckService.exportToYdk(deck);
  }

  @override
  Future<DeckInfo?> importFromYdk(String content, String deckKey) {
    return _deckService.importFromYdk(content, deckKey);
  }

  @override
  Future<DeckInfo?> loadDeck(String deckKey) {
    return _deckService.loadDeck(deckKey);
  }

  @override
  Future<List<DeckInfo>> loadDeckList() {
    return _deckService.loadDeckList();
  }

  @override
  Future<bool> saveDeck(DeckInfo deck) {
    return _deckService.saveDeck(deck);
  }
}
