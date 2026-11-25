/// 启动流程：开屏 → 登录（游客）→ 主页 → 对战模式 → 建房面板。
///
/// 覆盖开屏/登录/主页三屏切换，以及新版「建房」页（自由房间 / 练习）
/// 到既有 create_room 面板的接入，最后进入卡组中心。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uniygopro/main.dart' as app;
import 'package:biz/ygo_sound_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('开屏 → 游客主页 → 对战模式 → 建房面板 → 卡组中心', (tester) async {
    YgoSoundService.enabled = false;
    app.main();
    await tester.pumpAndSettle();
    _failIfFlutterException(tester, 'after app startup');

    // 开屏会自动跳转：未登录 → 登录页，已登录 → 主页。
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    final guestButton = find.byKey(const ValueKey('login-guest'));
    if (guestButton.evaluate().isNotEmpty) {
      expect(find.text('账号登录'), findsOneWidget);
      await tester.tap(guestButton);
      await tester.pumpAndSettle();
      _failIfFlutterException(tester, 'after guest login');
    }

    // 主页基础信息（新版底栏）
    expect(find.text('公告'), findsOneWidget);
    expect(find.text('比赛观看 ▾'), findsOneWidget);
    expect(find.text('竞技匹配 ▾'), findsOneWidget);

    // ── 建房：自由房间 → 进入房间面板 ──
    // 匹配盘有常驻旋转动画：这一页内不要 pumpAndSettle。
    await tester.tap(find.byKey(const ValueKey('home-match-bar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('对战'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('create-room-tab-3')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Koishi 通用环境'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-room-center')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('加入房间'), findsOneWidget);
    expect(find.text('对战环境'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 500));

    // ── 练习 → 人机对决面板 ──
    await tester.tap(find.byKey(const ValueKey('create-room-tab-2')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('人机对决'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('create-room-center')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('开始人机对战'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 500));

    // ── 返回主页 → 卡组页签 ──
    await tester.tap(find.text('← 返回大厅'));
    await tester.pumpAndSettle();
    expect(find.text('比赛观看 ▾'), findsOneWidget);

    await tester.tap(find.text('卡组'));
    await tester.pumpAndSettle();
    expect(find.text('卡组中心'), findsOneWidget);
    _failIfFlutterException(tester, 'after opening deck hub');
  });
}

void _failIfFlutterException(WidgetTester tester, String stage) {
  final exception = tester.takeException();
  if (exception != null) {
    fail('Unexpected Flutter exception $stage: $exception');
  }
}
