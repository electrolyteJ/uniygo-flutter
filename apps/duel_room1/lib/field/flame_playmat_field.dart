import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'package:duel_room1/field/duel_flame_game.dart';

/// A widget that displays a Flame game with a playmat duel.
class FlamePlaymatField extends StatelessWidget {
  final DuelFlameGame game;

  const FlamePlaymatField({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    // onAnchorsChanged 经构造注入（DuelFieldPage._ensureFlameGame），
    // 不在 build 里做副作用赋值。
    return GameWidget(game: game);
  }
}
