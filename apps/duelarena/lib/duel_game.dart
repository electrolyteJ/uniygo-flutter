import 'dart:ui';

import 'package:flame/components.dart' show Anchor;
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'models/duel_state.dart';
import 'duel_world.dart';
import 'widgets/field/field_layout.dart';

/// The duelarena Flame game: hosts the [DuelWorld] and looks at it through
/// Flame's [CameraComponent] (top-left anchored, since every scene component
/// does its own 3D projection to screen space).
class DuelGame extends FlameGame<DuelWorld> with MultiTouchTapDetector {
  DuelGame({super.world, super.camera});
  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final cam = world.camera;
    cam.viewportSize = Size(size.x, size.y);
    // Keep the whole field visible on narrow (portrait) screens — the same
    // job Unity's `fieldSize` zoom does.
    cam.fitHorizontal(FieldLayout.fitHalfWidth, FieldLayout.fitCorner);
  }

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    final pos = Offset(
      info.eventPosition.widget.x,
      info.eventPosition.widget.y,
    );
    final hit = world.cardsLayer.hitTest(pos);
    if (hit != null) {
      world.state.selectCard(hit.$1, zoneIndex: hit.$2);
    } else {
      world.state.selectCard(null);
    }
  }
}
