import 'field_zone_key.dart';

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

  String get key => zoneKeyOf(controller, zone, sequence);
}
