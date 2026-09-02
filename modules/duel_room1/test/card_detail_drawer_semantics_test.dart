import 'package:duel_room1/field/widgets/inspector/card_detail_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' show Tristate;

void main() {
  testWidgets('close control has one enabled button semantics node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 324,
            height: 600,
            child: CardDetailDrawer(onClose: () {}),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('关闭'), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel('关闭'));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isTrue);
    semantics.dispose();
  });
}
