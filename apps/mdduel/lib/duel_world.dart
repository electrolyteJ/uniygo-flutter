import 'package:flame/components.dart';

import 'field/cards_layer_component.dart';
import 'field/field_layout.dart';
import 'field/projection.dart';
import 'field/scene_components.dart';
import 'field/zones_component.dart';
import 'models/duel_state.dart';

class DuelWorld extends World {
  final DuelState state;
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
    cardsLayer = CardsLayerComponent(camera: camera, zones: zones, state: state);
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
