import 'field_card.dart';

/// 场上卡槽 key（`controller_zone_sequence`）的编解码。
/// 场上卡定位、就地选择高亮、槽位点击回调等跨层共用的 key 格式
/// 统一收敛在这里，不要在外层手工拼字符串。
String zoneKeyOf(int controller, int zone, int sequence) =>
    '${controller}_${zone}_$sequence';

/// [FieldCard] 的卡槽标识，等价于 [FieldCard.zoneKey]。
String fieldSlotId(FieldCard card) =>
    zoneKeyOf(card.controller, card.zone, card.sequence);

/// 解析卡槽 key；格式非法时返回 null。
({int controller, int zone, int sequence})? parseZoneKey(String key) {
  final parts = key.split('_');
  if (parts.length != 3) return null;
  final controller = int.tryParse(parts[0]);
  final zone = int.tryParse(parts[1]);
  final sequence = int.tryParse(parts[2]);
  if (controller == null || zone == null || sequence == null) return null;
  return (controller: controller, zone: zone, sequence: sequence);
}
