import 'package:duel_room1/field/widgets/docked_panel_shell.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' show Tristate;

void main() {
  Widget buildSubject() {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            DockedPanelShell(
              title: '测试面板',
              count: 3,
              onClose: () {},
              child: const Placeholder(),
            ),
          ],
        ),
      ),
    );
  }

  group('DockedPanelShell 响应式停靠几何', () {
    testWidgets('关闭按钮提供单一明确的 button 语义', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('关闭'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('关闭'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);
      semantics.dispose();
    });

    testWidgets('大 right 安全区只扣一次并保留两侧 panelGap', (tester) async {
      const size = Size(640, 360);
      const safePadding = EdgeInsets.fromLTRB(20, 0, 180, 0);
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
        MediaQuery(
          data: const MediaQueryData(
            size: size,
            viewPadding: safePadding,
            padding: safePadding,
          ),
          child: DuelRoomLayout(spec: spec, child: buildSubject()),
        ),
      );
      await tester.pumpAndSettle();

      final positioned = tester.widget<Positioned>(
        find
            .ancestor(of: find.text('测试面板'), matching: find.byType(Positioned))
            .first,
      );
      expect(positioned.right, safePadding.right + spec.panelGap);
      expect(
        positioned.width,
        spec.dockedPanelWidth.clamp(
          0.0,
          spec.safeRect.width - spec.panelGap * 2,
        ),
      );
    });

    testWidgets('桌面视口下保持设计值（上136/下126/右18/宽440）', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final pos = tester.widget<Positioned>(
        find
            .ancestor(of: find.text('测试面板'), matching: find.byType(Positioned))
            .first,
      );
      expect(pos.top, 136);
      expect(pos.bottom, 126);
      expect(pos.right, 18);
      expect(pos.width, 440);
    });

    testWidgets('手机横屏视口下按 HUD 缩放收缩上下留白', (tester) async {
      tester.view.physicalSize = const Size(800, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final pos = tester.widget<Positioned>(
        find
            .ancestor(of: find.text('测试面板'), matching: find.byType(Positioned))
            .first,
      );
      // 390 高 → hudScale 0.60。
      expect(pos.top, closeTo(81.6, 0.001));
      expect(pos.bottom, closeTo(75.6, 0.001));
      expect(pos.right, 8);
      expect(pos.width, 360);
    });

    testWidgets('极端矮视口仍返回非负几何', (tester) async {
      const height = 240.0;
      tester.view.physicalSize = const Size(480, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final pos = tester.widget<Positioned>(
        find
            .ancestor(of: find.text('测试面板'), matching: find.byType(Positioned))
            .first,
      );
      final contentHeight = height - (pos.top ?? 0) - (pos.bottom ?? 0);
      expect(contentHeight, greaterThanOrEqualTo(0));
    });

    testWidgets('窄视口下面板宽度夹紧到可用宽度', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final pos = tester.widget<Positioned>(
        find
            .ancestor(of: find.text('测试面板'), matching: find.byType(Positioned))
            .first,
      );
      expect(pos.width, 344);
      expect(pos.right, 8);
    });

    testWidgets('超窄视口下面板宽度不低于 0', (tester) async {
      tester.view.physicalSize = const Size(24, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final pos = tester.widget<Positioned>(
        find
            .ancestor(of: find.text('测试面板'), matching: find.byType(Positioned))
            .first,
      );
      expect(pos.width, 8.0);
    });

    for (final size in const [
      Size(640, 360),
      Size(800, 450),
      Size(1280, 720),
      Size(1920, 1080),
    ]) {
      testWidgets('$size 面板实际 Rect 位于 safeRect 内', (tester) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(() {
          tester.view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio();
        });
        final spec = DuelRoomLayoutSpec.resolve(size);
        await tester.pumpWidget(
          DuelRoomLayout(spec: spec, child: buildSubject()),
        );
        await tester.pumpAndSettle();

        final rect = tester.getRect(find.byKey(const ValueKey('docked-panel')));
        expect(rect.left, greaterThanOrEqualTo(spec.safeRect.left));
        expect(rect.top, greaterThanOrEqualTo(spec.safeRect.top));
        expect(rect.right, lessThanOrEqualTo(spec.safeRect.right));
        expect(rect.bottom, lessThanOrEqualTo(spec.safeRect.bottom));
        expect(rect.width, greaterThanOrEqualTo(0));
        expect(rect.height, greaterThanOrEqualTo(0));
      });
    }
  });
}
