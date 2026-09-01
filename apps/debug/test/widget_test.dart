// Debug Hub 冒烟测试：验证默认入口列出各模块预览页。
import 'package:debug/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Debug Hub 列出全部预览入口', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DebugHubPage()));

    expect(find.text('duel_room1 · 2D 场地预览'), findsOneWidget);
    expect(find.text('duel_room3 · 3D 场景预览'), findsOneWidget);
    expect(find.text('deck_editor3 · 卡组中心'), findsOneWidget);
  });
}
