import 'package:ocgcore/ocgcore.dart';
import 'package:service_loader/service_loader.dart';
import 'package:ygo_data/card_info.dart';
import 'package:ygo_data/ygo_data.dart';

import 'test_card_data.dart';

/// ocgcore 卡牌数据加载器 —— [CardReader] 的实现对局引擎通过它读取卡数据。
///
/// 数据来源优先级：
/// 1. [ICardService]（构造函数注入，或运行时通过 [ServiceFactory] 查找
///    已注册的实现 —— App 中为 ygo_card_mycard / ygo_card_baige）。
/// 2. 内置测试卡表 [kTestCards]（服务未注册或查询不到时兜底，
///    保证单元测试在无网络/无数据库环境下可用）。
class CardDataLoader {
  CardDataLoader({ICardService? cardService})
      : _cardService = cardService ?? _resolveCardService();

  final ICardService? _cardService;
  final _cache = <int, CardData>{};

  static ICardService? _resolveCardService() {
    if (!ServiceFactory.isRegistered<ICardService>()) return null;
    return ServiceFactory.create<ICardService>();
  }

  /// 读取卡牌数据（ocgcore [CardReader] 签名）。
  Future<CardData?> load(int code) async {
    final cached = _cache[code];
    if (cached != null) return cached;

    CardData? data;
    final info = await _cardService?.getCard(code);
    if (info != null) {
      data = _toCardData(info);
    } else {
      data = kTestCards[code];
    }
    if (data != null) _cache[code] = data;
    return data;
  }

  /// 查询已加载卡片的等级（供 AI 策略同步查询；卡组在对局开始前已预加载，
  /// 未命中缓存时退到测试卡表）。
  int? levelOf(int code) => _cache[code]?.level ?? kTestCards[code]?.level;

  static CardData _toCardData(CardInfo info) => CardData(
        code: info.code,
        alias: info.alias,
        setcode: info.setcode,
        type: info.type,
        level: info.level,
        attribute: info.attribute,
        race: info.race,
        attack: info.attack,
        defense: info.defense,
        lscale: info.lscale,
        rscale: info.rscale,
        linkMarker: info.linkMarker,
        ruleCode: 0,
        name: info.name,
        desc: info.desc,
      );
}
