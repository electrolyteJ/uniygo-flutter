/// 组卡器（deck_editor1 `DeckEditorPage`）的 Widget 级档位渲染验证。
///
/// 背景：`resolveDeckEditorColumns` 的纯函数契约已有测试，但**双栏是 S3
/// 新增的代码路径**（大厅「卡组 → 组卡器」在 regular 档注入 columns=2），
/// 此前只有函数级契约、没有一次真实渲染，因此这里补：
/// - regular 双栏：卡组列表 240 + 主区 + 底部卡组栏（「展开编辑」入口）；
/// - compact 单栏：无卡组列表栏，底部卡组栏仍在；
/// - wide 三栏：卡组列表 240 + 主区 + 编辑区 380；
/// - 「展开编辑」底部抽屉（占屏 72%）在 640×360 下不溢出、`DeckEditPanel`
///   真实渲染（此前是死按钮）。
library;

import 'dart:async';

import 'package:biz/service_loader.registrations.g.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:deck_editor1/deck_editor1.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _expandButtonText = '展开编辑';

void main() {
  setUpAll(() {
    // DeckEditorStore 构造期即读取 ServiceSingleton（饿汉单例，构造期 create
    // 各服务，未注册会抛 UnimplementedError）；注册表里的卡片库服务会
    // fire-and-forget 预下载 SQLite（widget 测试无 path_provider 插件实现），
    // 用独立 Zone 吞掉该异步失败——本套用例不读卡片库。
    runZonedGuarded(registerAllServices, (error, stack) {});
    YgoSoundService.enabled = false;
  });

  Future<DeckEditorStore> pumpEditor(
    WidgetTester tester, {
    required Size size,
    required int columns,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = DeckEditorStore();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<DeckEditorStore>.value(
        value: store,
        child: MaterialApp(
          home: Scaffold(
            body: DeckEditorPage(embedded: true, columns: columns),
          ),
        ),
      ),
    );
    await tester.pump(); // postFrameCallback → store.initialize()
    await tester.pump(const Duration(milliseconds: 100));
    return store;
  }

  group('档位渲染', () {
    testWidgets('regular 双栏（1280×720）：卡组列表 240 + 底部卡组栏，不溢出', (tester) async {
      await pumpEditor(tester, size: const Size(1280, 720), columns: 2);

      expect(tester.takeException(), isNull);
      // 卡组列表栏是双栏/三栏的标志（单栏走 _buildMobileLayout，没有它）。
      expect(find.byType(DeckListPanel), findsOneWidget);
      expect(tester.getSize(find.byType(DeckListPanel)).width, 240);
      // 双栏/单栏共用底部卡组栏：编辑入口必须存在。
      expect(find.text(_expandButtonText), findsOneWidget);
      // 双栏没有独立编辑区。
      expect(find.byType(DeckEditPanel), findsNothing);
    });

    testWidgets('compact 单栏（640×360）：无卡组列表栏，底部卡组栏在，不溢出', (tester) async {
      await pumpEditor(tester, size: const Size(640, 360), columns: 1);

      expect(tester.takeException(), isNull);
      expect(find.byType(DeckListPanel), findsNothing);
      expect(find.text(_expandButtonText), findsOneWidget);
      // 单栏布局不叠 AppBar（内嵌模式由宿主提供外壳）。
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('wide 三栏（1920×1080）：列表 240 + 编辑区 380', (tester) async {
      await pumpEditor(tester, size: const Size(1920, 1080), columns: 3);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(DeckListPanel)).width, 240);
      expect(tester.getSize(find.byType(DeckEditPanel)).width, 380);
      // 三栏有独立编辑区，不需要底部卡组栏。
      expect(find.text(_expandButtonText), findsNothing);
    });

    testWidgets('compact 单栏（640×360）：内嵌态仍保留保存与重命名入口', (tester) async {
      await pumpEditor(tester, size: const Size(640, 360), columns: 1);

      expect(tester.takeException(), isNull);
      // 单栏下「保存」与「重命名」只存在于 `_buildMobileAppBar` 一处
      // （桌面 `_buildAppBar` 的 `_AppBarActions` 与三栏布局都不参与单栏渲染）。
      // 因此内嵌态**不能**以「大厅已有导航、AppBar 冗余」为由整块删掉——
      // 删掉等于同时丢失保存与重命名两条功能路径。此断言锁住该决策。
      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing); // 内嵌态隐藏返回键

      // 点顶栏卡组名进入重命名（第一个「未命名卡组」在顶栏，第二个在底部卡组栏）。
      await tester.tap(find.text('未命名卡组').first);
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2)); // 搜索框 + 重命名框
      expect(find.text('输入卡组名称'), findsOneWidget); // 重命名框 hint
      expect(tester.takeException(), isNull);
    });
  });

  group('「展开编辑」底部抽屉', () {
    testWidgets('compact 640×360：抽屉占屏 72%，DeckEditPanel 渲染且不溢出', (tester) async {
      const size = Size(640, 360);
      await pumpEditor(tester, size: size, columns: 1);

      await tester.tap(find.text(_expandButtonText));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DeckEditPanel), findsOneWidget);
      // 抽屉高度 = 屏高 * 0.72（上下留出上下文）。
      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.height, closeTo(size.height * 0.72, 1.0));
      expect(sheet.bottom, closeTo(size.height, 1.0));
      // 抽屉内容不得溢出（DeckEditPanel 自带滚动）。
      expect(tester.takeException(), isNull);

      // 收起后按钮恢复可用（防重复开层的状态复位）。
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      expect(find.byType(DeckEditPanel), findsNothing);
      expect(find.text(_expandButtonText), findsOneWidget);
    });

    testWidgets('regular 双栏 1280×720：抽屉同样可用、不溢出', (tester) async {
      await pumpEditor(tester, size: const Size(1280, 720), columns: 2);

      await tester.tap(find.text(_expandButtonText));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DeckEditPanel), findsOneWidget);
      expect(
        tester.getRect(find.byType(BottomSheet)).height,
        closeTo(720 * 0.72, 1.0),
      );
    });
  });
}
