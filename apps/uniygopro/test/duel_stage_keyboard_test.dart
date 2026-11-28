import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/ui/duel_canvas.dart';

void main() {
  const design = Size(1280, 800);
  const pageKey = ValueKey('page-body');

  Widget subject({double keyboard = 0, bool avoidKeyboard = true}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQueryData(
            size: design,
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: DuelStage(
            backdrop: DuelBackdropKind.login,
            avoidKeyboard: avoidKeyboard,
            child: const SizedBox.expand(
              key: pageKey,
              child: ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('无键盘：页面画布铺满整个窗口', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject());
    final rect = tester.getRect(find.byKey(pageKey));
    expect(rect.top, 0);
    expect(rect.bottom, closeTo(design.height, 0.01));
  });

  testWidgets('键盘弹起：页面画布收进键盘上方，不被键盘盖住', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject(keyboard: 400));
    final rect = tester.getRect(find.byKey(pageKey));
    // 等比缩小后整块画布止于键盘顶部。
    expect(rect.bottom, lessThanOrEqualTo(design.height - 400));
    expect(rect.top, 0);
    expect(rect.width, lessThan(design.width));
    expect(tester.takeException(), isNull);
  });

  testWidgets('未开启避让：键盘弹起时画布保持不变', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject(keyboard: 400, avoidKeyboard: false));
    final rect = tester.getRect(find.byKey(pageKey));
    expect(rect.bottom, closeTo(design.height, 0.01));
    expect(tester.takeException(), isNull);
  });
}
