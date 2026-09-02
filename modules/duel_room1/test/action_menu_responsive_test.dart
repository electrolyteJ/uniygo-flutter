import 'package:biz/duel/models/duel_menu.dart';
import 'package:biz/duel/models/field_card.dart';
import 'package:duel_room1/field/widgets/menus/duel_field_popover_layout.dart';
import 'package:duel_room1/field/widgets/menus/hand_action_menu.dart';
import 'package:duel_room1/field/widgets/menus/hand_action_popover.dart';
import 'package:duel_room1/field/widgets/menus/phase_action_menu.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_portal/flutter_portal.dart';

import 'responsive_test_harness.dart';

const _safePadding = EdgeInsets.fromLTRB(44, 8, 21, 16);

void main() {
  for (final size in responsiveViewports) {
    testWidgets('HandActionMenu 在 $size 内受限、可滚且可操作', (tester) async {
      var activated = 0;
      final interactiveActions = List.generate(
        20,
        (index) => ActionMenuEntry(
          label: '第 ${index + 1} 个非常长的可执行操作标签用于验证省略与响应式布局',
          onTap: () => activated = index + 1,
        ),
      );
      await pumpResponsiveWidget(
        tester,
        Center(child: HandActionMenu(actions: interactiveActions)),
        size,
        safePadding: _safePadding,
      );

      final menu = find.byKey(const ValueKey('hand-action-menu'));
      final spec = DuelRoomLayoutSpec.resolve(size, safePadding: _safePadding);
      final rect = tester.getRect(menu);
      expect(rect.width, lessThanOrEqualTo(220));
      expect(
        rect.width,
        spec.safeRect.width < 220 + spec.pagePadding * 2
            ? spec.safeRect.width - spec.pagePadding * 2
            : 220,
      );
      expect(rect.height, lessThanOrEqualTo(spec.safeRect.height * .7 + .01));
      expect(spec.safeRect.contains(rect.topLeft), isTrue);
      expect(spec.safeRect.contains(rect.bottomRight), isTrue);
      expect(
        find.descendant(of: menu, matching: find.byType(Scrollable)),
        findsOneWidget,
      );

      final first = find.byKey(const ValueKey('hand-action-0'));
      expect(tester.getSize(first).height, greaterThanOrEqualTo(44));
      expect(tester.getSemantics(first).flagsCollection.isButton, isTrue);
      final scrollable = find.descendant(
        of: menu,
        matching: find.byType(Scrollable),
      );
      for (var index = 0; index < interactiveActions.length; index++) {
        final item = find.byKey(ValueKey('hand-action-$index'));
        await tester.scrollUntilVisible(item, 52, scrollable: scrollable);
        expect(tester.getSize(item).height, greaterThanOrEqualTo(44));
      }
      final last = find.byKey(const ValueKey('hand-action-19'));
      await tester.ensureVisible(last);
      await tester.pump();
      await tester.tap(last);
      expect(activated, 20);

      activated = 0;
      await tester.scrollUntilVisible(first, -52, scrollable: scrollable);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(activated, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PhaseActionMenu 在 $size 内滚动且每项至少 44', (tester) async {
      var activated = 0;
      final interactiveActions = List.generate(
        20,
        (index) => ActionMenuEntry(
          label: '第 ${index + 1} 个非常长的阶段操作标签用于验证响应式布局',
          onTap: () => activated = index + 1,
        ),
      );
      await pumpResponsiveWidget(
        tester,
        Center(child: PhaseActionMenu(actions: interactiveActions)),
        size,
        safePadding: _safePadding,
      );
      final menu = find.byKey(const ValueKey('phase-action-menu'));
      final spec = DuelRoomLayoutSpec.resolve(size, safePadding: _safePadding);
      final rect = tester.getRect(menu);
      expect(rect.width, menuWidthFor(spec));
      expect(rect.height, lessThanOrEqualTo(spec.safeRect.height * .7 + .01));
      expect(spec.safeRect.contains(rect.topLeft), isTrue);
      expect(spec.safeRect.contains(rect.bottomRight), isTrue);
      expect(
        find.descendant(of: menu, matching: find.byType(Scrollable)),
        findsOneWidget,
      );
      final scrollable = find.descendant(
        of: menu,
        matching: find.byType(Scrollable),
      );
      for (var index = 0; index < interactiveActions.length; index++) {
        final item = find.byKey(ValueKey('phase-action-$index'));
        await tester.scrollUntilVisible(item, 52, scrollable: scrollable);
        expect(tester.getSize(item).height, greaterThanOrEqualTo(44));
      }
      final last = find.byKey(const ValueKey('phase-action-19'));
      await tester.ensureVisible(last);
      await tester.pump();
      await tester.tap(last);
      expect(activated, 20);

      activated = 0;
      final first = find.byKey(const ValueKey('phase-action-0'));
      await tester.scrollUntilVisible(first, -52, scrollable: scrollable);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(activated, 1);
      expect(tester.takeException(), isNull);
    });
  }

  test('popoverArrowDx follows anchors after horizontal boundary shift', () {
    const safeRect = Rect.fromLTWH(44, 8, 575, 336);
    expect(
      popoverArrowDx(
        anchorRect: const Rect.fromLTWH(44, 100, 20, 30),
        safeRect: safeRect,
        menuWidth: 220,
      ),
      10,
    );
    expect(
      popoverArrowDx(
        anchorRect: const Rect.fromLTWH(599, 100, 20, 30),
        safeRect: safeRect,
        menuWidth: 220,
      ),
      210,
    );
    expect(
      popoverArrowDx(
        anchorRect: const Rect.fromLTWH(300, 100, 20, 30),
        safeRect: safeRect,
        menuWidth: 220,
      ),
      110,
    );
  });

  test('SafeAligned equality includes safePadding and parent fields', () {
    const first = SafeAligned(
      follower: Alignment.bottomCenter,
      target: Alignment.topCenter,
      offset: Offset(0, -8),
      safePadding: EdgeInsets.only(left: 20),
    );
    const same = SafeAligned(
      follower: Alignment.bottomCenter,
      target: Alignment.topCenter,
      offset: Offset(0, -8),
      safePadding: EdgeInsets.only(left: 20),
    );
    const differentPadding = SafeAligned(
      follower: Alignment.bottomCenter,
      target: Alignment.topCenter,
      offset: Offset(0, -8),
      safePadding: EdgeInsets.only(left: 120),
    );
    const differentParentField = SafeAligned(
      follower: Alignment.bottomCenter,
      target: Alignment.topCenter,
      offset: Offset(0, -4),
      safePadding: EdgeInsets.only(left: 20),
    );
    const base = Aligned(
      follower: Alignment.bottomCenter,
      target: Alignment.topCenter,
      offset: Offset(0, -8),
    );

    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first, isNot(differentPadding));
    expect(first.hashCode, isNot(differentPadding.hashCode));
    expect(first, isNot(differentParentField));
    expect((first as Object) == base, isFalse);
    expect((base as Object) == first, isFalse);
  });

  for (final menuType in ['hand', 'phase']) {
    testWidgets('$menuType Tab traverses and scrolls through all 20 actions', (
      tester,
    ) async {
      var activated = 0;
      final actions = List.generate(
        20,
        (index) => ActionMenuEntry(
          label: '操作 ${index + 1}',
          onTap: () => activated = index + 1,
        ),
      );
      await pumpResponsiveWidget(
        tester,
        Center(
          child: menuType == 'hand'
              ? HandActionMenu(actions: actions)
              : PhaseActionMenu(actions: actions),
        ),
        const Size(640, 360),
        safePadding: _safePadding,
      );
      for (var index = 0; index < actions.length; index++) {
        expect(find.byKey(ValueKey('$menuType-action-$index')), findsOneWidget);
      }
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.pixels, 0);

      for (var index = 0; index < actions.length; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }

      expect(scrollable.position.pixels, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(activated, 20);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Portal menu moves when safePadding changes', (tester) async {
    const size = Size(640, 360);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    var safePadding = EdgeInsets.zero;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            final spec = DuelRoomLayoutSpec.resolve(
              size,
              safePadding: safePadding,
            );
            return MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: safePadding,
                viewPadding: safePadding,
              ),
              child: DuelRoomLayout(
                spec: spec,
                child: Portal(
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: const Rect.fromLTWH(0, 330, 20, 20),
                        child: PortalTarget(
                          visible: true,
                          anchor: SafeAligned(
                            follower: Alignment.bottomCenter,
                            target: Alignment.topCenter,
                            offset: const Offset(0, -8),
                            safePadding: safePadding,
                          ),
                          portalFollower: HandActionPopover(
                            actions: [
                              ActionMenuEntry(label: '操作', onTap: () {}),
                            ],
                          ),
                          child: const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(tester.getRect(find.byType(HandActionPopover)).left, 0);

    update(() => safePadding = const EdgeInsets.only(left: 120));
    await tester.pump();

    final movedRect = tester.getRect(find.byType(HandActionPopover));
    expect(movedRect.left, 120);
    expect(movedRect.right, lessThanOrEqualTo(size.width));
    expect(tester.takeException(), isNull);
  });

  for (final placement in const [
    (name: 'field-left', anchor: Rect.fromLTWH(44, 330, 20, 20), phase: false),
    (name: 'hand-right', anchor: Rect.fromLTWH(599, 330, 20, 20), phase: false),
    (name: 'phase-right', anchor: Rect.fromLTWH(590, 320, 24, 24), phase: true),
  ]) {
    testWidgets('${placement.name} Portal follower stays inside safeRect', (
      tester,
    ) async {
      const size = Size(640, 360);
      final spec = DuelRoomLayoutSpec.resolve(size, safePadding: _safePadding);
      final entries = [ActionMenuEntry(label: '操作', onTap: () {})];
      await pumpResponsiveWidget(
        tester,
        Portal(
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: placement.anchor,
                child: PortalTarget(
                  visible: true,
                  anchor: SafeAligned(
                    follower: placement.phase
                        ? Alignment.centerRight
                        : Alignment.bottomCenter,
                    target: placement.phase
                        ? Alignment.centerLeft
                        : Alignment.topCenter,
                    offset: placement.phase
                        ? const Offset(-8, 0)
                        : const Offset(0, -8),
                    safePadding: _safePadding,
                  ),
                  portalFollower: placement.phase
                      ? PhaseActionMenu(actions: entries)
                      : HandActionPopover(
                          actions: entries,
                          arrowDx: popoverArrowDx(
                            anchorRect: placement.anchor,
                            safeRect: spec.safeRect,
                            menuWidth: menuWidthFor(spec),
                          ),
                        ),
                  child: const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        size,
        safePadding: _safePadding,
      );

      final follower = placement.phase
          ? find.byKey(const ValueKey('phase-action-menu'))
          : find.byType(HandActionPopover);
      final rect = tester.getRect(follower);
      expect(rect.left, greaterThanOrEqualTo(spec.safeRect.left));
      expect(rect.top, greaterThanOrEqualTo(spec.safeRect.top));
      expect(rect.right, lessThanOrEqualTo(spec.safeRect.right));
      expect(rect.bottom, lessThanOrEqualTo(spec.safeRect.bottom));
      expect(tester.takeException(), isNull);
    });
  }

  for (final menuWidth in const [1.0, 20.0, 33.0]) {
    testWidgets('HandActionPopover supports $menuWidth px menu width', (
      tester,
    ) async {
      final viewport = Size(menuWidth + 16, 200);
      await pumpResponsiveWidget(
        tester,
        HandActionPopover(
          actions: [ActionMenuEntry(label: 'A', onTap: () {})],
          arrowDx: menuWidth,
        ),
        viewport,
      );

      expect(
        tester.getSize(find.byKey(const ValueKey('hand-action-menu'))).width,
        menuWidth,
      );
      final arrow = find
          .descendant(
            of: find.byType(HandActionPopover),
            matching: find.byType(CustomPaint),
          )
          .last;
      expect(tester.getSize(arrow).width, menuWidth.clamp(0, 26));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('空 actions 的整个 popover 不渲染箭头', (tester) async {
    await pumpResponsiveWidget(
      tester,
      const Center(child: HandActionPopover(actions: [])),
      const Size(640, 360),
    );
    expect(
      find.descendant(
        of: find.byType(HandActionPopover),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  test('fieldCardAnchor clamp sequence 并限制到非对称 safeRect', () {
    const safeRect = Rect.fromLTWH(44, 8, 575, 336);
    for (final sequence in [-1000, 1000]) {
      final anchor = fieldCardAnchor(
        const Size(640, 360),
        FieldCard(code: 1, controller: 0, zone: 4, sequence: sequence),
        0,
        safeRect: safeRect,
      );
      expect(anchor.dx, inInclusiveRange(safeRect.left, safeRect.right));
      expect(anchor.dy, inInclusiveRange(safeRect.top, safeRect.bottom));
    }
  });

  test('fieldCardAnchor 对异常 viewport 返回有限安全结果', () {
    const safeRect = Rect.fromLTWH(4, 3, 1, 1);
    final anchor = fieldCardAnchor(
      const Size(double.nan, double.infinity),
      const FieldCard(code: 1, controller: 1, zone: 8, sequence: 999),
      0,
      safeRect: safeRect,
    );
    expect(anchor.dx, inInclusiveRange(safeRect.left, safeRect.right));
    expect(anchor.dy, inInclusiveRange(safeRect.top, safeRect.bottom));
    expect(anchor.dx.isFinite, isTrue);
    expect(anchor.dy.isFinite, isTrue);
  });
}
