import 'package:duel_room1/field/widgets/docked_panel_shell.dart';
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

  group('DockedPanelShell 固定停靠几何', () {
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

    testWidgets('固定设计值（上136/下126/右18/宽440）', (tester) async {
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

    testWidgets('长标题不溢出且关闭命中区为 44', (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 800)
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
                DockedPanelShell(
                  title: '非常长的测试面板标题',
                  count: 999,
                  onClose: () {},
                  titleSuffix: const Text('长状态'),
                  child: const Placeholder(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.bySemanticsLabel('关闭')),
        const Size.square(44),
      );
    });
  });
}
