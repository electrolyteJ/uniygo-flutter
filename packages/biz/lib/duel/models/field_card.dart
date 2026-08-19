import 'field_zone_key.dart';

/// 场上的一张卡（含身份、位置、表示形式与数值；
/// 卡槽定位见 [zoneKeyOf]）。
class FieldCard {
  final int code;
  final int controller;
  final int zone;
  final int sequence;
  final int position;
  final int overlayCount;
  final bool disabled;
  final int? attack;
  final int? defense;
  final String? name;

  const FieldCard({
    required this.code,
    required this.controller,
    required this.zone,
    required this.sequence,
    this.position = 0,
    this.overlayCount = 0,
    this.disabled = false,
    this.attack,
    this.defense,
    this.name,
  });

  /// 卡槽标识（`controller_zone_sequence`，见 [zoneKeyOf]）。
  String get zoneKey => zoneKeyOf(controller, zone, sequence);
}
