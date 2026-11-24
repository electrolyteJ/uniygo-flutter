/// 响应式尺寸矩阵：同一批页面在 4 档真实视口下都要「不溢出、导航形态正确、
/// 主按钮命中 >= 44」。
///
/// 矩阵：640×360（compact 横屏手机）/ 800×450（compact）/
/// 1280×720（regular）/ 1920×1080（wide）。
/// 断言方式说明：overflow 会以 FlutterError 抛出并让用例失败，这里额外用
/// [WidgetTester.takeException] 兜底，避免被后续 pump 吞掉。
library;

import 'dart:async';

import 'package:account_mycard/account_mycard.dart';
import 'package:biz/service_loader.registrations.g.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duel_room1/duel_result_page.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniygopro/layout/app_layout.dart';
import 'package:uniygopro/pages/create_room/match_store.dart';
import 'package:uniygopro/pages/home_page.dart';
import 'package:uniygopro/pages/login_page.dart';
import 'package:uniygopro/pages/splash_page.dart';

/// 尺寸矩阵：名称 → 视口。
const Map<String, Size> _matrix = {
  'compact 640×360': Size(640, 360),
  'compact 800×450': Size(800, 450),
  'regular 1280×720': Size(1280, 720),
  'wide 1920×1080': Size(1920, 1080),
};

AppLayoutTier _expectedTier(Size size) =>
    AppLayoutSpec.resolveTier(size, EdgeInsets.zero);

/// 设置视口并把控件挂上去（dpr 固定 1，避免逻辑像素被缩放）。
Future<void> _pumpAt(WidgetTester tester, Size size, Widget widget) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await tester.pump();
}

/// 带 AppLayoutScope（真实 MediaQuery 派生）与 go_router 的宿主壳。
Widget _routerHost(GoRouter router, MyCardAccountApi account) {
  return ChangeNotifierProvider<MyCardAccountApi>.value(
    value: account,
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => AppLayoutScope(child: child!),
    ),
  );
}

GoRouter _splashRouter() => GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('大厅占位'))),
  ],
);

GoRouter _loginRouter() => GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('大厅占位'))),
  ],
);

void main() {
  setUpAll(() {
    // 大厅切分区会经 ServiceSingleton 播放按键音，而 ServiceSingleton 是
    // 饿汉式单例（构造期即 create 各服务），未注册会抛 UnimplementedError，
    // 因此必须注册服务表。
    //
    // 但注册表里的卡片库服务会在 register 回调中 fire-and-forget 预下载
    // SQLite（依赖 path_provider 插件），widget 测试环境没有插件实现，会抛
    // MissingPluginException。本套用例不读卡片库，用独立 Zone 吞掉该异步
    // 失败，避免污染用例结果。
    runZonedGuarded(registerAllServices, (error, stack) {});
    YgoSoundService.enabled = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final entry in _matrix.entries) {
    final label = entry.key;
    final size = entry.value;

    group('开屏页 $label', () {
      testWidgets('渲染不溢出，动画结束后分流到登录页', (tester) async {
        await _pumpAt(
          tester,
          size,
          _routerHost(_splashRouter(), MyCardAccountApi()),
        );

        expect(find.text('uniygo'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 有限次动画（1200ms）结束后必须离开开屏（未登录 → /login）。
        // 用登录页专属控件判定，避免 wide 档登录页左侧品牌区也有 'uniygo' 字样。
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('mycard-login-username')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    });

    group('登录页 $label', () {
      testWidgets('表单可用、错误态可见、主按钮命中 >= 44', (tester) async {
        await _pumpAt(
          tester,
          size,
          _routerHost(_loginRouter(), MyCardAccountApi()),
        );
        expect(tester.takeException(), isNull);

        // spec 必须保留的 ValueKey。
        expect(
          find.byKey(const ValueKey('mycard-login-username')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('mycard-login-password')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('mycard-login-remember')),
          findsOneWidget,
        );

        final submit = find.byKey(const ValueKey('mycard-login-submit'));
        expect(submit, findsOneWidget);
        expect(tester.getSize(submit).height, greaterThanOrEqualTo(44));

        // 空表单提交 → 就地错误态，不发起网络。
        await tester.tap(submit);
        await tester.pump();
        expect(find.byKey(const ValueKey('mycard-login-error')), findsOneWidget);
        expect(find.text('请输入用户名和密码'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('大厅四分区 $label', () {
      testWidgets('导航形态正确、四分区可切、关键 key 未破坏', (tester) async {
        final account = MyCardAccountApi();
        await _pumpAt(
          tester,
          size,
          MultiProvider(
            providers: [
              ChangeNotifierProvider<MyCardAccountApi>.value(value: account),
              ChangeNotifierProvider<MatchStore>(create: (_) => MatchStore()),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => const AppLayoutScope(child: HomePage()),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);

        // 决斗分区：AI 入口 key 必须在（spec 必须保留）。
        expect(
          find.byKey(const ValueKey('home-server-ai-room')),
          findsOneWidget,
        );

        // 导航形态：compact 贴底 Tab，regular/wide 左侧 Rail。
        // 用「我的」标签的几何位置判定，避免依赖私有组件类型。
        final profile = find.text('我的');
        expect(profile, findsOneWidget);
        final center = tester.getCenter(profile);
        final tier = _expectedTier(size);
        if (tier == AppLayoutTier.compact) {
          expect(
            center.dy,
            greaterThan(size.height - 80),
            reason: 'compact 应使用底部 Tab，实际 dy=${center.dy}',
          );
        } else {
          expect(
            center.dx,
            lessThan(140),
            reason: '$tier 应使用左侧 Rail，实际 dx=${center.dx}',
          );
        }

        // 依次切换四个分区，全程不得抛异常（含 deck 分区拉市场数据的错误态）。
        for (final text in const ['卡组', '观战', '我的', '决斗']) {
          await tester.tap(find.text(text));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            tester.takeException(),
            isNull,
            reason: '切换到「$text」分区时抛出异常',
          );
        }

        // 卡组分区三段式入口存在（S1 契约）。
        await tester.tap(find.text('卡组'));
        await tester.pump();
        expect(find.text('卡组市场'), findsOneWidget);
        expect(find.text('我的卡组'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('结算页 $label', () {
      testWidgets('面板不溢出、主按钮命中 >= 44', (tester) async {
        final spec = DuelRoomLayoutSpec.resolve(size, EdgeInsets.zero);
        await _pumpAt(
          tester,
          size,
          MaterialApp(
            home: DuelRoomLayout(
              spec: spec,
              child: ProviderScope(
                child: DuelResultPage(
                  result: const {
                    'didWin': true,
                    'winPlayer': 1,
                    'selfName': '自己',
                    'opponentName': '对手',
                    'selfLp': 8000,
                    'opponentLp': 0,
                  },
                  onLeave: _noop,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);

        expect(find.byKey(const ValueKey('duel-result-panel')), findsOneWidget);
        final action = find.byKey(const ValueKey('duel-result-action'));
        expect(action, findsOneWidget);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(44));

        // 面板宽不超过档位上限（compact 420 / 常规 560），也不超出视口。
        final panelWidth = tester
            .getSize(find.byKey(const ValueKey('duel-result-panel')))
            .width;
        final cap = spec.tier == DuelRoomLayoutTier.compact ? 420.0 : 560.0;
        expect(panelWidth, lessThanOrEqualTo(cap + 0.5));
        expect(panelWidth, lessThanOrEqualTo(size.width));
      });
    });
  }

  // 设计评审复验判据：`maxContentWidth`（1600）唯一消费点是 login_page，
  // 大厅没用上；wide 档列数与 regular 同为 3（不是更多列）。
  // 这里只记录几何事实 + 防「溢出」这条底线，不给大厅加内容宽上限
  // （那是设计决策，不是测试能定的）。
  group('大厅 wide 档内容宽（已知设计风险：无 maxContentWidth 上限）', () {
    testWidgets('1920 下内容区铺到视口减 Rail 减内边距，列数与 regular 同为 3', (
      tester,
    ) async {
      final account = MyCardAccountApi();
      await _pumpAt(
        tester,
        const Size(1920, 1080),
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MyCardAccountApi>.value(value: account),
            ChangeNotifierProvider<MatchStore>(create: (_) => MatchStore()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => const AppLayoutScope(child: HomePage()),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final spec = AppLayoutSpec.resolve(
        const Size(1920, 1080),
        EdgeInsets.zero,
      );
      expect(spec.tier, AppLayoutTier.wide);

      final grid = find.byType(GridView);
      expect(grid, findsOneWidget);
      final gridWidth = tester.getSize(grid).width;
      // ignore: avoid_print
      print(
        'MEASURE[lobby wide 1920] gridWidth=$gridWidth '
        'rail=${spec.railWidth} pagePadding=${spec.pagePadding}',
      );
      // 内容区宽度 = 视口 - Rail - 2×pagePadding，没有 1600 上限。
      expect(
        gridWidth,
        closeTo(1920 - spec.railWidth - spec.pagePadding * 2, 1.0),
      );
      expect(
        gridWidth,
        greaterThan(1600),
        reason: '大厅未消费 maxContentWidth，1920 下内容宽超过 1600（已知设计风险）',
      );
      // 列数：regular/wide 都是 3（不随宽度增加）。
      final gridDelegate =
          tester.widget<GridView>(grid).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(gridDelegate.crossAxisCount, 3);
      expect(tester.takeException(), isNull);
    });
  });
}

void _noop() {}
