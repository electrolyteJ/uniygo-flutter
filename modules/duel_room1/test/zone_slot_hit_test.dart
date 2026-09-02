import 'package:duel_room1/field/duel_flame_game.dart';
import 'package:duel_room1/field/util/duel_field_layout.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final viewport in const [Size(640, 360), Size(800, 450)]) {
    testWidgets('slot routing provides a unique 44px target at $viewport', (
      tester,
    ) async {
      final selected = <int?>[];
      final inspected = <String>[];
      final game = DuelFlameGame(
        onCardSelect: (_, code) => selected.add(code),
        onZoneInspect: inspected.add,
      );
      await tester.pumpWidget(
        SizedBox.fromSize(
          size: viewport,
          child: GameWidget(game: game),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      Offset screen(double x, double y) => game.worldToWidget(Vector2(x, y));

      final extraX = DuelFieldLayout.colX[0];
      const rowY = DuelFieldLayout.stY;
      await tester.tapAt(screen(extraX, rowY));
      await tester.pump(const Duration(milliseconds: 50));
      expect(inspected, ['self_extra']);
      expect(selected, isEmpty);

      // The outward edge is 22 screen pixels from the visual center.
      final zoom = game.camera.viewfinder.zoom;
      await tester.tapAt(screen(extraX - 22 / zoom, rowY));
      await tester.pump(const Duration(milliseconds: 50));
      expect(inspected, ['self_extra', 'self_extra']);
      expect(selected, isEmpty);

      // At low zoom adjacent 44px targets overlap. The Voronoi boundary
      // must resolve to exactly one callback, never both.
      final before = inspected.length + selected.length;
      final midpoint = (DuelFieldLayout.colX[0] + DuelFieldLayout.colX[1]) / 2;
      await tester.tapAt(screen(midpoint, rowY));
      await tester.pump(const Duration(milliseconds: 50));
      expect(inspected.length + selected.length, before + 1);
    });
  }
}
