import 'package:duel_room1/field/duel_flame_game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('viewPadding remains publicly assignable before layout', () {
    final game = DuelFlameGame();

    game.viewPadding = const EdgeInsets.fromLTRB(44, 0, 21, 16);

    expect(game.viewPadding, const EdgeInsets.fromLTRB(44, 0, 21, 16));
  });
}
