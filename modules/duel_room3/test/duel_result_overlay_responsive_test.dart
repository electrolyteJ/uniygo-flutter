/// room3 结算 overlay 的响应式档位测试。
///
/// 与 room1 结算页同一套信息层级，档位直接从真实视口（MediaQuery，
/// 扣除安全区）推导：
/// - wide / regular（可用宽 >= 1024 且高 >= 600）：面板宽 520、双方 LP 条、
///   按钮并排；
/// - compact：面板宽 `min(viewport.width * 0.9, 420)`、LP 条收起为纯数值、
///   按钮纵向堆叠且最小高 48；
/// - 换备阶段「进入换备阶段」+「返回首页」为真双按钮（此前换备阶段被
///   模态锁死无离房出口）。
library;

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duel_room3/duel_result_overlay.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _panelKey = ValueKey('duel-result-panel');
const _actionKey = ValueKey('duel-result-action');
const _leaveKey = ValueKey('duel-result-leave');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 用固定状态 override 两个 provider，避免实例化真实 notifier 的
  /// 服务依赖；overlay 只读 duelResult / selfType / stage。
  Future<void> pumpOverlay(
    WidgetTester tester, {
    required Map<String, Object?> result,
    required Size viewSize,
    DuelRoomState room = const DuelRoomState(
      selfType: PlayerType.player1,
      stage: RoomDuelEnded(),
    ),
    VoidCallback? onLeave,
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        duelFieldProvider.overrideWithValue(DuelFieldState(duelResult: result)),
        duelRoomProvider.overrideWithValue(room),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: DuelResultOverlay(onLeave: onLeave)),
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

  group('档位', () {
    testWidgets('regular 档：面板宽 520、双方 LP 条、保留 key', (tester) async {
      await pumpOverlay(
        tester,
        result: winResult(),
        viewSize: const Size(1280, 800),
      );

      expect(find.byKey(_panelKey), findsOneWidget);
      expect(tester.getSize(find.byKey(_panelKey)).width, 520);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
      expect(find.byKey(_actionKey), findsOneWidget);
      expect(find.text('LP 8000'), findsOneWidget);
      expect(find.text('LP 0'), findsOneWidget);
      expect(find.text('结束原因：LP 归零'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wide 档：面板宽同样 520（信息密集但不再加宽）', (tester) async {
      await pumpOverlay(
        tester,
        result: winResult(),
        viewSize: const Size(1920, 1080),
      );

      expect(tester.getSize(find.byKey(_panelKey)).width, 520);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('断点：1024×600 归 regular，1023×600 / 1280×599 归 compact', (
      tester,
    ) async {
      await pumpOverlay(
        tester,
        result: winResult(),
        viewSize: const Size(1024, 600),
      );
      expect(tester.getSize(find.byKey(_panelKey)).width, 520);

      await pumpOverlay(
        tester,
        result: winResult(),
        viewSize: const Size(1023, 600),
      );
      expect(tester.getSize(find.byKey(_panelKey)).width, 420);

      await pumpOverlay(
        tester,
        result: winResult(),
        viewSize: const Size(1280, 599),
      );
      expect(tester.getSize(find.byKey(_panelKey)).width, 420);
    });

    testWidgets('compact 档：面板宽 min(vw*0.9, 420)、LP 条收起、无溢出', (tester) async {
      await pumpOverlay(
        tester,
        result: winResult(),
        viewSize: const Size(640, 360),
      );

      expect(tester.getSize(find.byKey(_panelKey)).width, 420);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('LP 8000'), findsOneWidget);
      expect(find.text('结束原因：LP 归零'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact 档：视口更窄时面板按 90% 收缩且不越界', (tester) async {
      await pumpOverlay(
        tester,
        result: winResult(),
        viewSize: const Size(390, 360),
      );

      final width = tester.getSize(find.byKey(_panelKey)).width;
      expect(width, lessThanOrEqualTo(390 * 0.9 + 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('换备阶段双按钮', () {
    const sideDecking = DuelRoomState(
      selfType: PlayerType.player1,
      stage: RoomSideDecking(),
    );

    testWidgets('宽档：进入换备阶段 + 返回首页 并排，主按钮关闭 overlay', (tester) async {
      await pumpOverlay(
        tester,
        result: winResult(),
        viewSize: const Size(1280, 800),
        room: sideDecking,
      );

      expect(find.text('进入换备阶段'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);

      final primary = tester.getCenter(find.byKey(_actionKey));
      final secondary = tester.getCenter(find.byKey(_leaveKey));
      expect(primary.dy, secondary.dy);
      expect(secondary.dx, greaterThan(primary.dx));

      await tester.tap(find.byKey(_actionKey));
      await tester.pump();
      // 既有行为：同一结果实例关闭后退回透明占位。
      expect(find.text('进入换备阶段'), findsNothing);
      expect(find.byKey(_panelKey), findsNothing);
    });

    testWidgets('compact 档：按钮纵向堆叠、最小高 48', (tester) async {
      await pumpOverlay(
        tester,
        result: winResult(),
        viewSize: const Size(640, 360),
        room: sideDecking,
      );

      final primary = tester.getCenter(find.byKey(_actionKey));
      final secondary = tester.getCenter(find.byKey(_leaveKey));
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
      // 回归：按钮曾经在 SingleChildScrollView 内，640×360 + 双按钮时
      // 第二颗按钮 rect.bottom 361.8 越出视口 360，用户必须先滚动。
      const viewSize = Size(640, 360);
      await pumpOverlay(
        tester,
        result: winResult(),
        viewSize: viewSize,
        room: sideDecking,
        onLeave: () {},
      );

      _expectFullyOnScreen(tester, find.byKey(_actionKey), viewSize);
      _expectFullyOnScreen(tester, find.byKey(_leaveKey), viewSize);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact 档：超长玩家名撑高信息区时按钮仍常驻可视区', (tester) async {
      const viewSize = Size(640, 360);
      await pumpOverlay(
        tester,
        result: const {
          'didWin': true,
          'winPlayer': 0,
          'reason': 0x01,
          'selfName': '一个非常非常长的玩家名字用来撑高信息区',
          'opponentName': '同样非常非常长的对手名字用来撑高信息区',
          'selfLp': 123456,
          'opponentLp': 654321,
        },
        viewSize: viewSize,
        room: sideDecking,
        onLeave: () {},
      );

      expect(find.byType(SingleChildScrollView), findsWidgets);
      _expectFullyOnScreen(tester, find.byKey(_actionKey), viewSize);
      _expectFullyOnScreen(tester, find.byKey(_leaveKey), viewSize);
      expect(tester.takeException(), isNull);
    });

    testWidgets('弃权防呆：返回首页先二次确认，取消不离房、确认才离房', (tester) async {
      var left = 0;
      await pumpOverlay(
        tester,
        result: winResult(),
        viewSize: const Size(1280, 800),
        room: sideDecking,
        onLeave: () => left++,
      );

      // 点次按钮：只弹二次确认，不立即离房。
      await tester.tap(find.byKey(_leaveKey));
      await tester.pumpAndSettle();
      expect(find.text('放弃本场比赛？'), findsOneWidget);
      expect(find.text('换备阶段离开房间将放弃本场对局（判负）并返回首页，确定吗？'), findsOneWidget);
      expect(left, 0);
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

  group('胜负配色与 LP 兜底', () {
    testWidgets('胜利金色（HudTheme.gold）', (tester) async {
      await pumpOverlay(
        tester,
        result: winResult(),
        viewSize: const Size(1280, 800),
      );
      expect(
        tester.widget<Text>(find.text('胜利')).style?.color,
        const Color(0xFFFFD75A),
      );
    });

    testWidgets('失败青色（HudTheme.cyan）', (tester) async {
      await pumpOverlay(
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
      expect(
        tester.widget<Text>(find.text('失败')).style?.color,
        const Color(0xFF37E2FF),
      );
    });

    testWidgets('平局中性灰（HudTheme.textSecondary）', (tester) async {
      await pumpOverlay(
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
      expect(
        tester.widget<Text>(find.text('平局')).style?.color,
        const Color(0xFF8A93A8),
      );
    });

    testWidgets('无 LP 字段：不展示 LP 区、不造 0', (tester) async {
      await pumpOverlay(
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
      expect(find.text('结束原因：卡组抽尽'), findsOneWidget);
      expect(find.byKey(_actionKey), findsOneWidget);
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
