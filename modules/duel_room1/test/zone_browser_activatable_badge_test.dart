/// 区域浏览面板「可发动」金色高亮的 widget 测试。
///
/// 防回归：可发动卡必须有金底「可发动」角标 + 金色描边 + 呼吸光环，
/// 标题栏显示「N 可发动」计数 chip；不可发动卡不出现角标。
library;

import 'package:biz/duel/models/duel_menu.dart';
import 'package:duel_room1/field/widgets/inspector/zone_browser_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _panel({Set<int> activatable = const {}}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          ZoneBrowserPanel(
            zoneBrowserKey: 'self_grave',
            cards: const [
              ZoneBrowserCardEntry(sequence: 0, code: 1001),
              ZoneBrowserCardEntry(sequence: 1, code: 1002),
              ZoneBrowserCardEntry(sequence: 2, code: 1003),
            ],
            selectedCardSequence: null,
            onCardTap: (_, _) {},
            onClose: () {},
            activatableSequences: activatable,
          ),
        ],
      ),
    ),
  );
}

/// 收集所有 AnimatedContainer 描边颜色为 [color] 的数量。
int _borderColorCount(WidgetTester tester, Color color) {
  return tester
      .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
      .where((w) {
        final decoration = w.decoration;
        if (decoration is! BoxDecoration) return false;
        final border = decoration.border;
        if (border is! Border) return false;
        return border.top.color == color;
      })
      .length;
}

void main() {
  testWidgets('可发动卡显示金色角标与描边，标题栏显示计数 chip', (tester) async {
    await tester.pumpWidget(_panel(activatable: {0, 2}));
    // 光环脉冲是 repeat 动画，不能用 pumpAndSettle（永不 settle）。
    await tester.pump();

    // 两张可发动卡 → 两个「可发动」角标 + 标题栏「2 可发动」chip。
    expect(find.text('可发动'), findsNWidgets(2));
    expect(find.text('2 可发动'), findsOneWidget);

    // 角标底色为琥珀金。
    final badgeColors = tester
        .widgetList<Container>(find.byType(Container))
        .where((w) {
          final decoration = w.decoration;
          return decoration is BoxDecoration &&
              decoration.color == activatableGold;
        });
    expect(badgeColors, hasLength(2));

    // 两张可发动卡的 tile 描边为金色；剩一张不可发动卡为默认白 10%。
    expect(_borderColorCount(tester, activatableGold), 2);
    expect(
      _borderColorCount(tester, Colors.white.withValues(alpha: 0.1)),
      1,
    );
  });

  testWidgets('无可发动卡：无角标、无计数 chip、无金色描边', (tester) async {
    await tester.pumpWidget(_panel());
    await tester.pump();

    expect(find.textContaining('可发动'), findsNothing);
    expect(_borderColorCount(tester, activatableGold), 0);
  });
}
