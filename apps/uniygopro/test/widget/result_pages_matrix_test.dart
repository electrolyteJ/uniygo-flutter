/// 结算页尺寸矩阵（duel_room1 + duel_room3）与 compact 档按钮常驻可见性。
///
/// 与 `responsive_matrix_test.dart` 互补：那份覆盖 room1 的四尺寸挂载，
/// 这份补两块实现者自认的空白：
/// 1. **room3 `DuelResultOverlay` 在四尺寸下的渲染**（宿主未注册结算路由，
///    overlay 自绘，档位从 `MediaQuery` 推导，与 room1 不同源，需独立验证）；
/// 2. **compact 档换备阶段双按钮是否真的常驻可见**——640×360 下信息区
///    必须滚动兜底，但两个按钮都得在首屏可视区内，不能要求用户先滚动。
library;

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duel_room1/duel_result_page.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:duel_room3/duel_result_overlay.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _panelKey = ValueKey('duel-result-panel');
const _actionKey = ValueKey('duel-result-action');
const _leaveKey = ValueKey('duel-result-leave');

const Map<String, Size> _matrix = {
  'compact 640×360': Size(640, 360),
  'compact 800×450': Size(800, 450),
  'regular 1280×720': Size(1280, 720),
  'wide 1920×1080': Size(1920, 1080),
};

const Map<String, Object?> _winResult = {
  'didWin': true,
  'winPlayer': 0,
  'reason': 0x01,
  'selfName': '玩家A',
  'opponentName': '玩家B',
  'selfLp': 8000,
  'opponentLp': 0,
};

const _sideDecking = DuelRoomState(
  selfType: PlayerType.player1,
  stage: RoomSideDecking(),
);

const _ended = DuelRoomState(
  selfType: PlayerType.player1,
  stage: RoomDuelEnded(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// room3 overlay：档位从 MediaQuery 推导，因此必须用真实视口挂载。
  Future<void> pumpOverlay(
    WidgetTester tester, {
    required Size viewSize,
    Map<String, Object?> result = _winResult,
    DuelRoomState room = _ended,
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

  /// room1 结算页：档位由房间页注入的 DuelRoomLayoutSpec 提供。
  Future<void> pumpResultPage(
    WidgetTester tester, {
    required Size viewSize,
    Map<String, Object?> result = _winResult,
    DuelRoomState room = _ended,
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
            child: DuelResultPage(result: result, onLeave: onLeave),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 断言控件矩形完全落在视口内（首屏可见，无需滚动）。
  void expectFullyOnScreen(WidgetTester tester, Finder finder, Size viewport) {
    expect(finder, findsOneWidget, reason: '控件未渲染');
    final rect = tester.getRect(finder);
    expect(
      rect.top >= -0.5 && rect.left >= -0.5 && rect.bottom <= viewport.height + 0.5 && rect.right <= viewport.width + 0.5,
      isTrue,
      reason: '控件应完全位于视口内，实际 rect=$rect，视口=$viewport',
    );
  }

  for (final entry in _matrix.entries) {
    final label = entry.key;
    final size = entry.value;

    group('room3 结算 overlay $label', () {
      testWidgets('渲染不溢出，关键 key 与信息层级完整', (tester) async {
        await pumpOverlay(tester, viewSize: size);

        expect(tester.takeException(), isNull);
        expect(find.byKey(_panelKey), findsOneWidget);
        expect(find.text('胜利'), findsOneWidget);
        expect(find.text('你赢下了这场决斗'), findsOneWidget);
        expect(find.text('胜利'), findsOneWidget);
        expect(find.text('结束原因：LP 归零'), findsOneWidget);
        expect(find.byKey(_actionKey), findsOneWidget);

        // 面板宽度不超过档位上限，也不越出视口。
        final panelWidth = tester.getSize(find.byKey(_panelKey)).width;
        final cap = DuelRoomLayoutSpec.resolve(
          size,
          EdgeInsets.zero,
        ).tier ==
            DuelRoomLayoutTier.compact
            ? 420.0
            : 520.0;
        expect(panelWidth, lessThanOrEqualTo(cap + 0.5));
        expect(panelWidth, lessThanOrEqualTo(size.width));
      });

      testWidgets('主按钮常驻可见且命中 >= 44', (tester) async {
        await pumpOverlay(tester, viewSize: size);

        expect(tester.takeException(), isNull);
        expectFullyOnScreen(tester, find.byKey(_actionKey), size);
        expect(
          tester.getSize(find.byKey(_actionKey)).height,
          greaterThanOrEqualTo(44),
        );
      });
    });
  }

  group('compact 640×360 换备阶段双按钮常驻可见', () {
    testWidgets('room1：两个按钮都在首屏可视区内，且不溢出', (tester) async {
      const size = Size(640, 360);
      await pumpResultPage(
        tester,
        viewSize: size,
        room: _sideDecking,
        onLeave: () {},
      );

      expect(tester.takeException(), isNull);
      expect(find.text('进入换备阶段'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
      expectFullyOnScreen(tester, find.byKey(_actionKey), size);
      expectFullyOnScreen(tester, find.byKey(_leaveKey), size);
    });

    testWidgets('room3：两个按钮都在首屏可视区内，且不溢出', (tester) async {
      const size = Size(640, 360);
      await pumpOverlay(
        tester,
        viewSize: size,
        room: _sideDecking,
        onLeave: () {},
      );

      expect(tester.takeException(), isNull);
      expect(find.text('进入换备阶段'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
      expectFullyOnScreen(tester, find.byKey(_actionKey), size);
      expectFullyOnScreen(tester, find.byKey(_leaveKey), size);
    });

    testWidgets('room1：信息区有滚动兜底容器（内容超长时不影响按钮）', (
      tester,
    ) async {
      const size = Size(640, 360);
      await pumpResultPage(
        tester,
        viewSize: size,
        room: _sideDecking,
        result: _longNamesResult,
        onLeave: () {},
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expectFullyOnScreen(tester, find.byKey(_actionKey), size);
      expectFullyOnScreen(tester, find.byKey(_leaveKey), size);
    });

    testWidgets('room3：信息区有滚动兜底容器（内容超长时不影响按钮）', (
      tester,
    ) async {
      const size = Size(640, 360);
      await pumpOverlay(
        tester,
        viewSize: size,
        room: _sideDecking,
        result: _longNamesResult,
        onLeave: () {},
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expectFullyOnScreen(tester, find.byKey(_actionKey), size);
      expectFullyOnScreen(tester, find.byKey(_leaveKey), size);
    });
  });

  group('换备阶段 compact 640×360「结束原因」是否需滚动', () {
    // s2 自报的已知项：「compact 双按钮下结束原因需滚动才看全」。
    // 这里用矩形实测证实/证伪：信息区是 Flexible(SingleChildScrollView)，
    // 被裁与否要看「结束原因矩形 vs 滚动视口矩形」，不是 vs 屏幕。
    for (final room3 in [false, true]) {
      final label = room3 ? 'room3' : 'room1';

      testWidgets('$label：结束原因可滚动到达，按钮不被滚走', (tester) async {
        const size = Size(640, 360);
        if (room3) {
          await pumpOverlay(
            tester,
            viewSize: size,
            room: _sideDecking,
            onLeave: () {},
          );
        } else {
          await pumpResultPage(
            tester,
            viewSize: size,
            room: _sideDecking,
            onLeave: () {},
          );
        }
        expect(tester.takeException(), isNull);

        final reason = find.textContaining('结束原因');
        expect(reason, findsOneWidget);

        final scroll = find.byType(SingleChildScrollView).first;
        final reasonRect = tester.getRect(reason);
        final scrollRect = tester.getRect(scroll);
        // ignore: avoid_print
        print(
          'MEASURE[$label 640×360] reason=$reasonRect scrollViewport=$scrollRect '
          'action=${tester.getRect(find.byKey(_actionKey))} '
          'leave=${tester.getRect(find.byKey(_leaveKey))}',
        );

        // 契约（硬断言）：无论首屏是否被裁，结束原因都必须能滚到滚动视口内。
        await tester.ensureVisible(reason);
        await tester.pumpAndSettle();
        final after = tester.getRect(reason);
        final viewport = tester.getRect(scroll);
        expect(
          after.top >= viewport.top - 0.5 && after.bottom <= viewport.bottom + 0.5,
          isTrue,
          reason: '结束原因应可滚动进滚动视口，实际 rect=$after 视口=$viewport',
        );

        // 滚动后按钮仍在首屏（按钮区在滚动区之外，不被滚走）。
        expectFullyOnScreen(tester, find.byKey(_actionKey), size);
        expectFullyOnScreen(tester, find.byKey(_leaveKey), size);
      });
    }
  });

  group('结算结果缺 LP 字段：不渲染 LP 区、不拿 0 冒充数据', () {
    const noLpResult = {
      'didWin': true,
      'winPlayer': 0,
      'reason': 0x01,
      'selfName': '玩家A',
      'opponentName': '玩家B',
    };

    testWidgets('room1：无 selfLp/opponentLp 时不出现 0/8000 数值行', (tester) async {
      await pumpResultPage(
        tester,
        viewSize: const Size(1280, 720),
        result: noLpResult,
        room: _ended,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(_panelKey), findsOneWidget);
      expect(find.text('结束原因：LP 归零'), findsOneWidget);
      expect(find.text('8000'), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('room3：无 selfLp/opponentLp 时不出现 0/8000 数值行', (tester) async {
      await pumpOverlay(
        tester,
        viewSize: const Size(1280, 720),
        result: noLpResult,
        room: _ended,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(_panelKey), findsOneWidget);
      expect(find.text('结束原因：LP 归零'), findsOneWidget);
      expect(find.text('8000'), findsNothing);
      expect(find.text('0'), findsNothing);
    });
  });
}

/// 超长对局名 + 大额 LP：用于把信息区撑到超出 640×360 的可视高度。
const Map<String, Object?> _longNamesResult = {
  'didWin': true,
  'winPlayer': 0,
  'reason': 0x01,
  'selfName': '一个非常非常长的玩家名字用来撑高信息区',
  'opponentName': '同样非常非常长的对手名字用来撑高信息区',
  'selfLp': 123456,
  'opponentLp': 654321,
};
