import 'package:duel_room3/theme/cyber_intro_tokens.dart';
import 'package:duel_room3/widgets/cyber_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 公共细条进度条：载入页与等候页共用同一套槽色 / 填充 / 辉光。
void main() {
  Future<void> pumpBar(
    WidgetTester tester,
    Widget bar, {
    double width = 320,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: bar),
          ),
        ),
      ),
    );
  }

  /// 填充层宽度（带 boxShadow 的 DecoratedBox，高度即条高）。
  double fillWidth(WidgetTester tester) {
    final fills = find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is BoxDecoration,
    );
    var w = 0.0;
    for (final e in fills.evaluate()) {
      final size = (e.renderObject as RenderBox?)?.size;
      if (size != null && size.height <= 4 && size.width > w) w = size.width;
    }
    return w;
  }

  testWidgets('填充宽度等于「容器宽 × 进度」', (tester) async {
    await pumpBar(tester, const CyberProgressBar(progress: 0.5));
    expect(fillWidth(tester), closeTo(160, 1));
  });

  testWidgets('进度越界被钳位到 0 / 1', (tester) async {
    await pumpBar(tester, const CyberProgressBar(progress: -0.7));
    expect(fillWidth(tester), 0);

    await pumpBar(tester, const CyberProgressBar(progress: 3.2));
    expect(fillWidth(tester), closeTo(320, 1));
  });

  testWidgets('默认槽色 / 填充色取载入页 token', (tester) async {
    await pumpBar(tester, const CyberProgressBar(progress: 0.3));

    // 槽：Positioned.fill 的 ColoredBox。
    final slot = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(CyberProgressBar),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(slot.color, CyberIntroTokens.slot);

    // 填充：DecoratedBox 的 color。
    final fill = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.boxShadow != null);
    expect(fill.color, CyberIntroTokens.cyan);
  });

  testWidgets('radius > 0 时外包 ClipRRect', (tester) async {
    await pumpBar(tester, const CyberProgressBar(progress: 0.5, radius: 2));
    expect(find.byType(ClipRRect), findsOneWidget);

    await pumpBar(tester, const CyberProgressBar(progress: 0.5));
    expect(find.byType(ClipRRect), findsNothing);
  });

  testWidgets('glow=false 时不画辉光', (tester) async {
    await pumpBar(tester, const CyberProgressBar(progress: 0.5, glow: false));
    final hasGlow = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .any((d) => d.boxShadow != null);
    expect(hasGlow, isFalse);
  });

  testWidgets('条高可配（默认 3）', (tester) async {
    await pumpBar(tester, const CyberProgressBar(progress: 0.5));
    expect(tester.getSize(find.byType(SizedBox).first).height, 3);
  });
}
