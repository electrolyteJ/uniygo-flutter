import 'package:duelarena/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('field scene golden', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DuelArenaApp());
    // Let the Flame game load and render a few frames.
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/field_scene.png'),
    );
  });
}
