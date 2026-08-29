import 'package:resource_data/card_info.dart';
import 'package:resource_data/ygo_data.dart';

import 'baige_api_client.dart';


class CardService implements ICardService {
  final BaigeApiClient _client;

  CardService({BaigeApiClient? client})
      : _client = client ?? BaigeApiClient();

  @override
  dynamic get envType => null;

  @override
  set envType(dynamic value) {}

  @override
  String getCardImageUrl(int code) => CardImageCdn.picHalf(code);

  @override
  getCardImage(int code) {
    // TODO: implement getCardImage
    throw UnimplementedError();
  }

  @override
  Future<CardInfo?> getCard(int code) => _client.fetchCard(code);

  @override
  Future<List<CardInfo>> searchCards(String keyword) =>
      _client.searchCards(keyword);

  @override
  Future<List<CardInfo>> searchCombined({
    String? query,
    int? cardType,
    int? attribute,
    int? race,
    int maxResults = 100,
  }) async {
    final keywords = <String>[];
    if (query != null && query.isNotEmpty) keywords.add(query);
    if (cardType != null) keywords.add('类型:$cardType');
    if (attribute != null) keywords.add('属性:$attribute');
    if (race != null) keywords.add('种族:$race');
    if (keywords.isEmpty) return [];
    return _client.searchCards(keywords.join(' '));
  }

  @override
  List<String> validateDeck(
    List<CardInfo> main,
    List<CardInfo> extra,
    List<CardInfo> side,
  ) {
    throw UnsupportedError('百鸽 API 不提供卡组校验');
  }

  void dispose() => _client.dispose();
}
