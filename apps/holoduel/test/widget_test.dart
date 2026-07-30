import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holoduel/main.dart';
import 'package:holoduel/widgets/field/duel_field_3d.dart';

void main() {
  testWidgets('mode screen shows and solo duel starts', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HoloDuelApp());
    expect(find.text('决斗领域'), findsOneWidget);
    expect(find.text('单人挑战'), findsOneWidget);
    expect(find.text('双人对战'), findsOneWidget);

    await tester.tap(find.text('单人挑战'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(DuelField3d), findsOneWidget);
    expect(find.text('结束回合 END TURN'), findsOneWidget);
  });
}
