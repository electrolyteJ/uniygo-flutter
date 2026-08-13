import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bloc_sample/main.dart';

void main() {
  testWidgets('home shows sample entries', (WidgetTester tester) async {
    await tester.pumpWidget(const BlocSampleApp());

    expect(find.text('Counter (Cubit)'), findsOneWidget);
    expect(find.text('Todos (Bloc)'), findsOneWidget);

    await tester.tap(find.text('Counter (Cubit)'));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });
}
