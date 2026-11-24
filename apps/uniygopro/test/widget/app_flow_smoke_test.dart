/// 首启链路 + 建房入口的**同构冒烟**（真实 router / 真实页面 / 真实 provider）。
///
/// 与 `integration_test/app_flow_test.dart` 逐条对齐：那支用例需要真机/模拟器
/// 才能跑（本机 Android 设备拒绝安装、macOS 桌面构建被 Xcode SPM 环境卡住），
/// 这里在 flutter_test harness 里用同一套 finder 走同一条链路，保证断言本身
/// 不过期。平台相关部分（真实网络、真实插件）仍由集成测试覆盖。
library;

import 'dart:async';

import 'package:account_mycard/account_mycard.dart';
import 'package:biz/service_loader.registrations.g.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:deck_editor1/deck_editor1.dart' show DeckEditorStore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniygopro/app.dart';
import 'package:uniygopro/pages/create_room/match_store.dart';

const _aiRoomKey = ValueKey('home-server-ai-room');
const _guestEntryKey = ValueKey('login-guest-entry');

void main() {
  setUpAll(() {
    // 真实 App 启动会 registerAllServices（main.dart），widget harness 里同样
    // 需要；卡片库服务的 fire-and-forget 预下载在无插件环境会异步失败，
    // 用独立 Zone 吞掉（本用例不读卡库）。
    runZonedGuarded(registerAllServices, (error, stack) {});
    YgoSoundService.enabled = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// 与 main.dart 同构的挂载（MultiProvider + UniygoproApp）。
  Future<MyCardAccountApi> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final account = MyCardAccountApi();
    addTearDown(account.dispose);
    final deckStore = DeckEditorStore();
    addTearDown(deckStore.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MyCardAccountApi>.value(value: account),
          ChangeNotifierProvider<MatchStore>(create: (_) => MatchStore()),
          ChangeNotifierProvider<DeckEditorStore>.value(value: deckStore),
        ],
        child: const UniygoproApp(),
      ),
    );
    await tester.pump();
    return account;
  }

  testWidgets('开屏 → 游客进入大厅 → 各建房面板 → 卡组编辑器 → 我的分区', (tester) async {
    await pumpApp(tester);

    // ── 开屏：品牌展示 + 有限次动画，结束后未登录分流到 /login ──
    expect(find.text('uniygo'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // ── 登录页 → 游客进入大厅 ──
    expect(find.byKey(_guestEntryKey), findsOneWidget);
    await tester.tap(find.byKey(_guestEntryKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(_aiRoomKey), findsOneWidget);

    // ── 竞技匹配 sheet ──
    await _tapAfterScroll(tester, find.text('竞技匹配'));
    expect(find.text('开始匹配'), findsOneWidget);
    expect(find.textContaining('用户名'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '竞技匹配面板在 640×360 溢出');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── 娱乐匹配 sheet ──
    await _tapAfterScroll(tester, find.text('娱乐匹配'));
    expect(find.text('开始匹配'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '娱乐匹配面板在 640×360 溢出');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── 自由房间 sheet ──
    await _tapAfterScroll(tester, find.text('自由房间'));
    expect(find.text('加入房间'), findsOneWidget);
    expect(find.text('对战环境'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '自由房间面板在 640×360 溢出');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── 残局房 sheet（640×360 下在首屏折叠线以下，必须先滚到可见）──
    await _tapAfterScroll(tester, find.text('残局房'));
    expect(find.text('搜索残局…'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '残局房面板在 640×360 溢出');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── AI 对决 sheet → 233 服 → AI 密码预览 ──
    await _tapAfterScroll(tester, find.byKey(_aiRoomKey));
    expect(find.text('开始人机对战'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'AI 对决面板（本地）在 640×360 溢出');
    await tester.tap(find.text('233 服 AI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI 密码:'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'AI 对决面板（233 服）在 640×360 溢出');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // ── 卡组编辑器入口（决斗分区的玩家信息条）──
    // 玩家信息条在 ListView 顶部：前面 ensureVisible 把列表滚下去后它已被
    // 回收（懒列表），需要先滚回顶部才能找到并点击。
    await _tapNavIcon(tester);
    expect(find.text('卡组编辑器'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // ── 返回大厅 → 我的分区探活 ──
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('全局设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已登录时开屏直接进大厅（不经过登录页）', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 一个可用的持久化登录态：isLoggedIn 由 store 依据 token 判定。
    final account = MyCardAccountApi(
      persistedJson:
          '{"username":"tester","displayName":"Tester",'
          '"avatarUrl":"","token":"token-123"}',
    );
    addTearDown(account.dispose);
    final deckStore = DeckEditorStore();
    addTearDown(deckStore.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MyCardAccountApi>.value(value: account),
          ChangeNotifierProvider<MatchStore>(create: (_) => MatchStore()),
          ChangeNotifierProvider<DeckEditorStore>.value(value: deckStore),
        ],
        child: const UniygoproApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(_guestEntryKey), findsNothing);
    expect(find.byKey(_aiRoomKey), findsOneWidget);
  });
}

/// 先滚到可见再点：640×360 下「对战模式」网格的第 5/6 张卡（残局房 / 怪兽动画）
/// 落在首屏折叠线以下，直接 tap 会命中不到（真机上同样点不动）。
Future<void> _tapAfterScroll(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 滚回列表顶部再点玩家信息条里的卡组编辑器入口。
Future<void> _tapNavIcon(WidgetTester tester) async {
  final icon = find.byIcon(Icons.card_membership);
  await tester.dragUntilVisible(
    icon,
    find.byType(ListView).first,
    const Offset(0, 200),
  );
  await tester.pumpAndSettle();
  expect(icon, findsOneWidget);
  await tester.tap(icon);
  await tester.pumpAndSettle();
}
