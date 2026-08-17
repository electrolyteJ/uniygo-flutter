import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'package:biz/duel/models/playmat_anchor_data.dart';

import 'duel_flame_game.dart';

/// A widget that displays a Flame game with a playmat duel.
class FlamePlaymatField extends StatelessWidget {
  final DuelFlameGame game;
  final ValueChanged<PlaymatAnchorData>? onAnchorsChanged;

  const FlamePlaymatField({
    super.key,
    required this.game,
    this.onAnchorsChanged,
  });

  @override
  Widget build(BuildContext context) {
    game.onAnchorsChanged = onAnchorsChanged;
    return GameWidget(game: game);
  }
}
