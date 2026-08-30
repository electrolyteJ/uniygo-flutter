/// 结算 overlay 的 widget 测试。
///
/// 覆盖 room1 → room3 对齐的结算展示：
/// - 胜利/失败标题、双方玩家名、双方 LP、结束原因文案；
/// - 观战者/平局的中性文案差异；
/// - 换备阶段按钮变「进入换备阶段」且点击后同一结果实例不再弹出；
/// - ModalBarrier 半透明遮罩点击不关闭。
library;

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart';
import 'package:duel_room3/duel_result_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 用固定状态 override 两个 provider，避免实例化真实 notifier 的
  /// 服务依赖；overlay 只读 duelResult / selfType / stage。
  Future<void> pumpWith(
    WidgetTester tester, {
    required Map<String, Object?> result,
    DuelRoomState room = const DuelRoomState(),
  }) async {
    final container = ProviderContainer(overrides: [
      duelFieldProvider.overrideWithValue(DuelFieldState(duelResult: result)),
      duelRoomProvider.overrideWithValue(room),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DuelResultOverlay()),
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

  testWidgets('决斗者胜利：标题/双方名/LP/结束原因/返回首页', (tester) async {
    await pumpWith(
      tester,
      result: winResult(),
      room: const DuelRoomState(
        selfType: PlayerType.player1,
        stage: RoomDuelEnded(),
      ),
    );

    expect(find.text('胜利'), findsOneWidget);
    expect(find.text('你赢下了这场决斗'), findsOneWidget);
    expect(find.text('玩家A'), findsOneWidget);
    expect(find.text('玩家B'), findsOneWidget);
    expect(find.text('LP 8000'), findsOneWidget);
    expect(find.text('LP 0'), findsOneWidget);
    expect(find.text('结束原因：LP 归零'), findsOneWidget);
    expect(find.text('返回首页'), findsOneWidget);
    // MaterialApp 路由自带一层 ModalBarrier，断言须限定在 overlay 子树内。
    expect(_overlayBarrier(), findsOneWidget);
  });

  testWidgets('决斗者失败：失败标题与落败文案', (tester) async {
    await pumpWith(
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
      room: const DuelRoomState(
        selfType: PlayerType.player1,
        stage: RoomDuelEnded(),
      ),
    );

    expect(find.text('失败'), findsOneWidget);
    expect(find.text('这场决斗落败'), findsOneWidget);
    expect(find.text('结束原因：认输'), findsOneWidget);
  });

  testWidgets('观战者：中性标题，按胜负展示胜者名', (tester) async {
    await pumpWith(
      tester,
      result: winResult(),
      room: const DuelRoomState(
        selfType: PlayerType.observer,
        stage: RoomDuelEnded(),
      ),
    );

    expect(find.text('决斗结束'), findsOneWidget);
    expect(find.text('玩家A 获胜'), findsOneWidget);
  });

  testWidgets('平局：中性文案与平局决胜原因', (tester) async {
    await pumpWith(
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
      room: const DuelRoomState(
        selfType: PlayerType.player1,
        stage: RoomDuelEnded(),
      ),
    );

    expect(find.text('平局'), findsOneWidget);
    expect(find.text('双方战平'), findsOneWidget);
    expect(find.text('结束原因：平局决胜'), findsOneWidget);
  });

  testWidgets('换备阶段：按钮为「进入换备阶段」，点击后同实例关闭', (tester) async {
    await pumpWith(
      tester,
      result: winResult(),
      room: const DuelRoomState(
        selfType: PlayerType.player1,
        stage: RoomSideDecking(),
      ),
    );

    expect(find.text('进入换备阶段'), findsOneWidget);
    expect(find.text('胜利'), findsOneWidget);

    await tester.tap(find.text('进入换备阶段'));
    await tester.pump();
    // 同一结果实例已被关闭：overlay 退回透明占位。
    expect(find.text('胜利'), findsNothing);
    expect(_overlayBarrier(), findsNothing);
  });

  testWidgets('遮罩点击不关闭（非换备阶段）', (tester) async {
    await pumpWith(
      tester,
      result: winResult(),
      room: const DuelRoomState(
        selfType: PlayerType.player1,
        stage: RoomDuelEnded(),
      ),
    );

    expect(find.text('返回首页'), findsOneWidget);
    // 点面板外空白处（遮罩区域），不触发关闭。
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(find.text('返回首页'), findsOneWidget);
    expect(_overlayBarrier(), findsOneWidget);
  });
}

/// 只匹配结算 overlay 内部的遮罩（MaterialApp 的路由自带一层
/// ModalBarrier，全局 byType 会误伤）。
Finder _overlayBarrier() => find.descendant(
      of: find.byType(DuelResultOverlay),
      matching: find.byType(ModalBarrier),
    );
