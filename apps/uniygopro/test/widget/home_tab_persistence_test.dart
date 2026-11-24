/// 大厅「上次停留分区」冷启恢复（spec §178 `app_last_tab`）。
///
/// 覆盖 `home_page.dart` 的 `_restoreLastTab` / `_persistLastTab`：
/// 1. 存量 `app_last_tab` 合法 → 冷启直接落在该分区；
/// 2. **脏数据必须回落「决斗」且不抛异常**——`9`（越界）、`'oops'`（类型错）
///    两种都要覆盖。实现者第一版用 `prefs.getInt()`，类型不符直接抛
///    `_TypeError`，而这是 fire-and-forget 异步路径，异常会变成未捕获
///    异步异常；改成 `get()` + `is int` 才修好，因此这里必须锁住。
/// 3. 切分区 → 落盘 → 整棵树重建 → 恢复到该分区。
library;

import 'dart:async';

import 'package:account_mycard/account_mycard.dart';
import 'package:biz/service_loader.registrations.g.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:deck_editor3/deck_editor3.dart' show DeckHubPage;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniygopro/layout/app_layout.dart';
import 'package:uniygopro/pages/create_room/match_store.dart';
import 'package:uniygopro/pages/home_page.dart' show HomePage, kAppLastTabKey;

const _aiRoomKey = ValueKey('home-server-ai-room');
const _specKeyName = 'app_last_tab';

/// 「决斗」分区的判定锚点：AI 入口 key（spec 必须保留项）。
Finder get duelTab => find.byKey(_aiRoomKey);

void main() {
  setUpAll(() {
    // HomePage 切分区会经 ServiceSingleton 播按键音，而 ServiceSingleton 是
    // 饿汉单例（构造期即 create 各服务），未注册会抛 UnimplementedError。
    // 注册回调里的卡片库预下载在 widget 测试环境缺插件实现，用独立 Zone 吞掉。
    runZonedGuarded(registerAllServices, (error, stack) {});
    YgoSoundService.enabled = false;
  });

  tearDownAll(() {
    YgoSoundService.enabled = true;
  });

  /// 挂载真实大厅壳（AppLayoutScope 由真实视口派生，与 app.dart 注入点一致）。
  Future<void> pumpHome(WidgetTester tester, {Size? size}) async {
    final viewport = size ?? const Size(1280, 720);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final account = MyCardAccountApi();
    addTearDown(account.dispose);

    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const HomePage())],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MyCardAccountApi>.value(value: account),
          ChangeNotifierProvider<MatchStore>(create: (_) => MatchStore()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => AppLayoutScope(child: child!),
        ),
      ),
    );
    await tester.pump();
    // 恢复读盘是异步的：给一拍让 getInstance()/setState 落地。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('冷启恢复合法值', () {
    testWidgets('app_last_tab=1 → 直接落在「卡组」分区', (tester) async {
      SharedPreferences.setMockInitialValues({_specKeyName: 1});
      await pumpHome(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(DeckHubPage), findsOneWidget);
      expect(duelTab, findsNothing);

      // 卡组分区三段式入口（S1 契约）应已渲染。
      expect(find.text('卡组市场'), findsOneWidget);
      expect(find.text('我的卡组'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('app_last_tab=3 → 落在「我的」分区', (tester) async {
      SharedPreferences.setMockInitialValues({_specKeyName: 3});
      await pumpHome(tester);

      expect(tester.takeException(), isNull);
      // 「全局设置」是「我的」分区常驻项（与登录态无关）。
      expect(find.text('全局设置'), findsOneWidget);
      expect(duelTab, findsNothing);
    });

    testWidgets('键名必须与 spec §178 一致（防止悄悄改名）', (tester) async {
      expect(kAppLastTabKey, _specKeyName);
    });
  });

  group('冷启恢复脏数据 → 一律回落「决斗」且不抛异常', () {
    testWidgets('越界值 9（分区数量减少 / 人为篡改）', (tester) async {
      SharedPreferences.setMockInitialValues({_specKeyName: 9});
      await pumpHome(tester);

      expect(tester.takeException(), isNull);
      expect(duelTab, findsOneWidget);
      expect(find.byType(DeckHubPage), findsNothing);
    });

    testWidgets('负值 -1', (tester) async {
      SharedPreferences.setMockInitialValues({_specKeyName: -1});
      await pumpHome(tester);

      expect(tester.takeException(), isNull);
      expect(duelTab, findsOneWidget);
    });

    testWidgets('类型错 "oops"（getInt 会抛 _TypeError 的那个点）', (tester) async {
      SharedPreferences.setMockInitialValues({_specKeyName: 'oops'});
      await pumpHome(tester);

      // 关键：异步路径不能出现未捕获异常。
      expect(tester.takeException(), isNull);
      expect(duelTab, findsOneWidget);
      expect(find.byType(DeckHubPage), findsNothing);
    });

    testWidgets('类型错 true（bool）', (tester) async {
      SharedPreferences.setMockInitialValues({_specKeyName: true});
      await pumpHome(tester);

      expect(tester.takeException(), isNull);
      expect(duelTab, findsOneWidget);
    });
  });

  group('切分区 → 落盘 → 整棵树重建 → 恢复', () {
    testWidgets('切到「卡组」后重建 HomePage，回到「卡组」', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpHome(tester);
      expect(duelTab, findsOneWidget, reason: '空 prefs 应停在「决斗」');

      await tester.tap(find.text('卡组'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 写入是异步的（`_persistLastTab` 里 await getInstance + await setInt）。
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.get(kAppLastTabKey),
        1,
        reason: '切分区应立即落盘（不能等 dispose，杀进程不走 dispose）',
      );

      // 模拟冷启：把整棵树换掉再挂一个新的 HomePage，状态全新。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpHome(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(DeckHubPage), findsOneWidget, reason: '重建后应恢复「卡组」');
      expect(duelTab, findsNothing);
    });

    testWidgets('compact 640×360 下同样恢复（底部 Tab 形态）', (tester) async {
      SharedPreferences.setMockInitialValues({_specKeyName: 2});
      await pumpHome(tester, size: const Size(640, 360));

      expect(tester.takeException(), isNull);
      // 「观战」分区专属提示语（底部 Tab 上也有「观战」二字，故断言正文）。
      expect(
        find.text('观战需要登录 MyCard 账号；房间列表随对局实时刷新。'),
        findsOneWidget,
      );
      expect(duelTab, findsNothing);
    });
  });
}
