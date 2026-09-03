import 'package:duel_room1/field/components/phase_rail/phase_rail_component.dart';
import 'package:duel_room1/field/components/phase_rail/phase_rail_layout.dart';
import 'package:duel_room1/field/duel_field_game.dart';
import 'package:duel_room1/field/util/duel_field_layout.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _TapProbe extends PositionComponent with TapCallbacks {
  _TapProbe(Vector2 center)
    : super(
        position: center,
        size: Vector2.all(20),
        anchor: Anchor.center,
        priority: 100,
      );

  int taps = 0;

  @override
  void onTapUp(TapUpEvent event) {
    taps++;
  }
}

Future<DuelFieldGame> _pumpCompactGame(
  WidgetTester tester, {
  required Size size,
  required bool hudVisible,
  EdgeInsets viewPadding = EdgeInsets.zero,
}) async {
  final game = DuelFieldGame()..viewPadding = viewPadding;
  game.setHandBarsVisible(hudVisible);
  await tester.pumpWidget(
    SizedBox(
      width: size.width,
      height: size.height,
      child: GameWidget(game: game),
    ),
  );
  await tester.pump();
  await tester.pump();
  expect(game.compactHud, isTrue);
  expect(game.world.isLoaded, isTrue);
  expect(game.world.phaseRailComponent?.isLoaded, isTrue);
  return game;
}

double _boardRightScreenX(DuelFieldGame game) => game
    .worldToWidget(
      Vector2(DuelFieldLayout.lastColX + DuelFieldLayout.slotWidth / 2, 0),
    )
    .dx;

Rect _compactActionHitRect(PhaseRailComponent rail) =>
    PhaseRailLayout.hitRectForVisual(rail.actionButtonCompactScreenRect());

void main() {
  for (final hudVisible in [false, true]) {
    testWidgets('640x360 compact rail stays 8dp from board when HUD is '
        '${hudVisible ? 'visible' : 'hidden'}', (tester) async {
      final game = await _pumpCompactGame(
        tester,
        size: const Size(640, 360),
        hudVisible: hudVisible,
      );
      final rail = game.world.phaseRailComponent!;

      final gap = rail.railCompactScreenRect().left - _boardRightScreenX(game);

      expect(gap, closeTo(8, 1));
    });
  }

  testWidgets(
    'compact rail visual and 44dp action hit rect stay in asymmetric safeRect',
    (tester) async {
      final game = await _pumpCompactGame(
        tester,
        size: const Size(844, 390),
        hudVisible: true,
        viewPadding: const EdgeInsets.fromLTRB(47, 5, 23, 11),
      );
      final rail = game.world.phaseRailComponent!;
      final visualRect = rail.railCompactScreenRect();
      final hitRect = _compactActionHitRect(rail);

      expect(visualRect.left, greaterThanOrEqualTo(game.safeRect.left));
      expect(visualRect.right, lessThanOrEqualTo(game.safeRect.right));
      expect(hitRect.width, 44);
      expect(hitRect.left, greaterThanOrEqualTo(game.safeRect.left));
      expect(hitRect.right, lessThanOrEqualTo(game.safeRect.right));
    },
  );

  test('containsLocalPoint includes low-zoom 44dp action hit area', () async {
    final game = DuelFieldGame();
    game.onGameResize(Vector2(800, 600));
    await game.onLoad();
    game.camera.viewfinder.zoom = 0.4;

    final rail = PhaseRailComponent();
    await game.world.add(rail);
    await game.ready();

    final centerY =
        rail.size.y / 2 -
        PhaseRailLayout.actionButtonShift +
        PhaseRailLayout.actionButtonCenterY;
    final insideExpanded = Vector2(rail.size.x + 10, centerY);
    final outsideExpanded = Vector2(rail.size.x + 51, centerY);

    expect(insideExpanded.x, greaterThan(rail.size.x));
    expect(rail.containsLocalPoint(insideExpanded), isTrue);
    expect(rail.containsLocalPoint(outsideExpanded), isFalse);
  });

  test('event lookup rejects the adjacent board-side overlap point', () async {
    final game = DuelFieldGame();
    game.onGameResize(Vector2(800, 600));
    await game.onLoad();
    game.camera.viewfinder.zoom = 0.4;

    final rail = PhaseRailComponent();
    await game.world.add(rail);
    await game.ready();

    final adjacentBoardPoint = Vector2(
      DuelFieldLayout.lastColX + DuelFieldLayout.slotWidth / 2 + 4,
      120,
    );
    final outwardPoint = Vector2(
      PhaseRailLayout.centerX + PhaseRailLayout.actionButtonWidth / 2 + 20,
      PhaseRailLayout.actionButtonCenterY,
    );

    expect(
      game.world.componentsAtPoint(adjacentBoardPoint),
      isNot(contains(rail)),
    );
    expect(game.world.componentsAtPoint(outwardPoint), contains(rail));
  });

  testWidgets(
    'GameWidget routes directional rail hits without stealing board taps',
    (tester) async {
      var phaseTaps = 0;
      var surrenderTaps = 0;
      var enabled = true;
      final game = DuelFieldGame(
        onPhaseLampTap: () => phaseTaps++,
        isPhaseLampEnabled: () => enabled,
        onSurrenderTap: () => surrenderTaps++,
        isSurrenderEnabled: () => enabled,
      );
      await tester.pumpWidget(
        SizedBox(width: 800, height: 600, child: GameWidget(game: game)),
      );
      await tester.pump();
      await tester.pump();
      game.camera.viewfinder.zoom = 0.4;
      final rail = game.world.phaseRailComponent!;
      rail.compactMode = false;
      rail.notifyStateChanged();

      final boardPoint = Vector2(290, PhaseRailLayout.actionButtonCenterY);
      final probe = _TapProbe(boardPoint);
      game.world.add(probe);
      await tester.pump();
      expect(probe.isMounted, isTrue);

      Offset screenPoint(double x, double y) =>
          game.worldToWidget(Vector2(x, y));

      await tester.tapAt(screenPoint(boardPoint.x, boardPoint.y));
      await tester.pump(const Duration(milliseconds: 50));
      expect(probe.taps, 1);
      expect(phaseTaps, 0);
      expect(surrenderTaps, 0);

      const outwardX =
          PhaseRailLayout.centerX + PhaseRailLayout.actionButtonWidth / 2 + 20;
      await tester.tapAt(
        screenPoint(outwardX, PhaseRailLayout.actionButtonCenterY),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(phaseTaps, 1);
      expect(surrenderTaps, 0);
      expect(probe.taps, 1);

      await tester.tapAt(
        screenPoint(outwardX, PhaseRailLayout.surrenderButtonCenterY),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(phaseTaps, 1);
      expect(surrenderTaps, 1);

      enabled = false;
      rail.notifyStateChanged();
      await tester.tapAt(
        screenPoint(outwardX, PhaseRailLayout.actionButtonCenterY),
      );
      await tester.tapAt(
        screenPoint(outwardX, PhaseRailLayout.surrenderButtonCenterY),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(phaseTaps, 1);
      expect(surrenderTaps, 1);
      expect(probe.taps, 1);
    },
  );
}
