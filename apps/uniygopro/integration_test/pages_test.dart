/// 简单页面（SidePage / MatchPage）与 SnackBar 工具函数测试。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uniygopro/util/snack_bar_util.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('showSnackBar 工具函数', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showSnackBar(context, '提示消息'),
                child: const Text('触发'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('触发'));
    await tester.pump();
    expect(find.text('提示消息'), findsOneWidget);
  });
}
