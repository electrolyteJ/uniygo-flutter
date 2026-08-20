import 'dart:typed_data';

import 'package:ygo_data/ygo_data.dart';

import 'yugipedia_api_client.dart';

/// Yugipedia 卡数据服务（多语言卡名/卡面文本，含简繁中文）。
///
/// 定位：多语言数据源。卡图直链 Yugipedia 不按卡密提供，
/// 卡图需求请配合 ygo_card_baige / ygo_card_ygoprodeck 使用。
class CardService implements ICardService {
  final YugipediaApiClient _client;

  CardService({YugipediaApiClient? client})
    : _client = client ?? YugipediaApiClient();

  @override
  dynamic get envType => null;

  @override
  set envType(dynamic value) {}

  /// Yugipedia 不提供按卡密的卡图直链。
  @override
  String getCardImageUrl(int code) =>
      throw UnsupportedError('Yugipedia 不提供按卡密直链卡图，请用其他卡图源');

  @override
  Future<Uint8List> getCardImage(int code) =>
      throw UnsupportedError('Yugipedia 不提供按卡密直链卡图，请用其他卡图源');

  /// 按卡密查询（经 Yugipedia 密码重定向页解析）。
  @override
  Future<CardInfo?> getCard(int code) async =>
      (await _client.fetchCard(code))?.info;

  /// 按卡名前缀搜索（Yugipedia prefixsearch，英文站标题）。
  @override
  Future<List<CardInfo>> searchCards(String keyword) async =>
      (await _client.searchCards(keyword)).map((c) => c.info).toList();

  /// Yugipedia 搜索仅支持卡名前缀；类型/属性/种族过滤不支持。
  @override
  Future<List<CardInfo>> searchCombined({
    String? query,
    int? cardType,
    int? attribute,
    int? race,
    int maxResults = 100,
  }) {
    if (cardType != null || attribute != null || race != null) {
      throw UnsupportedError('Yugipedia 搜索仅支持卡名前缀，不支持组合过滤');
    }
    return searchCards(query ?? '');
  }

  /// 释放底层 http.Client。
  /// IService 无生命周期回调，service_loader 不会自动调用；
  /// 服务通常随 app 生命周期存活，仅手动管理实例时需要调用。
  void dispose() => _client.dispose();
}
