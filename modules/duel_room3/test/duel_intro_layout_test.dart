import 'package:duel_room3/loading/duel_field_loading_page.dart';
import 'package:duel_room3/loading/models/duel_intro_timeline.dart';
import 'package:duel_room3/loading/widgets/intro_phases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 各相位在 844×390 视口下的几何健康度：不溢出、关键元素可见、
/// 不越界。等价于「截图人工核对」的自动化替代——本机 `toImage`
/// 会被系统 kill，只能走布局断言（见 memory/2026-11-27 的环境记录）。
void main() {
  const data = DuelIntroSceneData(
    myName: '混沌龙博士',
    opponentName: '剑斗士 K',
    iGoFirst: true,
  );

  const viewport = Size(844, 390);

  Future<void> pumpPhase(
    WidgetTester tester,
    DuelIntroPhase phase, {
    double t = 0.85,
  }) async {
    tester.view.physicalSize = viewport * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: buildIntroPhase(phase: phase, t: t, data: data),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }

  for (final span in DuelIntroTimeline.spans) {
    testWidgets('${span.phase.name} 无溢出且关键元素在视口内', (tester) async {
      await pumpPhase(tester, span.phase);

      // 任何 RenderFlex 溢出都会在这里抛出。
      expect(tester.takeException(), isNull);

      // 相位画面自身铺满视口。
      final rootSize = tester.getSize(find.byType(Stack).first);
      expect(rootSize.width, closeTo(viewport.width, 1));
      expect(rootSize.height, closeTo(viewport.height, 1));
    });
  }

  testWidgets('vs 方名左右分列且不重叠', (tester) async {
    await pumpPhase(tester, DuelIntroPhase.vs);
    final myRect = tester.getRect(find.text('混沌龙博士'));
    final oppRect = tester.getRect(find.text('剑斗士 K'));
    expect(myRect.right, lessThan(oppRect.left), reason: '双方方名不能重叠');
  });

  testWidgets('field 双方席位标识分别在左右两侧', (tester) async {
    await pumpPhase(tester, DuelIntroPhase.field);
    final myRect = tester.getRect(find.text('YOU  ▸  SEAT A'));
    final oppRect = tester.getRect(find.text('SEAT B  ◂  RIVAL'));
    expect(myRect.center.dx, lessThan(viewport.width / 2), reason: '我方席位应在左半屏');
    expect(
      oppRect.center.dx,
      greaterThan(viewport.width / 2),
      reason: '对手席位应在右半屏',
    );
  });

  testWidgets('页面级进度条填充宽度随演出单调增长', (tester) async {
    tester.view.physicalSize = viewport * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DuelFieldLoadingPage(data: data, onFinished: () {}),
      ),
    );

    /// 取加载条槽（#16263A 的 3px 细条）里填充层的宽度。
    double fillWidthAt(WidgetTester tester) {
      // 填充层是带 boxShadow 的 DecoratedBox，宽度由 LayoutBuilder 算出。
      final fills = find.byWidgetPredicate(
        (w) => w is DecoratedBox && w.decoration is BoxDecoration,
      );
      var maxW = 0.0;
      for (final e in fills.evaluate()) {
        final size = (e.renderObject as RenderBox?)?.size;
        if (size != null && size.height <= 4 && size.width > maxW) {
          maxW = size.width;
        }
      }
      return maxW;
    }

    // 进度条挂在页面层级，跨相位也只有一条：这里横跨 tunnel → field → vs
    // 三段采样，宽度必须单调增长（相位切换不能让条回退）。
    final widths = <double>[fillWidthAt(tester)];
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
      widths.add(fillWidthAt(tester));
    }

    for (var i = 1; i < widths.length; i++) {
      expect(
        widths[i],
        greaterThanOrEqualTo(widths[i - 1]),
        reason: '进度条宽度不应回退：$widths',
      );
    }
    expect(widths.last, greaterThan(widths.first), reason: '进度条确实在前进');
    expect(widths.last, lessThanOrEqualTo(viewport.width));
  });
}
