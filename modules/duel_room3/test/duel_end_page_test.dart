/// 结算页的 widget 测试。
///
/// 覆盖 room1 → room3 对齐的结算展示：
/// - 胜利/失败标题、双方玩家名、双方 LP、结束原因文案；
/// - 观战者/平局的中性文案差异；
/// - 换备阶段按钮变「进入换备阶段」且点击后同一结果实例不再展示；
/// - 结算页是平级 tab 页（无遮罩），空结果时退化为空白占位。
library;

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart';
import 'package:duel_room3/end/duel_end_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 用固定状态 override 两个 provider，避免实例化真实 notifier 的
  /// 服务依赖；结算页只读 duelResult / selfType / stage。
  Future<void> pumpWith(
    WidgetTester tester, {
    required Map<String, Object?>? result,
    DuelRoomState room = const DuelRoomState(),
  }) async {
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
        child: const MaterialApp(home: DuelEndPage()),
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

  testWidgets('观战者：名字缺失时不能兜底成「自己 / 对手」', (tester) async {
    await pumpWith(
      tester,
      result: const {
        'didWin': false,
        'winPlayer': 0,
        'reason': 0x01,
        // 故意不给 selfName / opponentName，逼出兜底分支。
        'selfLp': 8000,
        'opponentLp': 0,
      },
      room: const DuelRoomState(
        selfType: PlayerType.observer,
        stage: RoomDuelEnded(),
      ),
    );

    expect(find.text('玩家 1'), findsOneWidget);
    expect(find.text('玩家 2'), findsOneWidget);
    // 观战者不占任何一方的席位，这两个词都不该出现。
    expect(find.text('自己'), findsNothing);
    expect(find.text('对手'), findsNothing);
    expect(find.text('决斗结束'), findsOneWidget);
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

  testWidgets('换备阶段：按钮为「进入换备阶段」，点击后同实例不再展示', (tester) async {
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
    // 同一结果实例已被关闭：本页退化为空白占位。
    expect(find.text('胜利'), findsNothing);
    expect(find.text('进入换备阶段'), findsNothing);
  });

  testWidgets('无结果：渲染空白占位，不展示任何结算内容', (tester) async {
    await pumpWith(
      tester,
      result: null,
      room: const DuelRoomState(
        selfType: PlayerType.player1,
        stage: RoomInDuel(isFirstTurn: true),
      ),
    );

    expect(find.text('胜利'), findsNothing);
    expect(find.text('失败'), findsNothing);
    expect(find.text('返回首页'), findsNothing);
  });

  testWidgets('结算页是平级页：不再自绘模态遮罩', (tester) async {
    await pumpWith(
      tester,
      result: winResult(),
      room: const DuelRoomState(
        selfType: PlayerType.player1,
        stage: RoomDuelEnded(),
      ),
    );

    // 叠层时代的 ModalBarrier 已随 tab 化移除；MaterialApp 路由自带的
    // 那一层不算本页内容，所以限定在本页子树内断言。
    expect(
      find.descendant(
        of: find.byType(DuelEndPage),
        matching: find.byType(ModalBarrier),
      ),
      findsNothing,
    );
  });
}
