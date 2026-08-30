import 'package:duel_room1/field/widgets/confirm/confirm_cards_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 确认卡列表面板的非阻塞契约测试。
///
/// 确认消息不回包、不阻塞对局流程，因此不做居中模态：右停靠面板，
/// 面板外点击穿透到场地，关闭只走 × 按钮。
void main() {
  const codes = [1001, 1002, 1003];

  ({
    Widget widget,
    List<int> underlyingTaps,
    List<int> dismissTaps,
    List<int> inspectedCodes,
  })
  buildSubject({List<int> panelCodes = codes, bool withInspect = true}) {
    final underlyingTaps = <int>[];
    final dismissTaps = <int>[];
    final inspectedCodes = <int>[];
    final widget = MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => underlyingTaps.add(1),
              ),
            ),
            ConfirmCardsPanel(
              title: '对方卡组',
              codes: panelCodes,
              cardNameBuilder: (code) => 'C$code',
              onDismiss: () => dismissTaps.add(1),
              onInspectCard: withInspect
                  ? (code) => inspectedCodes.add(code)
                  : null,
            ),
          ],
        ),
      ),
    );
    return (
      widget: widget,
      underlyingTaps: underlyingTaps,
      dismissTaps: dismissTaps,
      inspectedCodes: inspectedCodes,
    );
  }

  testWidgets('面板外点击穿透到底层，且不触发关闭', (tester) async {
    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    expect(s.underlyingTaps.length, 1, reason: '非阻塞面板外点击应穿透');
    expect(s.dismissTaps, isEmpty, reason: '非模态面板点外不关闭');
  });

  testWidgets('面板区域内点击不穿透、不关闭', (tester) async {
    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(400, 300));
    expect(s.underlyingTaps, isEmpty);
    expect(s.dismissTaps, isEmpty);
  });

  testWidgets('关闭按钮触发 onDismiss', (tester) async {
    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    expect(s.dismissTaps.length, 1);
  });

  testWidgets('标题、张数与卡名渲染', (tester) async {
    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    await tester.pumpAndSettle();

    expect(find.text('对方卡组'), findsOneWidget);
    expect(find.text('3 张'), findsOneWidget);
    expect(find.text('C1001'), findsOneWidget);
    expect(find.text('C1003'), findsOneWidget);
  });

  testWidgets('点击卡片触发 onInspectCard，不关闭、不穿透', (tester) async {
    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('C1002'));
    expect(s.inspectedCodes, [1002], reason: '点卡应带上对应 code');
    expect(s.dismissTaps, isEmpty, reason: '检视不是关闭');
    expect(s.underlyingTaps, isEmpty, reason: '面板内点击不穿透');
  });

  testWidgets('onInspectCard 为 null 时点击卡片无效果', (tester) async {
    final s = buildSubject(withInspect: false);
    await tester.pumpWidget(s.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('C1002'));
    expect(s.inspectedCodes, isEmpty);
    expect(s.dismissTaps, isEmpty);
    expect(s.underlyingTaps, isEmpty);
  });

  testWidgets('空列表显示占位文案', (tester) async {
    final s = buildSubject(panelCodes: const []);
    await tester.pumpWidget(s.widget);
    await tester.pumpAndSettle();

    expect(find.text('没有可查看的卡片'), findsOneWidget);
  });

  testWidgets('面板停靠右侧：上 136、下 126、右 18、宽 440', (tester) async {
    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    await tester.pumpAndSettle();

    final pos = tester.widget<Positioned>(
      find
          .ancestor(of: find.text('对方卡组'), matching: find.byType(Positioned))
          .first,
    );
    expect(pos.top, 136);
    expect(pos.bottom, 126);
    expect(pos.right, 18);
    expect(pos.width, 440);
    expect(pos.left, isNull);
  });
}
