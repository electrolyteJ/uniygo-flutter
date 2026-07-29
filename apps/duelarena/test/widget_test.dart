import 'package:duelarena/main.dart';
import 'package:duelarena/widgets/field/field_layout.dart';
import 'package:duelarena/widgets/field/projection.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders the duel game', (WidgetTester tester) async {
    await tester.pumpWidget(const DuelArenaApp());
    await tester.pump();
    expect(find.byWidgetPredicate((w) => w is GameWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('camera frames all zones inside a portrait viewport', () {
    final cam = FieldCamera.fromPitch(
      position: FieldLayout.cameraPosition,
      pitchDegrees: FieldLayout.cameraPitch,
      fovDegrees: FieldLayout.cameraFov,
    );
    cam.viewportSize = const Size(390, 844);
    cam.fitHorizontal(FieldLayout.fitHalfWidth, FieldLayout.fitCorner);

    final zones = FieldLayout.buildZones();
    expect(zones.length, 30); // 15 zone kinds x 2 players

    for (final zone in zones) {
      // Zone centers must project on screen...
      final p = cam.project(zone.center);
      expect(p, isNotNull, reason: 'zone ${zone.kind} off-screen (null)');
      expect(p!.dx, inInclusiveRange(0, 390),
          reason: 'zone ${zone.kind} x out of viewport');
      expect(p.dy, inInclusiveRange(0, 844),
          reason: 'zone ${zone.kind} y out of viewport');

      // ...and so must all four corners of the zone rectangle.
      final hw = zone.width / 2;
      final hd = zone.depth / 2;
      for (final corner in [
        Vec3(zone.center.x - hw, 0, zone.center.z - hd),
        Vec3(zone.center.x + hw, 0, zone.center.z - hd),
        Vec3(zone.center.x + hw, 0, zone.center.z + hd),
        Vec3(zone.center.x - hw, 0, zone.center.z + hd),
      ]) {
        final c = cam.project(corner);
        expect(c, isNotNull, reason: 'zone ${zone.kind} corner culled');
        expect(c!.dx, inInclusiveRange(-1, 391),
            reason: 'zone ${zone.kind} corner x out of viewport');
        expect(c.dy, inInclusiveRange(-1, 845),
            reason: 'zone ${zone.kind} corner y out of viewport');
      }
    }
  });

  test('player zones sit nearer the camera than opponent zones', () {
    final cam = FieldCamera.fromPitch(
      position: FieldLayout.cameraPosition,
      pitchDegrees: FieldLayout.cameraPitch,
      fovDegrees: FieldLayout.cameraFov,
    );
    final zones = FieldLayout.buildZones();
    final playerMonster = FieldLayout.zone(zones, ZoneKind.monster,
        isOpponent: false, index: 2);
    final opponentMonster = FieldLayout.zone(zones, ZoneKind.monster,
        isOpponent: true, index: 2);
    expect(cam.depthOf(playerMonster.center),
        lessThan(cam.depthOf(opponentMonster.center)));
  });

  test('landscape viewport needs no camera pull-back', () {
    final cam = FieldCamera.fromPitch(
      position: FieldLayout.cameraPosition,
      pitchDegrees: FieldLayout.cameraPitch,
      fovDegrees: FieldLayout.cameraFov,
    );
    cam.viewportSize = const Size(1280, 720);
    cam.fitHorizontal(FieldLayout.fitHalfWidth, FieldLayout.fitCorner);
    expect(cam.position.x, FieldLayout.cameraPosition.x);
    expect(cam.position.y, FieldLayout.cameraPosition.y);
    expect(cam.position.z, FieldLayout.cameraPosition.z);
  });
}
