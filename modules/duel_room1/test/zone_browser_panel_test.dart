import 'package:biz/duel/models/duel_menu.dart';
import 'package:duel_room1/field/widgets/inspector/card_detail_drawer.dart';
import 'package:duel_room1/field/widgets/inspector/zone_browser_panel.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 区域浏览面板的非模态契约测试。
///
/// 核心行为：面板停靠右侧、无全屏遮罩——面板外的点击穿透到底层
/// （场地），不再触发关闭；关闭只走 × 按钮。
void main() {
  const cards = [
    ZoneBrowserCardEntry(sequence: 0, code: 1001),
    ZoneBrowserCardEntry(sequence: 1, code: 1002),
  ];

  /// 组装：底层放一个全屏手势记录器模拟场地，上面叠面板。
  /// 返回底层点击次数与关闭次数的记录对象。
  ({
    Widget widget,
    List<int> underlyingTaps,
    List<int> closeTaps,
    List<(int, int)> cardTaps,
  })
  buildSubject({
    List<ZoneBrowserCardEntry> entries = cards,
    int hiddenCount = 0,
    List<ActionMenuEntry> actions = const [],
    Set<int> activatableSequences = const {},
  }) {
    final underlyingTaps = <int>[];
    final closeTaps = <int>[];
    final cardTaps = <(int, int)>[];
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
            ZoneBrowserPanel(
              zoneBrowserKey: 'self_grave',
              cards: entries,
              selectedCardSequence: null,
              onCardTap: (seq, code) => cardTaps.add((seq, code)),
              onClose: () => closeTaps.add(1),
              cardNameBuilder: (code) => 'C$code',
              selectedActions: actions,
              hiddenCount: hiddenCount,
              activatableSequences: activatableSequences,
            ),
          ],
        ),
      ),
    );
    return (
      widget: widget,
      underlyingTaps: underlyingTaps,
      closeTaps: closeTaps,
      cardTaps: cardTaps,
    );
  }

  testWidgets('面板外点击穿透到底层，且不触发关闭', (tester) async {
    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    // 面板进场动画（220ms）播完后再断言/点击。
    await tester.pumpAndSettle();

    // 面板右侧停靠：左侧中央（100, 300）在面板外。
    await tester.tapAt(const Offset(100, 300));
    expect(s.underlyingTaps.length, 1, reason: '面板外点击应穿透到场地');
    expect(s.closeTaps, isEmpty, reason: '非模态面板点外不关闭');
  });

  testWidgets('面板区域内点击不穿透、不关闭', (tester) async {
    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    // 面板进场动画（220ms）播完后再断言/点击。
    await tester.pumpAndSettle();

    // 800x600 测试屏：右停靠面板（右 18、宽 440、上 136、下 126）
    // 覆盖 x 342..782、y 136..474，（700, 300）在面板内。
    await tester.tapAt(const Offset(700, 300));
    expect(s.underlyingTaps, isEmpty, reason: '面板自身区域不穿透');
    expect(s.closeTaps, isEmpty);
  });

  testWidgets('右上角关闭按钮触发 onClose', (tester) async {
    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    // 面板进场动画（220ms）播完后再断言/点击。
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    expect(s.closeTaps.length, 1);
  });

  testWidgets('卡片点击回调携带 sequence 与 code', (tester) async {
    final s = buildSubject();
    await tester.pumpWidget(s.widget);
    // 面板进场动画（220ms）播完后再断言/点击。
    await tester.pumpAndSettle();

    await tester.tap(find.text('C1001'));
    expect(s.cardTaps, [(0, 1001)]);
  });

  testWidgets('空态：hiddenCount>0 提示里侧不可见，否则提示没有卡片', (tester) async {
    final hidden = buildSubject(entries: const [], hiddenCount: 3);
    await tester.pumpWidget(hidden.widget);
    expect(find.text('该区域有 3 张里侧卡片，无法查看'), findsOneWidget);

    final empty = buildSubject(entries: const []);
    await tester.pumpWidget(empty.widget);
    expect(find.text('该区域当前没有卡片'), findsOneWidget);
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
          .ancestor(of: find.text('己方墓地'), matching: find.byType(Positioned))
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
          .ancestor(of: find.text('己方墓地'), matching: find.byType(Positioned))
          .first,
    );
    // compact 使用 8px 面板间距与 safeWidth 35% 的 spec 宽度。
    expect(pos.top, closeTo(81.6, 0.001));
    expect(pos.bottom, closeTo(75.6, 0.001));
    expect(pos.right, 8);
    expect(pos.width, 280);
  });

  testWidgets('带非对称安全区时面板完全位于 safeRect 内', (tester) async {
    const size = Size(844, 390);
    const safePadding = EdgeInsets.fromLTRB(44, 0, 21, 16);
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
        child: DuelRoomLayout(
          spec: DuelRoomLayoutSpec.resolve(size, safePadding: safePadding),
          child: s.widget,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(const ValueKey('docked-panel')));
    final safeRect = DuelRoomLayoutSpec.resolve(
      size,
      safePadding: safePadding,
    ).safeRect;
    expect(safeRect.contains(rect.topLeft), isTrue);
    expect(
      safeRect.contains(rect.bottomRight - const Offset(0.001, 0.001)),
      isTrue,
    );
  });

  for (final entry in const [
    (Size(640, 360), 2),
    (Size(800, 450), 2),
    (Size(1280, 720), 4),
    (Size(1920, 1080), 4),
  ]) {
    testWidgets('${entry.$1} 区域网格使用 ${entry.$2} 列', (tester) async {
      tester.view
        ..physicalSize = entry.$1
        ..devicePixelRatio = 1;
      addTearDown(() {
        tester.view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });
      final s = buildSubject(
        entries: List.generate(
          6,
          (index) => ZoneBrowserCardEntry(sequence: index, code: 1000 + index),
        ),
      );
      await tester.pumpWidget(s.widget);
      await tester.pumpAndSettle();

      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('zone-browser-grid')),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, entry.$2);
    });
  }

  testWidgets('详情抽屉关闭命中区为 44 且内容可滚动', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: CardDetailDrawer(cardCode: 1001, onClose: _noop),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('card-detail-close'))),
      const Size.square(44),
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  test('详情抽屉在 compact 安全区内且避开顶部 HUD 与底部手牌栏', () {
    final spec = DuelRoomLayoutSpec.resolve(
      const Size(844, 390),
      safePadding: const EdgeInsets.fromLTRB(44, 0, 21, 16),
    );
    final rect = cardDetailDrawerRect(spec);

    expect(spec.safeRect.contains(rect.topLeft), isTrue);
    expect(rect.right, lessThanOrEqualTo(spec.safeRect.right));
    expect(
      rect.top,
      greaterThanOrEqualTo(spec.safeRect.top + spec.topHudHeight),
    );
    expect(
      rect.bottom,
      lessThanOrEqualTo(spec.safeRect.bottom - spec.handBarHeight - 8),
    );
    expect(rect.width, greaterThanOrEqualTo(0));
    expect(rect.height, greaterThanOrEqualTo(0));
    expect(rect.width, spec.dockedPanelWidth);
  });

  testWidgets('compact 详情卡图不超过面板内容且内容可滚动', (tester) async {
    const size = Size(640, 360);
    final spec = DuelRoomLayoutSpec.resolve(size);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fromRect(
                rect: cardDetailDrawerRect(spec),
                child: DuelRoomLayout(
                  spec: spec,
                  child: const CardDetailDrawer(cardCode: 0, onClose: _noop),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final panelRect = tester.getRect(find.byType(CardDetailDrawer));
    final imageRect = tester.getRect(
      find.byKey(const ValueKey('card-detail-image')),
    );
    expect(panelRect.width, spec.dockedPanelWidth);
    expect(imageRect.left, greaterThan(panelRect.left));
    expect(imageRect.right, lessThan(panelRect.right));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('可发动的卡显示角标，未命中集合的不显示', (tester) async {
    final s = buildSubject(activatableSequences: const {1});
    await tester.pumpWidget(s.widget);
    // 可发动光环是 repeat 脉冲动画，pumpAndSettle 永不 settle——
    // 用定长 pump 等进场动画播完即可。
    await tester.pump(const Duration(milliseconds: 300));

    // 只有 sequence=1（C1002）一张可发动 → 恰好一个角标。
    expect(find.text('可发动'), findsOneWidget);
  });

  testWidgets('动作区渲染可执行动作按钮', (tester) async {
    var tapped = 0;
    final s = buildSubject(
      actions: [ActionMenuEntry(label: '特殊召唤', onTap: () => tapped++)],
    );
    await tester.pumpWidget(s.widget);
    // 面板进场动画（220ms）播完后再断言/点击。
    await tester.pumpAndSettle();

    expect(find.text('可直接执行的动作'), findsOneWidget);
    await tester.tap(find.text('特殊召唤'));
    expect(tapped, 1);
  });

  testWidgets('640x360 下 20 个动作可滚动到末项并点击', (tester) async {
    tester.view
      ..physicalSize = const Size(640, 360)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    var tapped = 0;
    final s = buildSubject(
      actions: List.generate(
        20,
        (index) => ActionMenuEntry(
          label: '动作$index',
          onTap: index == 19 ? () => tapped++ : () {},
        ),
      ),
    );
    await tester.pumpWidget(s.widget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('动作19'),
      100,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('zone-browser-actions-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('动作19')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('动作19'));
    expect(tapped, 1);
  });
}

void _noop() {}
