import 'package:duelarena/widgets/field/cards_layer_component.dart';
import 'package:duelarena/widgets/field/scene_components.dart';
import 'package:flame/components.dart';

import 'models/duel_state.dart';
import 'widgets/field/zones_component.dart';
import 'widgets/field/field_layout.dart';
import 'widgets/field/projection.dart';

/// The duel scene, mirroring the world hierarchy of YGOProUnity_V2:
/// a field camera plus the field content (ground, zones, cards, FX).
class DuelWorld extends World {
  final DuelState state;

  /// The perspective camera used by every scene component to project
  /// world points onto the canvas. Configured like the Unity main camera.
  final FieldCamera camera;

  final List<ZonePosition> zones;

  late final CardsLayerComponent cardsLayer;

  DuelWorld({required this.state})
      : camera = FieldCamera.fromPitch(
          position: FieldLayout.cameraPosition,
          pitchDegrees: FieldLayout.cameraPitch,
          fovDegrees: FieldLayout.cameraFov,
        ),
        zones = FieldLayout.buildZones();

  @override
  Future<void> onLoad() async {
    cardsLayer = CardsLayerComponent(
      camera: camera,
      zones: zones,
      state: state,
    );
    await addAll([
      BackdropComponent(camera: camera),
      GroundComponent(camera: camera),
      ZonesComponent(camera: camera, zones: zones, state: state),
      cardsLayer,
      ParticlesComponent(camera: camera),
      VignetteComponent(camera: camera),
    ]);
  }
}
