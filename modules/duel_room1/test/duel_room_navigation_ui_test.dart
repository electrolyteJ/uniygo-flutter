import 'package:duel_room1/duel_room_page.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:duel_room1/platform/duel_immersive_mode.dart';
import 'package:duel_room1/platform/platform_adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only waiting stages show the room back button', () {
    expect(
      shouldShowDuelRoomBackButton(isInDuel: false, hasResult: false),
      isTrue,
    );
    expect(
      shouldShowDuelRoomBackButton(isInDuel: true, hasResult: false),
      isFalse,
    );
    expect(
      shouldShowDuelRoomBackButton(isInDuel: false, hasResult: true),
      isFalse,
    );
  });

  testWidgets('room shell owns immersive mode and never builds an AppBar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DuelRoomShell(
          platform: DuelPlatform.windows,
          isInDuel: false,
          hasResult: false,
          onBack: () {},
          content: const SizedBox(),
        ),
      ),
    );

    expect(find.byType(DuelImmersiveMode), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('duel-room-back-button')), findsOneWidget);
  });

  testWidgets('room shell hides its back button during duel and result', (
    tester,
  ) async {
    Future<void> pump({required bool isInDuel, required bool hasResult}) =>
        tester.pumpWidget(
          MaterialApp(
            home: DuelRoomShell(
              platform: DuelPlatform.windows,
              isInDuel: isInDuel,
              hasResult: hasResult,
              onBack: () {},
              content: const SizedBox(),
            ),
          ),
        );

    await pump(isInDuel: true, hasResult: false);
    expect(find.byKey(const ValueKey('duel-room-back-button')), findsNothing);
    await pump(isInDuel: false, hasResult: true);
    expect(find.byKey(const ValueKey('duel-room-back-button')), findsNothing);
  });

  testWidgets('room back button uses safe padding and opens exit action', (
    tester,
  ) async {
    var presses = 0;
    final spec = DuelRoomLayoutSpec.fixed;

    await tester.pumpWidget(
      MaterialApp(
        home: DuelRoomLayout(
          spec: spec,
          child: Stack(
            children: [DuelRoomBackButton(onPressed: () => presses++)],
          ),
        ),
      ),
    );

    final button = find.byKey(const ValueKey('duel-room-back-button'));
    expect(tester.getTopLeft(button), const Offset(18, 18));
    expect(tester.getSize(button), const Size.square(44));
    expect(find.byTooltip('退出房间'), findsOneWidget);

    await tester.tap(button);
    expect(presses, 1);
  });
}
