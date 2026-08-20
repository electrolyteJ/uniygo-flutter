/// 连锁序号徽章（手牌等 Flutter 侧卡片共用）：实时显示、清空后停留 1s 淡出。
library;

import 'package:duel_room1/field/widgets/hud/chain_order_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildApp(int? number) => MaterialApp(
    home: Scaffold(body: Center(child: ChainOrderBadge(number: number))),
  );

  testWidgets('number 非空时显示序号', (tester) async {
    await tester.pumpWidget(buildApp(3));
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('number 为 null 且无历史时不显示', (tester) async {
    await tester.pumpWidget(buildApp(null));
    expect(find.byType(ChainOrderBadge), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('number 变 null 后停留 1s 再淡出，淡出结束后移除', (tester) async {
    await tester.pumpWidget(buildApp(2));
    expect(find.text('2'), findsOneWidget);

    await tester.pumpWidget(buildApp(null));
    // 停留期间仍显示
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('2'), findsOneWidget);

    // 停留结束开始淡出（300ms）
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2'), findsNothing);
  });

  testWidgets('停留期间新序号到来立即恢复并更新', (tester) async {
    await tester.pumpWidget(buildApp(1));
    await tester.pumpWidget(buildApp(null));
    await tester.pump(const Duration(milliseconds: 1100)); // 进入淡出
    await tester.pumpWidget(buildApp(4));

    expect(find.text('4'), findsOneWidget);
    final opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('4'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(opacity.opacity, 1.0);
  });
}
