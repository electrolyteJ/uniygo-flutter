import 'package:duel_room1/field/duel_field_game.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera reserves HUD geometry regardless of hand-bar visibility', () {
    const viewport = Size(1280, 800);
    final game = DuelFieldGame();

    game.onGameResize(Vector2(viewport.width, viewport.height));
    game.setLayoutSpec(DuelRoomLayoutSpec.fixed);

    final insets = cameraHudInsetsFor(hudVisible: true);
    const expectedTop = 96.0;
    const expectedBottom = 96.0;
    expect(insets.top, closeTo(expectedTop, 1e-6));
    expect(insets.bottom, closeTo(expectedBottom, 1e-6));
    // 纯函数仍保留 hudVisible 语义：隐藏时不产出预留。
    expect(cameraHudInsetsFor(hudVisible: false), EdgeInsets.zero);

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
