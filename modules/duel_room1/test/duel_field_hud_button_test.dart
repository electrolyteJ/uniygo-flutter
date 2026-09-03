import 'package:duel_room1/field/duel_field_page.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact duel top HUD has status and timer but no back button', (
    tester,
  ) async {
    final spec = DuelRoomLayoutSpec.resolve(const Size(640, 360));
    await tester.pumpWidget(
      MaterialApp(
        home: DuelRoomLayout(
          spec: spec,
          child: Stack(
            children: [
              CompactDuelTopHud(
                status: const Text('opponent status'),
                timer: const Text('timer'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('opponent status'), findsOneWidget);
    expect(find.text('timer'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });
}
