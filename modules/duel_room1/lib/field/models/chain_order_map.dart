import 'package:biz/duel/models/chain_link.dart';
import 'package:biz/duel/models/field_zone_key.dart';
import 'package:duelink/duelink.dart'
    show
        CARD_ZONE_DECK,
        CARD_ZONE_FZONE,
        CARD_ZONE_GRAVE,
        CARD_ZONE_HAND,
        CARD_ZONE_EXTRA,
        CARD_ZONE_MZONE,
        CARD_ZONE_REMOVED,
        CARD_ZONE_SZONE;

/// 连锁序号按显示目标拆分后的映射。
///
/// - [field]：场上卡槽/区域堆槽位 key → 连锁序号（1 起），key 与
///   卡槽 key 体系一致（场上卡为 `controller_zone_sequence`，区域堆为
///   `self_grave` / `opp_extra` 等命名 key），供 Flame 卡槽组件直接读取；
/// - [selfHand] / [oppHand]：手牌序号（hand index）→ 连锁序号，
///   供手牌栏卡片组件标注。
typedef ChainOrderMaps = ({
  Map<String, int> field,
  Map<int, int> selfHand,
  Map<int, int> oppHand,
});

/// 把连锁链按显示目标拆成三组序号映射。
///
/// FZONE（场地魔法）归一化为魔陷区 5 号位，与 biz 的 _normalizeFieldZone
/// 语义一致；同一槽位多环连锁（如同区域连发）保留最大序号。
ChainOrderMaps buildChainOrderMaps(List<ChainLink> chains, int myController) {
  final field = <String, int>{};
  final selfHand = <int, int>{};
  final oppHand = <int, int>{};

  for (var i = 0; i < chains.length; i++) {
    final link = chains[i];
    final order = i + 1;
    final isSelf = link.controller == myController;
    var zone = link.zone;
    var sequence = link.sequence;
    if ((zone & CARD_ZONE_FZONE) != 0) {
      zone = CARD_ZONE_SZONE;
      sequence = 5;
    }

    if ((zone & CARD_ZONE_MZONE) != 0 || (zone & CARD_ZONE_SZONE) != 0) {
      field[zoneKeyOf(link.controller, zone, sequence)] = order;
      continue;
    }
    if ((zone & CARD_ZONE_HAND) != 0) {
      (isSelf ? selfHand : oppHand)[link.sequence] = order;
      continue;
    }
    final side = isSelf ? 'self' : 'opp';
    final String? pileKey = switch (zone) {
      CARD_ZONE_DECK => '${side}_deck',
      CARD_ZONE_GRAVE => '${side}_grave',
      CARD_ZONE_REMOVED => '${side}_removed',
      CARD_ZONE_EXTRA => '${side}_extra',
      _ => null,
    };
    if (pileKey != null) {
      field[pileKey] = order;
    }
  }

  return (field: field, selfHand: selfHand, oppHand: oppHand);
}
