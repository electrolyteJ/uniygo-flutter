import 'package:service_loader/service_loader.dart';

import 'card_info.dart';
import 'lf_table.dart';

/// 卡片资源服务
abstract class ICardService implements IService {
  dynamic get envType;

  set envType(dynamic value);

  Future<Map<int,LfTable>> getAllLfTable() async {
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

  List<String> validateDeck(List<CardInfo> main,
      List<CardInfo> extra,
      List<CardInfo> side);
}
