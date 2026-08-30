/// 等待房（waiting room）子域移植对齐的 widget 级测试。
///
/// 覆盖：
/// - 换备面板：主/额点卡移入副卡组、副卡组「→主/→额」按卡类型互斥、
///   数量一致才点亮确认、重置、初始化失败重试、观战只读；
/// - 房间信息面板：信息项渲染、禁限卡表行点击弹详情弹窗；
/// - 自动化开关：切换回调与禁用态。
library;

import 'package:biz/duel/room/duel_room_state.dart' show SidingZone;
import 'package:biz/widgets/banlist_detail_dialog.dart';
import 'package:duel_room3/waiting/widgets/automation_switch.dart';
import 'package:duel_room3/waiting/widgets/room_info_panel.dart';
import 'package:duel_room3/waiting/widgets/side_decking_panel.dart';
import 'package:duelink/duelink.dart' show DuelRule, RoomMode, RoomOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/card_info.dart' show CardInfo;
import 'package:resource_data/lf_table.dart' show LfInfo, LfTable, LfType;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SideDeckingPanel', () {
    const mainCard = CardInfo(code: 89631139, type: 0x11, name: '青眼白龙');
    const extraCard = CardInfo(code: 12345678, type: 0x41, name: '青眼究极龙');
    const normalSide = CardInfo(code: 11111111, type: 0x2, name: '旋风');
    const fusionSide = CardInfo(code: 22222222, type: 0x40, name: '融合怪兽');

    testWidgets('主卡组卡点击移入副卡组', (tester) async {
      final moves = <(SidingZone, SidingZone, int)>[];
      await tester.pumpWidget(
        _wrap(
          SideDeckingPanel(
            isDuelist: true,
            sidingMain: const [mainCard],
            sidingExtra: const [],
            sidingSide: const [],
            baselineMainCount: 1,
            baselineExtraCount: 0,
            baselineSideCount: 0,
            onMoveCard: (from, to, index) => moves.add((from, to, index)),
            onReset: () {},
            onConfirm: () async {},
          ),
        ),
      );

      await tester.tap(find.text('青眼白龙'));
      expect(moves, [(SidingZone.main, SidingZone.side, 0)]);
    });

    testWidgets('额外卡组卡点击移入副卡组', (tester) async {
      final moves = <(SidingZone, SidingZone, int)>[];
      await tester.pumpWidget(
        _wrap(
          SideDeckingPanel(
            isDuelist: true,
            sidingMain: const [],
            sidingExtra: const [extraCard],
            sidingSide: const [],
            baselineMainCount: 0,
            baselineExtraCount: 1,
            baselineSideCount: 0,
            onMoveCard: (from, to, index) => moves.add((from, to, index)),
            onReset: () {},
            onConfirm: () async {},
          ),
        ),
      );

      await tester.tap(find.text('青眼究极龙'));
      expect(moves, [(SidingZone.extra, SidingZone.side, 0)]);
    });

    testWidgets('副卡组按类型只显示 →主 或 →额', (tester) async {
      final moves = <(SidingZone, SidingZone, int)>[];
      await tester.pumpWidget(
        _wrap(
          SideDeckingPanel(
            isDuelist: true,
            sidingMain: const [],
            sidingExtra: const [],
            sidingSide: const [normalSide, fusionSide],
            baselineMainCount: 0,
            baselineExtraCount: 0,
            baselineSideCount: 2,
            onMoveCard: (from, to, index) => moves.add((from, to, index)),
            onReset: () {},
            onConfirm: () async {},
          ),
        ),
      );

      // 普通卡只给「→主」，额外卡组类型只给「→额」。
      expect(find.text('→主'), findsOneWidget);
      expect(find.text('→额'), findsOneWidget);

      await tester.tap(find.text('→主'));
      expect(moves.single, (SidingZone.side, SidingZone.main, 0));
      moves.clear();

      await tester.tap(find.text('→额'));
      expect(moves.single, (SidingZone.side, SidingZone.extra, 1));
    });

    testWidgets('数量与基准一致才点亮确认换备', (tester) async {
      Future<void> pumpPanel(int baselineMain) async {
        await tester.pumpWidget(
          _wrap(
            SideDeckingPanel(
              isDuelist: true,
              sidingMain: const [mainCard],
              sidingExtra: const [],
              sidingSide: const [],
              baselineMainCount: baselineMain,
              baselineExtraCount: 0,
              baselineSideCount: 0,
              onMoveCard: (_, _, _) {},
              onReset: () {},
              onConfirm: () async {},
            ),
          ),
        );
      }

      final confirm = find.byKey(const ValueKey('side-decking-confirm'));

      await pumpPanel(1);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

      await pumpPanel(2);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    });

    testWidgets('重置调用 onReset', (tester) async {
      var resetCount = 0;
      await tester.pumpWidget(
        _wrap(
          SideDeckingPanel(
            isDuelist: true,
            sidingMain: const [mainCard],
            sidingExtra: const [],
            sidingSide: const [],
            baselineMainCount: 1,
            baselineExtraCount: 0,
            baselineSideCount: 0,
            onMoveCard: (_, _, _) {},
            onReset: () => resetCount++,
            onConfirm: () async {},
          ),
        ),
      );

      await tester.tap(find.text('重置'));
      expect(resetCount, 1);
    });

    testWidgets('初始化失败显示重试并可点击', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _wrap(
          SideDeckingPanel(
            isDuelist: true,
            sidingMain: null,
            sidingExtra: null,
            sidingSide: null,
            sidingInitFailed: true,
            onRetryInit: () => retried++,
            baselineMainCount: 0,
            baselineExtraCount: 0,
            baselineSideCount: 0,
            onMoveCard: (_, _, _) {},
            onReset: () {},
            onConfirm: () async {},
          ),
        ),
      );

      expect(find.text('换备数据初始化失败'), findsOneWidget);
      await tester.tap(find.text('重试'));
      expect(retried, 1);
    });

    testWidgets('观战者只读等待提示', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SideDeckingPanel(
            isDuelist: false,
            sidingMain: const [mainCard],
            sidingExtra: const [],
            sidingSide: const [],
            baselineMainCount: 1,
            baselineExtraCount: 0,
            baselineSideCount: 0,
            onMoveCard: (_, _, _) {},
            onReset: () {},
            onConfirm: () async {},
          ),
        ),
      );

      expect(find.text('决斗者换备中…'), findsOneWidget);
      expect(find.text('确认换备'), findsNothing);
    });
  });

  group('RoomInfoPanel', () {
    const opts = RoomOptions(
      mode: RoomMode.single,
      rule: 0,
      duelRule: DuelRule.mr2020,
      startLp: 8000,
      startHand: 5,
      drawCount: 1,
      timeLimit: 180,
      noCheckDeck: false,
      noShuffleDeck: false,
      lfTableHash: 0,
    );

    testWidgets('渲染房间信息项', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RoomInfoPanel(opts: opts, cardLoader: (_) async => null),
        ),
      );

      expect(find.text('单局模式 · OCG'), findsOneWidget);
      expect(find.text('大师规则 2020'), findsOneWidget);
      expect(find.text('LP: 8000  手牌: 5  抽卡: 1'), findsOneWidget);
      expect(find.text('限时: 180秒'), findsOneWidget);
      expect(find.text('禁限卡表: 不限制'), findsOneWidget);
      expect(find.text('检查卡组: 是'), findsOneWidget);
      expect(find.text('切洗卡组: 是'), findsOneWidget);
    });

    testWidgets('禁限卡表行点击弹详情弹窗', (tester) async {
      const lfTable = LfTable(
        name: '2024.10 禁限卡表',
        date: '2024-10-01',
        lfInfos: {
          1: LfInfo(code: 89631139, limit: LfType.forbidden, name: '青眼白龙'),
        },
      );
      await tester.pumpWidget(
        _wrap(
          RoomInfoPanel(
            opts: opts,
            lfTable: lfTable,
            cardLoader: (_) async => null,
          ),
        ),
      );

      expect(find.text('禁限卡表: 2024.10 禁限卡表'), findsOneWidget);
      await tester.tap(find.text('禁限卡表: 2024.10 禁限卡表'));
      await tester.pumpAndSettle();
      expect(find.byType(BanlistDetailDialog), findsOneWidget);
    });
  });

  group('AutomationSwitch', () {
    testWidgets('开关切换回调', (tester) async {
      var received = false;
      await tester.pumpWidget(
        _wrap(
          AutomationSwitch(
            label: '自动猜拳',
            value: false,
            enabled: true,
            onChanged: (v) => received = v,
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      expect(received, isTrue);
    });

    testWidgets('禁用时不回调', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          AutomationSwitch(
            label: '自动猜拳',
            value: false,
            enabled: false,
            onChanged: (_) => called = true,
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      expect(called, isFalse);
    });
  });
}
