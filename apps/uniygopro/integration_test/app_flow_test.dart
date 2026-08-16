/// 首页各建房入口的完整导航流程（真实 App 启动）。
///
/// 依次打开竞技匹配 / 娱乐匹配 / 自由房间 / 残局房 / AI 对决 面板，
/// 验证各 sheet 渲染与基础交互，最后进入卡组编辑器入口。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uniygopro/main.dart' as app;
import 'package:biz/ygo_sound_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('首页 → 各建房面板 → 卡组编辑器入口', (tester) async {
    YgoSoundService.enabled = false;
    app.main();
    await tester.pumpAndSettle();
    _failIfFlutterException(tester, 'after app startup');

    // ── 竞技匹配 sheet ──
    await tester.tap(find.text('竞技匹配'));
    await tester.pumpAndSettle();
    expect(find.text('开始匹配'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    // 关闭弹层（点击遮罩）
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── 娱乐匹配 sheet ──
    await tester.tap(find.text('娱乐匹配'));
    await tester.pumpAndSettle();
    expect(find.text('开始匹配'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── 自由房间 sheet（默认 Koishi 只能加入）──
    await tester.tap(find.text('自由房间'));
    await tester.pumpAndSettle();
    expect(find.text('加入房间'), findsOneWidget);
    expect(find.text('对战环境'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── 残局房 sheet ──
    await tester.tap(find.text('残局房'));
    await tester.pumpAndSettle();
    expect(find.text('搜索残局…'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── AI 对决 sheet → 切到 233 → 校验房间串预览 ──
    await tester.tap(find.byKey(const ValueKey('home-server-ai-room')));
    await tester.pumpAndSettle();
    expect(find.text('开始人机对战'), findsOneWidget);
    await tester.tap(find.text('233 服 AI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('房间串:'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── 卡组编辑器入口 ──
    await tester.tap(find.byIcon(Icons.card_membership));
    await tester.pumpAndSettle();
    expect(find.text('卡组编辑器'), findsOneWidget);
    _failIfFlutterException(tester, 'after opening deck editor');
  });
}

void _failIfFlutterException(WidgetTester tester, String stage) {
  final exception = tester.takeException();
  if (exception != null) {
    fail('Unexpected Flutter exception $stage: $exception');
  }
}
