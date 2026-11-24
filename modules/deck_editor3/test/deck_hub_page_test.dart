/// 卡组中心三段式（市场 / 我的卡组 / 组卡器）的骨架行为。
///
/// 只验证结构契约，不触网：
/// - 三段在 [DeckHubPage] 内唯一存在；
/// - 未注入组卡器时降为两段，不留无法打开的入口；
/// - 组卡器与我的卡组均为懒构建（首次切换才实例化）。
library;

import 'package:deck_editor3/deck_editor3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('注入组卡器时展示三段', (tester) async {
    await tester.pumpWidget(
      _host(
        DeckHubPage(
          embedded: true,
          editorBuilder: (_) =>
              const SizedBox.shrink(key: ValueKey('fake-editor')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('卡组市场'), findsOneWidget);
    expect(find.text('我的卡组'), findsOneWidget);
    expect(find.text('组卡器'), findsOneWidget);
  });

  testWidgets('未注入组卡器时降为两段，不出现组卡器入口', (tester) async {
    await tester.pumpWidget(_host(const DeckHubPage(embedded: true)));
    await tester.pump();

    expect(find.text('卡组市场'), findsOneWidget);
    expect(find.text('我的卡组'), findsOneWidget);
    expect(find.text('组卡器'), findsNothing);
  });

  testWidgets('组卡器懒构建：切换前不实例化', (tester) async {
    await tester.pumpWidget(
      _host(
        DeckHubPage(
          embedded: true,
          editorBuilder: (_) =>
              const SizedBox.shrink(key: ValueKey('fake-editor')),
        ),
      ),
    );
    await tester.pump();

    // 首屏在市场段，组卡器尚未挂载。
    expect(find.byKey(const ValueKey('fake-editor')), findsNothing);

    await tester.tap(find.text('组卡器'));
    await tester.pump();

    expect(find.byKey(const ValueKey('fake-editor')), findsOneWidget);
  });

  testWidgets('切换我的卡组不抛异常（加载失败也走错误态）', (tester) async {
    await tester.pumpWidget(_host(const DeckHubPage(embedded: true)));
    await tester.pump();

    await tester.tap(find.text('我的卡组'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
  });

  testWidgets('内嵌模式不自建 AppBar，独立模式自带卡组中心标题', (tester) async {
    await tester.pumpWidget(_host(const DeckHubPage(embedded: true)));
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: DeckHubPage()));
    await tester.pump();
    expect(find.text('卡组中心'), findsOneWidget);
  });
}
