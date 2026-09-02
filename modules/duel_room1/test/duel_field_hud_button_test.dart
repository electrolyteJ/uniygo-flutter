import 'package:duel_room1/field/duel_field_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared production HUD builder keeps compact hit target at 44', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildDuelHudIconButton(
            icon: Icons.arrow_back,
            scale: 0.6,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('duel-hud-icon-hit-target'))),
      const Size.square(44),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('duel-hud-icon-visual'))),
      const Size.square(34),
    );
  });
}
