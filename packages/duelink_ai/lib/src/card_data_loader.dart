import 'package:applog/console.dart' as console;

import 'package:ocgcore/ocgcore.dart';
import 'package:service_loader/service_loader.dart';
import 'package:resource_data/card_info.dart';
import '../duelink_ai.dart';

/// ocgcore 卡牌数据加载器 —— [CardReader] 的实现对局引擎通过它读取卡数据。
///
/// 数据来源优先级：
/// [ICardService]（构造函数注入，或运行时通过 [ServiceFactory] 查找
///    已注册的实现 —— App 中为 ygo_card_mycard / ygo_card_baige）。
class CardDataLoader {
  final CardConverter _cardConverter;
  final _cache = <int, CardData>{};

  CardDataLoader({required this._cardConverter});

  /// 读取卡牌数据（ocgcore [CardReader] 签名）。
  Future<CardData?> load(int code) async {
    final cached = _cache[code];
    if (cached != null) return cached;

    CardData? data;

    final info = await _cardConverter(code);
    console.log('CardDataLoader: load code=$code info=$info');
    if (info != null) {
      data = _toCardData(info);
    }
    if (data != null) _cache[code] = data;
    return data;
  }

  /// 查询已加载卡片的等级（供 AI 策略同步查询；卡组在对局开始前已预加载）。
  int? levelOf(int code) => _cache[code]?.level;

  /// 查询已加载卡片的完整数据（供 ygo-agent 输入构建器同步查询）。
  ///
  /// 卡组在对局开始前已全量预加载，对局中命中的均为缓存热数据；
  /// 未命中返回 null（构建器退化为使用引擎查询到的原始值）。
  CardData? dataOf(int code) => _cache[code];

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
