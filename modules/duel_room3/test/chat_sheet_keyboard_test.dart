import 'package:duel_room3/waiting/widgets/chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const design = Size(1280, 800);
  final panel = find.byKey(const ValueKey('chat-sheet-panel'));

  Widget subject({double keyboard = 0}) {
    return ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQueryData(
              size: design,
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            // 弹层在真实调用里由 ModalBottomSheet 贴底摆放，这里用 same 的
            // 底部对齐复现该约束。
            child: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ChatSheet(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('无键盘：聊天抽屉 360 高并贴底', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject());
    // panel 含 12 的外边距：内容 360 + 上下边距 24。
    final rect = tester.getRect(panel);
    expect(rect.height, 360 + 24);
    expect(rect.bottom, design.height);
  });

  testWidgets('键盘弹起：抽屉整体让出键盘高度，输入框不被遮挡', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject(keyboard: 400));
    final rect = tester.getRect(panel);
    // 抽屉底部正好落在键盘顶部。
    expect(rect.bottom, design.height - 400);
    // 输入框整体位于键盘上方。
    final field = tester.getRect(find.byType(TextField));
    expect(field.bottom, lessThanOrEqualTo(design.height - 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('键盘过高：抽屉收缩到键盘上方剩余空间', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(subject(keyboard: 560));
    final rect = tester.getRect(panel);
    // 剩余空间不够放 360 时整条抽屉收窄，且不会顶出画布。
    expect(rect.height, lessThanOrEqualTo(design.height - 560));
    expect(rect.top, greaterThanOrEqualTo(0));
    final field = tester.getRect(find.byType(TextField));
    expect(field.bottom, lessThanOrEqualTo(design.height - 560));
    expect(tester.takeException(), isNull);
  });
}
