import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:duelink/duelink.dart';
import 'package:uniygopro/stores/duel_room_state.dart';
import 'package:uniygopro/stores/match_store.dart';
import 'package:uniygopro/stores/side_store.dart';
import 'package:uniygopro/app.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MatchStore()),
          ChangeNotifierProvider(create: (_) => SideStore()),
        ],
        child: const UniygoproApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('uniygopro'), findsOneWidget);
    expect(find.text('开始对战'), findsOneWidget);
  });
}
