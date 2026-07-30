import 'dart:ui';

import 'package:flame/components.dart' show Anchor;
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'duel_world.dart';
import 'field/field_layout.dart';
import 'models/duel_state.dart';

class DuelGame extends FlameGame with MultiTouchTapDetector {
  late final DuelWorld _world;

  DuelGame({required DuelState state}) {
    _world = DuelWorld(state: state);
  }

  DuelWorld get world_ => _world;

  @override
  Future<void> onLoad() async {
    world = _world;
    camera.viewfinder.anchor = Anchor.topLeft;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final cam = _world.camera;
    cam.viewportSize = Size(size.x, size.y);
    cam.fitHorizontal(FieldLayout.fitHalfWidth, FieldLayout.fitCorner);
  }

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    final pos = Offset(info.eventPosition.widget.x, info.eventPosition.widget.y);
    final hit = _world.cardsLayer.hitTest(pos);
    if (hit == null) return;
    final (card, index, isOpponent) = hit;
    final state = _world.state;
    if (!isOpponent && card.isMonster) {
      if (state.phase == DuelPhase.battle) {
        state.selectMonster(index);
      }
    } else if (isOpponent && card.isMonster) {
      state.attackTarget(index);
    } else if (isOpponent && !card.isMonster) {
      state.directAttack();
    }
  }
}
