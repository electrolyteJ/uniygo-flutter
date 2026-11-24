/// 结算页（duel_room1 `DuelResultPage`）响应式信息层级测试。
///
/// 覆盖：
/// - 统一信息层级：结果徽记（标题）/ 副标题 / LP 区 / 结束原因 / 操作按钮；
/// - 档位：wide、regular 面板宽 560 + LP 条 + 双按钮并排；
///   compact（可用宽 < 1024 或高 < 600）面板宽 `min(vw * 0.9, 420)`、
///   LP 条收起为纯数值、按钮纵向堆叠且最小高 48；
/// - 胜负配色：胜=金 0xFFFFD75A / 负=青 0xFF37E2FF / 平=灰 0xFF8A93A8
///   （与 room3 `HudTheme` 同值）；
/// - LP 缺失（room3 部分结算来源无 LP）时不展示 LP 区，不拿 0 冒充数据；
/// - 换备阶段保留「进入换备阶段」文案与 `duel-result-action` key，
///   并给出「返回首页」次按钮；点击主按钮仍走 onDismissed。
library;

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duel_room1/duel_result_page.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 结算面板 key（spec「必须保留的 key」）。
const _panelKey = ValueKey('duel-result-panel');
const _actionKey = ValueKey('duel-result-action');
const _leaveKey = ValueKey('duel-result-leave');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 以指定真实视口挂载结算页：布局规格由视口推导（与房间页注入点一致）。
  Future<void> pumpResult(
    WidgetTester tester, {
    required Map<String, Object?> result,
    required Size viewSize,
    DuelRoomState room = const DuelRoomState(
      selfType: PlayerType.player1,
      stage: RoomDuelEnded(),
    ),
    VoidCallback? onDismissed,
    VoidCallback? onLeave,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [duelRoomProvider.overrideWithValue(room)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: DuelRoomLayout(
            spec: DuelRoomLayoutSpec.resolve(viewSize, EdgeInsets.zero),
            child: DuelResultPage(
              result: result,
              onDismissed: onDismissed,
              onLeave: onLeave,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Map<String, Object?> winResult() => const {
    'didWin': true,
    'winPlayer': 0,
    'reason': 0x01,
    'selfName': '玩家A',
    'opponentName': '玩家B',
    'selfLp': 8000,
    'opponentLp': 0,
  };

  group('信息层级', () {
    testWidgets('常规档展示徽记/副标题/LP/原因/主按钮', (tester) async {
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(1280, 800),
      );

      expect(find.byKey(_panelKey), findsOneWidget);
      expect(find.text('胜利'), findsOneWidget);
      expect(find.text('你赢下了这场决斗'), findsOneWidget);
      expect(find.text('玩家A'), findsOneWidget);
      expect(find.text('玩家B'), findsOneWidget);
      expect(find.text('LP 8000'), findsOneWidget);
      expect(find.text('LP 0'), findsOneWidget);
      expect(find.text('结束原因：LP 归零'), findsOneWidget);
      expect(find.byKey(_actionKey), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('胜负配色与 room3 HudTheme 同值', (tester) async {
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(1280, 800),
      );
      expect(
        tester.widget<Text>(find.text('胜利')).style?.color,
        kDuelResultWinAccent,
      );
      expect(kDuelResultWinAccent, const Color(0xFFFFD75A));

      await pumpResult(
        tester,
        result: const {
          'didWin': false,
          'winPlayer': 1,
          'reason': 0x00,
          'selfName': '玩家A',
          'opponentName': '玩家B',
          'selfLp': 0,
          'opponentLp': 8000,
        },
        viewSize: const Size(1280, 800),
      );
      expect(find.text('失败'), findsOneWidget);
      expect(find.text('这场决斗落败'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('失败')).style?.color,
        kDuelResultLoseAccent,
      );
      expect(kDuelResultLoseAccent, const Color(0xFF37E2FF));

      await pumpResult(
        tester,
        result: const {
          'didWin': false,
          'winPlayer': 2,
          'reason': 0x54,
          'selfName': '玩家A',
          'opponentName': '玩家B',
          'selfLp': 8000,
          'opponentLp': 8000,
        },
        viewSize: const Size(1280, 800),
      );
      expect(find.text('平局'), findsOneWidget);
      expect(find.text('双方战平'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('平局')).style?.color,
        kDuelResultDrawAccent,
      );
      expect(kDuelResultDrawAccent, const Color(0xFF8A93A8));
    });

    testWidgets('观战者：中性标题、按胜负展示胜者名', (tester) async {
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(1280, 800),
        room: const DuelRoomState(
          selfType: PlayerType.observer,
          stage: RoomDuelEnded(),
        ),
      );

      expect(find.text('决斗结束'), findsOneWidget);
      expect(find.text('玩家A 获胜'), findsOneWidget);
    });
  });

  group('档位', () {
    testWidgets('wide 档：面板宽 560、双方 LP 条、单按钮撑满', (tester) async {
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(1920, 1080),
      );

      expect(tester.getSize(find.byKey(_panelKey)).width, 560);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
      // 单按钮：撑满面板内容宽度。
      expect(tester.getSize(find.byKey(_actionKey)).width, greaterThan(400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('regular 档：面板宽 560、LP 条可见', (tester) async {
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(1280, 800),
      );

      expect(tester.getSize(find.byKey(_panelKey)).width, 560);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    });

    testWidgets('断点：1024×600 归 regular（面板 560），1023×600 归 compact', (
      tester,
    ) async {
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(1024, 600),
      );
      expect(tester.getSize(find.byKey(_panelKey)).width, 560);

      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(1023, 600),
      );
      expect(tester.getSize(find.byKey(_panelKey)).width, 420);

      // 高度不足 600 同样归 compact（横屏手机 2340×1080 逻辑 780×360 级）。
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(1280, 599),
      );
      expect(tester.getSize(find.byKey(_panelKey)).width, 420);
    });

    testWidgets('compact 档：面板宽 min(vw*0.9, 420)、LP 条收起、无溢出', (tester) async {
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(640, 360),
      );

      // 640 * 0.9 = 576 > 420 → 取 420。
      expect(tester.getSize(find.byKey(_panelKey)).width, 420);
      // 窄档收起 LP 条，但 LP 数值仍可读。
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('LP 8000'), findsOneWidget);
      expect(find.text('LP 0'), findsOneWidget);
      expect(find.text('结束原因：LP 归零'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact 档：视口更窄时面板按 90% 收缩', (tester) async {
      // 宽 400、高 360：min(400*0.9, 420) = 360，再受
      // ResponsivePanel 安全边距钳制（不会贴边、不会溢出）。
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(400, 360),
      );
      final width = tester.getSize(find.byKey(_panelKey)).width;
      expect(width, lessThanOrEqualTo(360));
      expect(width, greaterThan(300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact 档：单按钮最小高 48', (tester) async {
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(640, 360),
      );
      expect(
        tester.getSize(find.byKey(_actionKey)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('换备阶段双按钮', () {
    const sideDeckingRoom = DuelRoomState(
      selfType: PlayerType.player1,
      stage: RoomSideDecking(),
    );

    testWidgets('宽档：进入换备阶段 + 返回首页 并排', (tester) async {
      var dismissed = 0;
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(1280, 800),
        room: sideDeckingRoom,
        onDismissed: () => dismissed++,
      );

      expect(find.text('进入换备阶段'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
      expect(find.byKey(_leaveKey), findsOneWidget);

      final primary = tester.getCenter(find.byKey(_actionKey));
      final secondary = tester.getCenter(find.byKey(_leaveKey));
      // 并排：同一行（dy 相同）、水平分开。
      expect(primary.dy, secondary.dy);
      expect(secondary.dx, greaterThan(primary.dx));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(_actionKey));
      await tester.pump();
      expect(dismissed, 1);
    });

    testWidgets('compact 档：按钮纵向堆叠、最小高 48', (tester) async {
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(640, 360),
        room: sideDeckingRoom,
        onDismissed: () {},
      );

      final primary = tester.getCenter(find.byKey(_actionKey));
      final secondary = tester.getCenter(find.byKey(_leaveKey));
      // 堆叠：同一列（dx 相同）、垂直分开且主按钮在上。
      expect(primary.dx, secondary.dx);
      expect(secondary.dy, greaterThan(primary.dy));
      expect(
        tester.getSize(find.byKey(_actionKey)).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byKey(_leaveKey)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact 档：双按钮常驻首屏可视区（不被滚动区裁切）', (tester) async {
      // 与 room3 同一回归线：按钮区必须在滚动区之外常驻。
      const viewSize = Size(640, 360);
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: viewSize,
        room: sideDeckingRoom,
        onDismissed: () {},
        onLeave: () {},
      );

      _expectFullyOnScreen(tester, find.byKey(_actionKey), viewSize);
      _expectFullyOnScreen(tester, find.byKey(_leaveKey), viewSize);
      expect(tester.takeException(), isNull);
    });

    testWidgets('弃权防呆：返回首页先二次确认，取消不离房、确认才离房', (tester) async {
      var left = 0;
      await pumpResult(
        tester,
        result: winResult(),
        viewSize: const Size(1280, 800),
        room: sideDeckingRoom,
        onLeave: () => left++,
      );

      // 点次按钮：只弹二次确认，不立即离房。
      await tester.tap(find.byKey(_leaveKey));
      await tester.pumpAndSettle();
      expect(find.text('放弃本场比赛？'), findsOneWidget);
      expect(find.text('换备阶段离开房间将放弃本场对局（判负）并返回首页，确定吗？'), findsOneWidget);
      expect(left, 0);
      // 结算面板仍在，主按钮仍可继续进入换备。
      expect(find.text('进入换备阶段'), findsOneWidget);

      // 取消：关闭确认框，仍不离房。
      await tester.tap(find.byKey(const ValueKey('duel-result-leave-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('放弃本场比赛？'), findsNothing);
      expect(left, 0);
      expect(find.byKey(_panelKey), findsOneWidget);

      // 确认：才真正走离房动作。
      await tester.tap(find.byKey(_leaveKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('duel-result-leave-confirm')));
      await tester.pumpAndSettle();
      expect(left, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('LP 缺失兜底', () {
    testWidgets('无 LP 字段：不展示 LP 区、不造 0', (tester) async {
      await pumpResult(
        tester,
        result: const {
          'didWin': true,
          'winPlayer': 0,
          'reason': 0x02,
          'selfName': '玩家A',
          'opponentName': '玩家B',
        },
        viewSize: const Size(1280, 800),
      );

      expect(find.textContaining('LP '), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('胜利'), findsOneWidget);
      expect(find.text('结束原因：卡组抽尽'), findsOneWidget);
      expect(find.byKey(_actionKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('只有单侧 LP：只展示有数据的一侧', (tester) async {
      await pumpResult(
        tester,
        result: const {
          'didWin': true,
          'winPlayer': 0,
          'reason': 0x00,
          'selfName': '玩家A',
          'opponentName': '玩家B',
          'selfLp': 3200,
        },
        viewSize: const Size(1280, 800),
      );

      expect(find.text('LP 3200'), findsOneWidget);
      expect(find.text('LP 0'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('防御性解析', () {
    testWidgets('空结果 map 不崩溃，回退默认文案', (tester) async {
      await pumpResult(
        tester,
        result: const {},
        viewSize: const Size(1280, 800),
      );

      expect(find.byKey(_panelKey), findsOneWidget);
      expect(find.text('失败'), findsOneWidget);
      expect(find.text('结束原因：未知'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// 断言控件矩形完全落在视口内（首屏可见，不需要滚动才能点到）。
void _expectFullyOnScreen(WidgetTester tester, Finder finder, Size viewport) {
  expect(finder, findsOneWidget, reason: '控件未渲染');
  final rect = tester.getRect(finder);
  expect(
    rect.top >= -0.5 &&
        rect.left >= -0.5 &&
        rect.bottom <= viewport.height + 0.5 &&
        rect.right <= viewport.width + 0.5,
    isTrue,
    reason: '控件应完全位于视口内，实际 rect=$rect，视口=$viewport',
  );
}
