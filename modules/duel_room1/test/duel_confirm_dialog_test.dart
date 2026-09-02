import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/field_overlay_state.dart';
import 'package:duel_room1/field/duel_field_page.dart';
import 'package:duel_room1/field/widgets/confirm/confirm_floating_card.dart';
import 'package:duel_room1/field/widgets/confirm/duel_confirm_dialog.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/card_info.dart' as pkg;

void main() {
  const safeRect = Rect.fromLTWH(44, 10, 575, 344);

  group('clampFloatingCardRect', () {
    test('夹紧负坐标与左上边缘', () {
      expect(
        clampFloatingCardRect(
          const Rect.fromLTWH(-200, -100, 150, 230),
          safeRect,
        ),
        const Rect.fromLTWH(44, 10, 150, 230),
      );
    });

    test('夹紧右下边缘', () {
      expect(
        clampFloatingCardRect(
          const Rect.fromLTWH(600, 300, 150, 230),
          safeRect,
        ),
        const Rect.fromLTWH(469, 124, 150, 230),
      );
    });

    test('分别夹紧右上与左下边缘', () {
      expect(
        clampFloatingCardRect(
          const Rect.fromLTWH(700, -100, 150, 230),
          safeRect,
        ),
        const Rect.fromLTWH(469, 10, 150, 230),
      );
      expect(
        clampFloatingCardRect(
          const Rect.fromLTWH(-200, 400, 150, 230),
          safeRect,
        ),
        const Rect.fromLTWH(44, 124, 150, 230),
      );
    });

    test('过大浮卡缩到安全区', () {
      expect(
        clampFloatingCardRect(const Rect.fromLTWH(0, 0, 900, 500), safeRect),
        safeRect,
      );
    });
  });

  test('compact 主面板纯策略为 inspector > confirm > zone', () {
    expect(
      selectDuelPrimaryPanel(
        isCompact: true,
        hasInspector: true,
        hasConfirmPanel: true,
        hasZoneBrowser: true,
      ),
      DuelPrimaryPanel.inspector,
    );
    expect(
      selectDuelPrimaryPanel(
        isCompact: true,
        hasInspector: false,
        hasConfirmPanel: true,
        hasZoneBrowser: true,
      ),
      DuelPrimaryPanel.confirm,
    );
    expect(
      selectDuelPrimaryPanel(
        isCompact: true,
        hasInspector: false,
        hasConfirmPanel: false,
        hasZoneBrowser: true,
      ),
      DuelPrimaryPanel.zone,
    );
  });

  testWidgets('enum host 只构建选中面板且确认层单次构建并保留浮卡', (tester) async {
    var confirmBuildCount = 0;
    Widget buildSubject(DuelPrimaryPanel selectedPanel) => MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            DuelPrimaryPanelHost(
              selectedPanel: selectedPanel,
              zoneBuilder: (_) =>
                  const SizedBox(key: ValueKey('zone-panel-test')),
              confirmBuilder: (_, showPanel) {
                confirmBuildCount++;
                return Stack(
                  children: [
                    if (showPanel)
                      const SizedBox(key: ValueKey('confirm-panel-test')),
                    const SizedBox(key: ValueKey('floating-test')),
                  ],
                );
              },
              inspectorBuilder: (_) =>
                  const SizedBox(key: ValueKey('inspector-panel-test')),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(buildSubject(DuelPrimaryPanel.inspector));
    expect(find.byKey(const ValueKey('inspector-panel-test')), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-panel-test')), findsNothing);
    expect(find.byKey(const ValueKey('zone-panel-test')), findsNothing);
    expect(find.byKey(const ValueKey('floating-test')), findsOneWidget);
    expect(confirmBuildCount, 1);

    confirmBuildCount = 0;
    await tester.pumpWidget(buildSubject(DuelPrimaryPanel.confirm));
    expect(find.byKey(const ValueKey('confirm-panel-test')), findsOneWidget);
    expect(find.byKey(const ValueKey('zone-panel-test')), findsNothing);
    expect(find.byKey(const ValueKey('inspector-panel-test')), findsNothing);
    expect(confirmBuildCount, 1);

    await tester.pumpWidget(buildSubject(DuelPrimaryPanel.zone));
    expect(find.byKey(const ValueKey('confirm-panel-test')), findsNothing);
    expect(find.byKey(const ValueKey('zone-panel-test')), findsOneWidget);
    expect(find.byKey(const ValueKey('floating-test')), findsOneWidget);
  });

  test('真实 provider 保留 zone 与 confirm，关闭详情后可恢复', () {
    final container = ProviderContainer(
      overrides: [
        fieldOverlayProvider.overrideWith(FieldOverlayNotifier.new),
        cardConfirmProvider.overrideWith(CardConfirmNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    final overlay = container.read(fieldOverlayProvider.notifier);
    final confirm = container.read(cardConfirmProvider.notifier);

    overlay.openZoneBrowser('self_grave');
    confirm.showConfirmPanel(title: '确认卡', codes: const [1001]);
    overlay.applyInspect(1001, null, preserveZoneBrowser: true);

    expect(container.read(fieldOverlayProvider).showInspector, isTrue);
    expect(
      container.read(fieldOverlayProvider).openZoneBrowserKey,
      'self_grave',
    );
    expect(container.read(cardConfirmProvider).confirmPanel, isNotNull);
    overlay.dismissInspector();
    expect(
      selectDuelPrimaryPanel(
        isCompact: true,
        hasInspector: container.read(fieldOverlayProvider).showInspector,
        hasConfirmPanel:
            container.read(cardConfirmProvider).confirmPanel != null,
        hasZoneBrowser:
            container.read(fieldOverlayProvider).openZoneBrowserKey != null,
      ),
      DuelPrimaryPanel.confirm,
    );
    confirm.dismissConfirmPanel();
    expect(
      container.read(fieldOverlayProvider).openZoneBrowserKey,
      'self_grave',
    );
  });

  for (final anchor in const [
    Rect.fromLTWH(-20, -20, 40, 40),
    Rect.fromLTWH(824, -20, 40, 40),
    Rect.fromLTWH(-20, 370, 40, 40),
    Rect.fromLTWH(824, 370, 40, 40),
  ]) {
    testWidgets('实际 DuelConfirmDialog 将 $anchor 浮卡夹进 safeRect', (tester) async {
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardConfirmProvider.overrideWith(_FloatConfirmNotifier.new),
            duelFieldProvider.overrideWith(_TestDuelFieldNotifier.new),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: size,
                viewPadding: safePadding,
                padding: safePadding,
              ),
              child: DuelRoomLayout(
                spec: spec,
                child: Scaffold(
                  body: Stack(
                    children: [DuelConfirmDialog(slotRectOf: (_) => anchor)],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(ConfirmFloatingCard), findsOneWidget);
      final rect = tester.getRect(
        find.byKey(const ValueKey('confirm-floating-card')),
      );
      expect(rect.left, greaterThanOrEqualTo(spec.safeRect.left));
      expect(rect.top, greaterThanOrEqualTo(spec.safeRect.top));
      expect(rect.right, lessThanOrEqualTo(spec.safeRect.right));
      expect(rect.bottom, lessThanOrEqualTo(spec.safeRect.bottom));
    });
  }
}

class _FloatConfirmNotifier extends CardConfirmNotifier {
  @override
  CardConfirmState build() =>
      const CardConfirmState(floatPreviewCodes: [1001], floatPreviewOwner: 0);
}

class _TestDuelFieldNotifier extends DuelFieldNotifier {
  @override
  DuelFieldState build() => const DuelFieldState(myController: 0);

  @override
  pkg.CardInfo? getCardInfo(int code) => null;
}
