import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:riverpod_sample/main.dart';

void main() {
  testWidgets('home shows sample entries', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: RiverpodSampleApp()),
    );

    expect(find.text('Counter (NotifierProvider)'), findsOneWidget);
    expect(find.text('Todos (AsyncNotifier)'), findsOneWidget);

    await tester.tap(find.text('Counter (NotifierProvider)'));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });
}
