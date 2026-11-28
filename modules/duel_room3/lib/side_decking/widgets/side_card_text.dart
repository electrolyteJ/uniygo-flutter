import 'package:resource_data/card_info.dart' show CardInfo;

/// 卡类副标：`怪兽 · 3 星 · 地属性` / `魔法 · 通常`。
///
/// 设计稿每张副卡组条目都有这样一行（531:2 的「怪兽 · 3 星 · 地属性」）。
/// 星级拼法按卡种区分：超量写「阶」，连接写「LINK-2」，灵摆怪兽同时给出
/// 等级与刻度——直接读 [CardInfo.level] 会因为超量是负值而显示成「-4 星」。
String sideCardSubtitle(CardInfo card) {
  final parts = <String>[];
  final typeText = card.typeText.trim();
  parts.add(typeText.isEmpty ? '未知' : typeText);

  if (card.isLink) {
    // 连接怪兽的 level 字段存的是 LINK 值（箭头数），语义上不是「星」。
    if (card.level > 0) parts.add('LINK-${card.level}');
  } else if (card.isMonster) {
    if (card.isXyz) {
      if (card.level != 0) parts.add('${card.level.abs()} 阶');
    } else if (card.level > 0) {
      parts.add('${card.level} 星');
    }
    if (card.attribute != 0) parts.add('${card.attributeText}属性');
  } else {
    // 魔法 / 陷阱：卡类里已含「通常 / 永续 / 速攻」等细分，补个阵营名即可。
    if (card.isSpell && parts.length == 1) parts.add('魔法');
    if (card.isTrap && parts.length == 1) parts.add('陷阱');
  }
  return parts.join(' · ');
}
