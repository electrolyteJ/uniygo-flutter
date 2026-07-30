import 'duel_card.dart';

class FieldState {
  final List<DuelCard?> monsterZones;
  final List<DuelCard?> spellZones;
  DuelCard? fieldZone;
  int deckCount;
  int extraCount;
  int graveCount;
  int banishedCount;

  FieldState({
    List<DuelCard?>? monsterZones,
    List<DuelCard?>? spellZones,
    this.fieldZone,
    this.deckCount = 40,
    this.extraCount = 15,
    this.graveCount = 0,
    this.banishedCount = 0,
  })  : monsterZones = monsterZones ?? List.filled(5, null),
        spellZones = spellZones ?? List.filled(5, null);

  int get monsterCount => monsterZones.where((c) => c != null).length;
}
