import 'package:duel_room1/field/widgets/confirm/confirm_cards_panel.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
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

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('docked-panel'))),
    );
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

  testWidgets('桌面视口下停靠几何不变（上136/下126/右18/宽440）', (tester) async {
    // 桌面尺寸（≥760 高）：HUD 缩放恒 1.0，停靠几何保持设计值。
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

  testWidgets('手机横屏视口下面板收缩上下留白', (tester) async {
    tester.view.physicalSize = const Size(800, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    await tester.pumpAndSettle();

    final pos = tester.widget<Positioned>(
      find
          .ancestor(of: find.text('对方卡组'), matching: find.byType(Positioned))
          .first,
    );
    // compact 使用 8px 面板间距与 360px spec 宽度。
    expect(pos.top, closeTo(81.6, 0.001));
    expect(pos.bottom, closeTo(75.6, 0.001));
    expect(pos.right, 8);
    expect(pos.width, 360);
  });

  for (final entry in const [
    (Size(640, 360), 2),
    (Size(800, 450), 3),
    (Size(1280, 720), 4),
  ]) {
    testWidgets('${entry.$1} 确认网格使用 ${entry.$2} 列', (tester) async {
      tester.view
        ..physicalSize = entry.$1
        ..devicePixelRatio = 1;
      addTearDown(() {
        tester.view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });
      final s = buildSubject(
        panelCodes: List.generate(8, (index) => 1000 + index),
      );
      await tester.pumpWidget(s.widget);
      await tester.pumpAndSettle();

      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('confirm-cards-grid')),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, entry.$2);
      expect(tester.getSize(find.text('C1001')).width, greaterThan(0));
    });
  }

  testWidgets('844x390 非对称安全区内停靠且避开 HUD 与手牌栏', (tester) async {
    const size = Size(844, 390);
    const safePadding = EdgeInsets.fromLTRB(44, 0, 21, 16);
    final spec = DuelRoomLayoutSpec.resolve(size, safePadding: safePadding);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    final s = buildSubject();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: size,
          viewPadding: safePadding,
          padding: safePadding,
        ),
        child: DuelRoomLayout(spec: spec, child: s.widget),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(const ValueKey('docked-panel')));
    expect(rect.left, greaterThanOrEqualTo(spec.safeRect.left));
    expect(rect.right, lessThanOrEqualTo(spec.safeRect.right));
    expect(
      rect.top,
      greaterThanOrEqualTo(spec.safeRect.top + spec.topHudHeight),
    );
    expect(
      rect.bottom,
      lessThanOrEqualTo(spec.safeRect.bottom - spec.handBarHeight),
    );
  });
}
