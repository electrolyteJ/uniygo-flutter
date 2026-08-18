import 'package:ygo_data/card_info.dart';

/// 召唤类别 —— cardlive 的权威分类。
///
/// 决斗内事件（biz `SummonEffectType`）与卡片鉴赏（`CardInfo` 位掩码）
/// 两个来源都映射到本枚举：
/// - 决斗场景：normal/special/flip/set + 仪式/融合/同调/超量/链接；
/// - 鉴赏场景：另含 pendulum/spell/trap（卡片类型展示）。
enum SummonCategory {
  normal,
  special,
  flip,
  set,
  ritual,
  fusion,
  synchro,
  xyz,
  link,
  pendulum,
  spell,
  trap;

  /// 中文标签（鉴赏 UI / 动效字幕）。
  String get label => switch (this) {
    SummonCategory.normal => '通常召唤',
    SummonCategory.special => '特殊召唤',
    SummonCategory.flip => '反转召唤',
    SummonCategory.set => '盖放',
    SummonCategory.ritual => '仪式召唤',
    SummonCategory.fusion => '融合召唤',
    SummonCategory.synchro => '同调召唤',
    SummonCategory.xyz => '超量召唤',
    SummonCategory.link => '链接召唤',
    SummonCategory.pendulum => '灵摆召唤',
    SummonCategory.spell => '魔法卡发动',
    SummonCategory.trap => '陷阱卡发动',
  };
}

/// 依据卡数据类型位掩码推断召唤类别（纯函数，便于测试）。
///
/// 多类别卡（如灵摆融合）取第一个命中项，优先级：
/// spell/trap > link > xyz > synchro > fusion > ritual > pendulum >
/// normal（无效果）/ special（其余效果怪兽）。
SummonCategory summonCategoryFromCard(CardInfo card) {
  final type = card.type;
  if ((type & 0x2) != 0) return SummonCategory.spell; // 魔法卡
  if ((type & 0x4) != 0) return SummonCategory.trap; // 陷阱卡
  if ((type & 0x4000000) != 0) return SummonCategory.link;
  if ((type & 0x800000) != 0) return SummonCategory.xyz;
  if ((type & 0x2000) != 0) return SummonCategory.synchro;
  if ((type & 0x40) != 0) return SummonCategory.fusion;
  if ((type & 0x80) != 0) return SummonCategory.ritual;
  if ((type & 0x1000000) != 0) return SummonCategory.pendulum;
  // 通常怪兽（TYPE_NORMAL 且非效果）
  if ((type & 0x10) != 0 && (type & 0x20) == 0) {
    return SummonCategory.normal;
  }
  return SummonCategory.special;
}
