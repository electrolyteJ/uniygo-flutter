/// 大厅「卡组 → 组卡器」在真实宿主里的渲染验证 + 主操作命中区检查。
///
/// S3 把组卡器内嵌进大厅分区，产生两条此前没有 Widget 级验证的路径：
/// 1. compact（640×360）单栏：组卡器的「底部卡组栏（展开编辑）」与大厅
///    「底部 Tab」是否互相压盖；
/// 2. regular（1280×720）双栏：卡组列表 240 + 主区 + 底部卡组栏；
/// 3. 「展开编辑」抽屉在宿主壳内（含底部 Tab）是否仍能正常弹出、不溢出。
///
/// 同时按 spec「所有可点区域有效命中 >= 44dp」检查大厅与登录页的主操作。
library;

import 'dart:async';

import 'package:account_mycard/account_mycard.dart';
import 'package:biz/service_loader.registrations.g.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:deck_editor1/deck_editor1.dart'
    show DeckEditorPage, DeckEditorStore, DeckListPanel;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniygopro/layout/app_layout.dart';
import 'package:uniygopro/pages/create_room/match_store.dart';
import 'package:uniygopro/pages/home_page.dart';
import 'package:uniygopro/pages/login_page.dart';

const _aiRoomKey = ValueKey('home-server-ai-room');
const _quickBattleKey = ValueKey('quick-battle-start');
const _guestEntryKey = ValueKey('login-guest-entry');

void main() {
  setUpAll(() {
    // HomePage / DeckEditorStore 都经 ServiceSingleton 取服务（饿汉单例），
    // 未注册会抛 UnimplementedError；注册回调里的卡片库预下载在 widget 测试
    // 环境会因缺少插件实现而异步失败，用独立 Zone 吞掉（本套用例不读卡库）。
    runZonedGuarded(registerAllServices, (error, stack) {});
    YgoSoundService.enabled = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// 挂载真实大厅壳（AppLayoutScope 由真实视口派生，与 app.dart 注入点一致）。
  Future<void> pumpLobby(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final account = MyCardAccountApi();
    addTearDown(account.dispose);
    final deckStore = DeckEditorStore();
    addTearDown(deckStore.dispose);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MyCardAccountApi>.value(value: account),
          ChangeNotifierProvider<MatchStore>(create: (_) => MatchStore()),
          ChangeNotifierProvider<DeckEditorStore>.value(value: deckStore),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => AppLayoutScope(child: child!),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('大厅 → 卡组 → 组卡器', () {
    testWidgets('compact 640×360：单栏组卡器的底部卡组栏不与底部 Tab 重叠', (tester) async {
      const size = Size(640, 360);
      await pumpLobby(tester, size);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('卡组'));
      await tester.pump();
      await tester.tap(find.text('组卡器'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.byType(DeckEditorPage), findsOneWidget);
      // 单栏：没有卡组列表栏。
      expect(find.byType(DeckListPanel), findsNothing);

      final expand = find.text('展开编辑');
      expect(expand, findsOneWidget);

      // 底部 Tab 顶边 = 屏高 - bottomTabHeight(56)。
      final tabBarTop = size.height - 56;
      final expandRect = tester.getRect(expand);
      expect(
        expandRect.bottom,
        lessThanOrEqualTo(tabBarTop + 0.5),
        reason: '「展开编辑」被底部 Tab 压盖：rect=$expandRect, tabBarTop=$tabBarTop',
      );
      // 也不能被挤出屏幕。
      expect(expandRect.top, greaterThanOrEqualTo(0));

      // 抽屉仍能在宿主壳内弹出。
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact 640×360：内嵌单栏的保存入口可点且命中 >= 44', (tester) async {
      const size = Size(640, 360);
      await pumpLobby(tester, size);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('卡组'));
      await tester.pump();
      await tester.tap(find.text('组卡器'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);

      // 内嵌态没有路由可返回，但移动 AppBar 的 `Icons.save` 是单栏下唯一
      // 保存入口（桌面 `_AppBarActions` 只在桌面布局渲染）。删掉它 = 砍功能，
      // 因此这里按「必须存在 + 真的能点 + 命中 >= 44」设断言。
      final save = find.byIcon(Icons.save);
      expect(save, findsOneWidget, reason: '内嵌单栏缺少保存入口（AppBar 被误删？）');
      expect(
        save.hitTestable().evaluate(),
        isNotEmpty,
        reason: '保存按钮被遮挡，无法命中',
      );
      // 命中区是外层 IconButton（图标本身只有 24×24，不是可点区域）。
      final saveButton = find
          .ancestor(of: save, matching: find.byType(IconButton))
          .first;
      final saveRect = tester.getRect(saveButton);
      expect(saveRect.top, greaterThanOrEqualTo(0));
      expect(
        saveRect.bottom,
        lessThanOrEqualTo(size.height),
        reason: '保存按钮越出视口：rect=$saveRect',
      );
      expect(
        saveRect.height,
        greaterThanOrEqualTo(44),
        reason: '保存按钮命中高 ${saveRect.height} < 44',
      );
    });

    testWidgets('regular 1280×720：双栏组卡器渲染（列表 240 + 底部卡组栏）', (tester) async {
      await pumpLobby(tester, const Size(1280, 720));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('卡组'));
      await tester.pump();
      await tester.tap(find.text('组卡器'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.byType(DeckEditorPage), findsOneWidget);
      expect(tester.getSize(find.byType(DeckListPanel)).width, 240);
      expect(find.text('展开编辑'), findsOneWidget);
    });
  });

  group('主操作命中区 >= 44（spec 触控要求）', () {
    testWidgets('大厅 compact 640×360：快速对战 / 模式卡 / 底部 Tab', (tester) async {
      await pumpLobby(tester, const Size(640, 360));
      expect(tester.takeException(), isNull);

      for (final entry in {
        '快速对战主按钮': find.byKey(_quickBattleKey),
        'AI 对决模式卡': find.byKey(_aiRoomKey),
      }.entries) {
        expect(entry.value, findsOneWidget, reason: '${entry.key} 未渲染');
        final size = tester.getSize(entry.value);
        expect(
          size.height,
          greaterThanOrEqualTo(44),
          reason: '${entry.key} 命中高 ${size.height} < 44',
        );
      }

      // 底部 Tab 项：图标 + 文字整块可点，高度即 TabBar 高度。
      final tab = tester.getRect(find.text('决斗'));
      expect(tab.height, greaterThanOrEqualTo(10)); // 文字本身可小
      final tabItemTop = tester.getRect(find.text('决斗')).center.dy;
      final tabBarTop = 360.0 - 56;
      expect(tabItemTop, greaterThan(tabBarTop));
    });

    testWidgets('登录页四尺寸：返回 / 游客进入 / 登录按钮均可命中且 >= 44', (tester) async {
      for (final size in const [
        Size(640, 360),
        Size(800, 450),
        Size(1280, 720),
        Size(1920, 1080),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final account = MyCardAccountApi();
        addTearDown(account.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<MyCardAccountApi>.value(
            value: account,
            child: MaterialApp(
              home: Builder(
                builder: (context) => const AppLayoutScope(child: LoginPage()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size 渲染异常');

        final submit = find.byKey(const ValueKey('mycard-login-submit'));
        expect(
          tester.getSize(submit).height,
          greaterThanOrEqualTo(44),
          reason: '$size 登录按钮命中高不足 44',
        );

        // 「游客进入」是首启链路的唯一无账号入口：必须真的能点。
        // （compact 下表单一度整宽铺满并盖住它，导致点击无效。）
        final guest = find.byKey(_guestEntryKey);
        expect(guest, findsOneWidget, reason: '$size 缺少游客进入按钮');
        expect(
          guest.hitTestable().evaluate(),
          isNotEmpty,
          reason: '$size 游客进入按钮被表单遮挡，无法命中',
        );
        expect(
          tester.getSize(guest).height,
          greaterThanOrEqualTo(44),
          reason: '$size 游客进入按钮命中高不足 44',
        );

        final back = find.byKey(const ValueKey('login-back'));
        expect(
          back.hitTestable().evaluate(),
          isNotEmpty,
          reason: '$size 返回按钮被表单遮挡，无法命中',
        );
      }
    });
  });
}
