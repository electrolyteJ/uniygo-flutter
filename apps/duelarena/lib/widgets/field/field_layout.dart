import 'projection.dart';

/// The kind of a field zone. Mirrors the CardLocation handling in
/// YGOProUnity_V2's SibylSystem/Ocgcore/Ocgcore.cs#get_point_worldposition.
enum ZoneKind { monster, spell, deck, extra, grave, banished, fieldSpell }

class ZonePosition {
  final Vec3 center;
  final double width;
  final double depth;
  final ZoneKind kind;
  final int index;
  final bool isOpponent;

  const ZonePosition({
    required this.center,
    required this.width,
    required this.depth,
    required this.kind,
    required this.index,
    required this.isOpponent,
  });

  bool get isMonster => kind == ZoneKind.monster;
  bool get isPile =>
      kind == ZoneKind.deck ||
      kind == ZoneKind.extra ||
      kind == ZoneKind.grave ||
      kind == ZoneKind.banished;
}

/// Duel field geometry, ported from YGOProUnity_V2 (master rule 4+,
/// fieldSize = 1). The Unity world uses card size 3 x 4.2 and zone
/// coordinates in roughly [-15.2, 14.65] x [-14.6, 14.6]; everything is
/// multiplied by [fieldScale] to bring it into this app's world units.
class FieldLayout {
  static const double fieldScale = 0.35;

  // Card metrics from YGOProUnity_V2 SibylSystem/Ocgcore/OCGobjects/gameCard.cs.
  static const double cardW = 3.0 * fieldScale; // 1.05
  static const double cardH = 4.2 * fieldScale; // 1.47

  /// Per-card vertical offset when stacking piles (Unity: 0.03/card).
  static const double stackStep = 0.03 * fieldScale;

  /// Zone rectangles are slightly larger than the cards, like Unity decals.
  static const double zoneW = cardW * 1.15;
  static const double zoneD = cardH * 1.15;

  // Main monster/spell columns (Ocgcore.cs, `switch (realIndex)`).
  static const List<double> columnX = [-10.1, -5.17, -0.27, 4.72, 9.62];
  static const double playerMonsterZ = -5.68;
  static const double opponentMonsterZ = 5.65;
  static const double playerSpellZ = -11.5;
  static const double opponentSpellZ = 11.5;

  // Corner zones (master rule 4+).
  static const double playerDeckX = 14.65;
  static const double playerDeckZ = -14.6;
  static const double opponentDeckX = -15.2;
  static const double opponentDeckZ = 14.6;
  static const double playerExtraX = -15.2;
  static const double playerExtraZ = -14.6;
  static const double opponentExtraX = 14.65;
  static const double opponentExtraZ = 14.6;
  static const double playerGraveX = 14.65;
  static const double playerGraveZ = -9.0;
  static const double opponentGraveX = -15.2;
  static const double opponentGraveZ = 9.0;
  static const double playerBanishedX = 14.65;
  static const double playerBanishedZ = -3.0;
  static const double opponentBanishedX = -15.2;
  static const double opponentBanishedZ = 3.0;
  static const double playerFieldSpellX = -15.2;
  static const double playerFieldSpellZ = -9.0;
  static const double opponentFieldSpellX = 14.65;
  static const double opponentFieldSpellZ = 9.0;

  // Ground quad and grid extents (a bit beyond the outermost zones).
  static const double groundHalfW = 19.0 * fieldScale;
  static const double groundNearZ = -18.0 * fieldScale; // behind player
  static const double groundFarZ = 18.0 * fieldScale; // behind opponent

  // Main camera (Assets/App/Scenes/AppMain.unity): pos (0, 23, -17.5),
  // 60 degree downward pitch, perspective FOV 75 (vertical).
  static final Vec3 cameraPosition =
      Vec3(0, 23 * fieldScale, -17.5 * fieldScale);
  static const double cameraPitch = 60;
  static const double cameraFov = 75;

  /// Half width (incl. zone margin) and the closest field corner used by
  /// [FieldCamera.fitHorizontal] to frame the field on portrait screens.
  static const double fitHalfWidth = 17.3 * fieldScale;
  static final Vec3 fitCorner =
      Vec3(15.2 * fieldScale, 0, playerDeckZ * fieldScale);

  static Vec3 _p(double x, double z) =>
      Vec3(x * fieldScale, 0, z * fieldScale);

  static ZonePosition _zone(
    double x,
    double z,
    ZoneKind kind,
    bool isOpponent, {
    int index = 0,
  }) {
    return ZonePosition(
      center: _p(x, z),
      width: zoneW,
      depth: zoneD,
      kind: kind,
      index: index,
      isOpponent: isOpponent,
    );
  }

  static List<ZonePosition> buildZones() {
    final zones = <ZonePosition>[];
    for (int i = 0; i < 5; i++) {
      // The opponent's columns are mirrored (Unity: realIndex = 4 - sequence).
      zones.add(_zone(columnX[i], playerMonsterZ, ZoneKind.monster, false,
          index: i));
      zones.add(
          _zone(columnX[i], playerSpellZ, ZoneKind.spell, false, index: i));
      zones.add(_zone(columnX[4 - i], opponentMonsterZ, ZoneKind.monster, true,
          index: i));
      zones.add(
          _zone(columnX[4 - i], opponentSpellZ, ZoneKind.spell, true, index: i));
    }

    // Player corner zones.
    zones.add(_zone(playerDeckX, playerDeckZ, ZoneKind.deck, false));
    zones.add(_zone(playerExtraX, playerExtraZ, ZoneKind.extra, false));
    zones.add(_zone(playerGraveX, playerGraveZ, ZoneKind.grave, false));
    zones.add(_zone(playerBanishedX, playerBanishedZ, ZoneKind.banished, false));
    zones.add(
        _zone(playerFieldSpellX, playerFieldSpellZ, ZoneKind.fieldSpell, false));

    // Opponent corner zones.
    zones.add(_zone(opponentDeckX, opponentDeckZ, ZoneKind.deck, true));
    zones.add(_zone(opponentExtraX, opponentExtraZ, ZoneKind.extra, true));
    zones.add(_zone(opponentGraveX, opponentGraveZ, ZoneKind.grave, true));
    zones.add(_zone(opponentBanishedX, opponentBanishedZ, ZoneKind.banished, true));
    zones.add(
        _zone(opponentFieldSpellX, opponentFieldSpellZ, ZoneKind.fieldSpell, true));

    return zones;
  }

  static ZonePosition zone(
    List<ZonePosition> zones,
    ZoneKind kind, {
    required bool isOpponent,
    int index = 0,
  }) {
    return zones.firstWhere((z) =>
        z.kind == kind && z.isOpponent == isOpponent && z.index == index);
  }
}
