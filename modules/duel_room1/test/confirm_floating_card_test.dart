import 'package:duel_room1/field/widgets/confirm/confirm_floating_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 卡组顶/额外顶浮动确认卡的手势契约测试：
/// 点卡片 = 查看详情（onInspectCard），提前关闭只走右上角 ×（onDismiss）。
void main() {
  ({Widget widget, List<int> inspected, List<int> dismissTaps}) buildSubject({
    bool withInspect = true,
  }) {
    final inspected = <int>[];
    final dismissTaps = <int>[];
    final widget = MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConfirmFloatingCard(
            codes: const [1001, 1002],
            currentIndex: 1,
            title: '卡组顶部',
            cardNameBuilder: (code) => 'C$code',
            onDismiss: () => dismissTaps.add(1),
            onInspectCard: withInspect ? (code) => inspected.add(code) : null,
          ),
        ),
      ),
    );
    return (widget: widget, inspected: inspected, dismissTaps: dismissTaps);
  }

  testWidgets('点击卡片触发 onInspectCard 且不触发关闭', (tester) async {
    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('C1002'));
    expect(s.inspected, [1002], reason: '应带上当前展示卡的 code');
    expect(s.dismissTaps, isEmpty, reason: '点卡片不再是提前关闭');
  });

  testWidgets('右上角 × 触发 onDismiss 且不触发检视', (tester) async {
    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    expect(s.dismissTaps.length, 1);
    expect(s.inspected, isEmpty);
    expect(
      tester.getSize(find.byKey(const ValueKey('confirm-floating-close'))),
      const Size.square(44),
    );
  });

  testWidgets('关闭按钮提供单一明确的 button 语义', (tester) async {
    final semantics = tester.ensureSemantics();
    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    await tester.pumpAndSettle();

    final closeSemantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((widget) => widget.properties.label == '关闭');
    expect(closeSemantics, hasLength(1));
    expect(closeSemantics.single.properties.button, isTrue);
    expect(closeSemantics.single.properties.enabled, isTrue);
    semantics.dispose();
  });

  testWidgets('onInspectCard 为 null 时点卡片无效果', (tester) async {
    final s = buildSubject(withInspect: false);
    await tester.pumpWidget(s.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('C1002'));
    expect(s.inspected, isEmpty);
    expect(s.dismissTaps, isEmpty);
  });
}
