import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/field_overlay_state.dart';
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
    expect(container.read(fieldOverlayProvider).showInspector, isFalse);
    confirm.dismissConfirmPanel();
    expect(
      container.read(fieldOverlayProvider).openZoneBrowserKey,
      'self_grave',
    );
  });

  for (final anchor in const [
    Rect.fromLTWH(-20, -20, 40, 40),
    Rect.fromLTWH(1260, -20, 40, 40),
    Rect.fromLTWH(-20, 780, 40, 40),
    Rect.fromLTWH(1260, 780, 40, 40),
  ]) {
    testWidgets('实际 DuelConfirmDialog 将 $anchor 浮卡夹进 safeRect', (tester) async {
      const size = Size(1280, 800);
      const spec = DuelRoomLayoutSpec.fixed;
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
                viewPadding: EdgeInsets.zero,
                padding: EdgeInsets.zero,
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
