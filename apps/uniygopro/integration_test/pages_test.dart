/// 简单页面（SidePage / MatchPage）与 SnackBar 工具函数测试。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:uniygopro/pages/create_room/match_page.dart';
import 'package:uniygopro/pages/create_room/match_store.dart';
import 'package:uniygopro/util/snack_bar_util.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();


  testWidgets('MatchPage 非搜索态渲染两个匹配按钮', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MatchStore(),
        child: _wrap(const MatchPage()),
      ),
    );
    expect(find.text('匹配对战'), findsOneWidget);
    expect(find.text('竞技匹配'), findsOneWidget);
    expect(find.text('娱乐匹配'), findsOneWidget);
    expect(find.text('正在搜索对手...'), findsNothing);
  });

  testWidgets('MatchPage 搜索态显示进度', (tester) async {
    final store = MatchStore()..startSearching('athletic');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: _wrap(const MatchPage()),
      ),
    );
    expect(find.text('正在搜索对手...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('showSnackBar 工具函数', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Builder(builder: (context) {
        return TextButton(
          onPressed: () => showSnackBar(context, '提示消息'),
          child: const Text('触发'),
        );
      }))),
    );
    await tester.tap(find.text('触发'));
    await tester.pump();
    expect(find.text('提示消息'), findsOneWidget);
  });
}
