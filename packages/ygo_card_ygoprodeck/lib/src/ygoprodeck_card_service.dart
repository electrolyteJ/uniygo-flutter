import 'dart:typed_data';

import 'package:ygo_data/ygo_data.dart';

import 'ygoprodeck_api_client.dart';

/// YGOPRODeck 卡数据服务（英文 TCG 数据 + 卡图 CDN）。
///
/// 免费、无需鉴权。不支持中文（中文需求见 ygo_card_yugipedia）。
/// 包内实现类统一命名 CardService（同 baige 约定）；
/// 公开入口是主库文件的 YgoprodeckCardService。
class CardService implements ICardService {
  final YgoprodeckApiClient _client;

  CardService({YgoprodeckApiClient? client})
    : _client = client ?? YgoprodeckApiClient();

  @override
  dynamic get envType => null;

  @override
  set envType(dynamic value) {}

  @override
  String getCardImageUrl(int code) => YgoprodeckApiClient.cardImageUrl(code);

  @override
  Future<Uint8List> getCardImage(int code) => _client.fetchCardImage(code);

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
  }) => _client.searchCombined(
    query: query,
    cardType: cardType,
    attribute: attribute,
    race: race,
    maxResults: maxResults,
  );

  /// 释放底层 http.Client。
  /// IService 无生命周期回调，service_loader 不会自动调用；
  /// 服务通常随 app 生命周期存活，仅手动管理实例时需要调用。
  void dispose() => _client.dispose();
}
