import 'package:service_loader/service_loader.dart';

import 'card_info.dart';
import 'lflist_info.dart';

/// 卡片资源服务
abstract class ICardService implements IService {
  dynamic get envType;
  set envType(dynamic value);
  Future<LflistInfo> fetchLflist();
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