import 'package:duel_room1/field/duel_field_game.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('viewPadding remains publicly assignable before layout', () {
    final game = DuelFieldGame();

    game.viewPadding = const EdgeInsets.fromLTRB(44, 0, 21, 16);

    expect(game.viewPadding, const EdgeInsets.fromLTRB(44, 0, 21, 16));
  });

  for (final viewport in [const Size(640, 360), const Size(800, 450)]) {
    test('camera reserves HUD geometry regardless of hand-bar visibility at $viewport', () {
      final game = DuelFieldGame();
      final spec = DuelRoomLayoutSpec.resolve(viewport);

      game.onGameResize(Vector2(viewport.width, viewport.height));
      game.setLayoutSpec(spec);

      final insets = cameraHudInsetsFor(spec: spec, hudVisible: true);
      const expectedTop = 97.6;
      const expectedBottom = 65.6;
      expect(insets.top, closeTo(expectedTop, 1e-6));
      expect(insets.bottom, closeTo(expectedBottom, 1e-6));
      // 纯函数仍保留 hudVisible 语义：隐藏时不产出预留。
      expect(
        cameraHudInsetsFor(spec: spec, hudVisible: false),
        EdgeInsets.zero,
      );

      // 进房（手牌栏隐藏）即按 HUD 预留尺寸适配，进对局不再缩放跳变。
      final reservedZoom =
          (viewport.height - expectedTop - expectedBottom) / 510;
      expect(game.camera.viewfinder.zoom, closeTo(reservedZoom, 1e-6));

      game.setHandBarsVisible(true);
      expect(game.camera.viewfinder.zoom, closeTo(reservedZoom, 1e-6));

      game.setHandBarsVisible(false);
      expect(game.camera.viewfinder.zoom, closeTo(reservedZoom, 1e-6));
    });
  }
}
