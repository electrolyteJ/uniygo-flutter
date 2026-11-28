/// 换备界面（Ardot 531:2 / 531:147 / 531:245）widget 级测试。
///
/// 覆盖设计稿落地时最容易回退的几条约定：
/// - 主卡组用等宽卡面网格，同名卡聚合为 `×N` 角标；
/// - 「点一张主卡 + 点一张副卡」= 一次原子互换（不能退化成两次 move）；
/// - 张数不守恒时提交按钮禁用，底栏给得出缺几张；
/// - 提交失败原因进底栏错误条，不悬成 SnackBar；
/// - 已提交后整页切到等待形态（卡组快照 + 就绪圈）。
library;

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duel_room3/side_decking/widgets/side_card.dart';
import 'package:duel_room3/side_decking/widgets/side_deck_editor_view.dart';
import 'package:duel_room3/side_decking/widgets/side_waiting_view.dart';
import 'package:duel_room3/theme/cyber_side_tokens.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/card_info.dart' show CardInfo;

/// 主卡组普通怪兽。
CardInfo _main(int code, [String? name]) =>
    CardInfo(code: code, type: 0x11, name: name ?? '主$code');

/// 额外卡组融合怪兽。
CardInfo _extra(int code, [String? name]) =>
    CardInfo(code: code, type: 0x41, name: name ?? '额$code');

/// 魔法卡（副卡组常见类型）。
CardInfo _spell(int code, [String? name]) =>
    CardInfo(code: code, type: 0x2, name: name ?? '魔$code');

/// 造一个换备阶段的状态。
DuelRoomState _room({
  List<CardInfo>? main,
  List<CardInfo>? extra,
  List<CardInfo>? side,
  List<CardInfo>? baseMain,
  List<CardInfo>? baseExtra,
  List<CardInfo>? baseSide,
  bool submitted = false,
  ResolvedDeck? snapshot,
  PlayerType selfType = PlayerType.player1,
  List<PlayerInfo> players = const [
    PlayerInfo(name: 'kaiba', pos: 0, ready: false),
    PlayerInfo(name: 'muto', pos: 1, ready: false),
  ],
}) {
  final m = main ?? [_main(101), _main(102), _main(103)];
  final e = extra ?? [_extra(201)];
  final s = side ?? [_spell(301), _spell(302)];
  return DuelRoomState(
    stage: const RoomSideDecking(),
    selfType: selfType,
    selectedDeckName: '青眼白龙 · 混沌龙',
    players: players,
    sidingDeck: (main: m, extra: e, side: s),
    sidingBaseline: (
      main: baseMain ?? m,
      extra: baseExtra ?? e,
      side: baseSide ?? s,
    ),
    sidingSnapshot: snapshot,
    sidingSubmitted: submitted,
  );
}

/// 固定成设计稿尺寸（844×390）再测，避免默认 800×600 测试视口把
/// 三栏挤成负宽度。
Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: CyberSideTokens.designSize.width,
      height: CyberSideTokens.designSize.height,
      child: child,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SideCardGrid 同名卡聚合', () {
    test('连续同名卡合并成一组，非连续不合并', () {
      final groups = SideCardGrid.group(['A', 'A', 'B', 'A']);
      expect(groups.length, 3);
      expect(groups[0], (name: 'A', start: 0, count: 2));
      expect(groups[1], (name: 'B', start: 2, count: 1));
      expect(groups[2], (name: 'A', start: 3, count: 1));
    });

    test('空列表返回空组', () {
      expect(SideCardGrid.group(const []), isEmpty);
    });

    testWidgets('张数 >1 时渲染 ×N 角标', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SideCardGrid(
            items: ['增殖的G', '增殖的G', '增殖的G', '灰流丽'],
            kind: SideCardKind.main,
          ),
        ),
      );
      expect(find.text('×3'), findsOneWidget);
      // 灰流丽只有一张，不应有 ×1 角标。
      expect(find.text('×1'), findsNothing);
    });

    testWidgets('缺卡时补「待补」空位', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SideCardGrid(
            items: ['A'],
            kind: SideCardKind.main,
            pendingCount: 2,
          ),
        ),
      );
      expect(find.text('待补'), findsNWidgets(2));
    });
  });

  group('SideDeckEditorView 版式', () {
    testWidgets('主卡组/额外卡组/副卡组三个分区标题都在', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SideDeckEditorView(
            room: _room(),
            onSwapCards: (_, _, _) {},
            onReset: () {},
            onSubmit: () async => null,
            onCancel: () {},
          ),
        ),
      );
      expect(find.text('MAIN DECK · 主卡组'), findsOneWidget);
      expect(find.text('EXTRA DECK · 额外卡组'), findsOneWidget);
      expect(find.text('SIDE · 副卡组'), findsOneWidget);
      expect(find.text('换牌清单 · 0 组'), findsOneWidget);
    });

    testWidgets('主卡组数量与基准一致时显示 heal 色读数', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SideDeckEditorView(
            room: _room(),
            onSwapCards: (_, _, _) {},
            onReset: () {},
            onSubmit: () async => null,
            onCancel: () {},
          ),
        ),
      );
      final label = tester.widget<Text>(find.text('3 / 3'));
      expect(label.style?.color, CyberSideTokens.heal);
    });

    testWidgets('主卡组缺卡时读数转酸绿并写「缺 N」', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SideDeckEditorView(
            room: _room(
              main: [_main(101), _main(102)],
              side: [_spell(301), _spell(302), _main(103)],
              baseMain: [_main(101), _main(102), _main(103)],
            ),
            onSwapCards: (_, _, _) {},
            onReset: () {},
            onSubmit: () async => null,
            onCancel: () {},
          ),
        ),
      );
      expect(find.text('2 / 3 · 缺 1'), findsOneWidget);
      final label = tester.widget<Text>(find.text('2 / 3 · 缺 1'));
      expect(label.style?.color, CyberSideTokens.acid);
    });

    testWidgets('张数不守恒时底栏显示待补而非守恒 ✓', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SideDeckEditorView(
            room: _room(
              main: [_main(101), _main(102)],
              side: [_spell(301), _spell(302), _main(103)],
              baseMain: [_main(101), _main(102), _main(103)],
            ),
            onSwapCards: (_, _, _) {},
            onReset: () {},
            onSubmit: () async => null,
            onCancel: () {},
          ),
        ),
      );
      expect(find.text('张数待补'), findsOneWidget);
      expect(find.text('张数守恒 ✓'), findsNothing);
    });
  });

  group('SideDeckEditorView 换牌交互', () {
    testWidgets('点主卡再点副卡 = 一次原子互换', (tester) async {
      final swaps = <(int, int, SidingZone)>[];
      await tester.pumpWidget(
        _wrap(
          SideDeckEditorView(
            room: _room(),
            onSwapCards: (b, s, z) => swaps.add((b, s, z)),
            onReset: () {},
            onSubmit: () async => null,
            onCancel: () {},
          ),
        ),
      );
      // 主卡面不显示卡名，按 SideCard 顺序定位：第一格是主卡组第 0 张。
      await tester.tap(find.byType(SideCard).first);
      await tester.pump();
      // 副卡组第 0 行（带卡名）。
      await tester.tap(find.text('魔301'));
      await tester.pump();

      expect(swaps, [(0, 0, SidingZone.main)]);
    });

    testWidgets('副卡组卡名与卡类副标都渲染', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SideDeckEditorView(
            room: _room(side: [_spell(301, '旋风'), _main(302, '增殖的G')]),
            onSwapCards: (_, _, _) {},
            onReset: () {},
            onSubmit: () async => null,
            onCancel: () {},
          ),
        ),
      );
      expect(find.text('旋风'), findsOneWidget);
      expect(find.text('增殖的G'), findsOneWidget);
      expect(find.textContaining('魔法'), findsOneWidget);
    });

    testWidgets('先点副卡再点主卡，同样触发一次互换且下标不串位', (tester) async {
      // 副卡组第 0 张进主卡组第 2 张的位置。
      final swaps = <(int, int, SidingZone)>[];
      await tester.pumpWidget(
        _wrap(
          SideDeckEditorView(
            room: _room(),
            onSwapCards: (b, s, z) => swaps.add((b, s, z)),
            onReset: () {},
            onSubmit: () async => null,
            onCancel: () {},
          ),
        ),
      );
      await tester.tap(find.text('魔301'));
      await tester.pump();
      // 主卡组第 3 格（下标 2）。
      await tester.tap(find.byType(SideCard).at(2));
      await tester.pump();

      expect(swaps, [(2, 0, SidingZone.main)]);
    });

    testWidgets('额外卡组卡不能通过副卡组换进主卡组（点击失败给提示）', (tester) async {
      final swaps = <(int, int, SidingZone)>[];
      await tester.pumpWidget(
        _wrap(
          SideDeckEditorView(
            // 副卡组里放一张额外卡组类型（融合怪兽）。
            room: _room(side: [_extra(401, '融合怪兽'), _spell(302)]),
            onSwapCards: (b, s, z) => swaps.add((b, s, z)),
            onReset: () {},
            onSubmit: () async => null,
            onCancel: () {},
          ),
        ),
      );
      // 选主卡组第一张，再点副卡组里的融合怪兽 → 分区不匹配，不互换。
      await tester.tap(find.byType(SideCard).first);
      await tester.pump();
      await tester.tap(find.text('融合怪兽'));
      await tester.pump();

      expect(swaps, isEmpty);
      expect(find.textContaining('属于额外卡组'), findsOneWidget);
    });

    testWidgets('提交失败原因显示在底栏错误条', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SideDeckEditorView(
            room: _room(),
            onSwapCards: (_, _, _) {},
            onReset: () {},
            onSubmit: () async => '卡组不合规: 副卡组 14 张',
            onCancel: () {},
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('side-decking-submit')));
      await tester.pumpAndSettle();
      expect(find.text('卡组不合规: 副卡组 14 张'), findsOneWidget);
    });

    testWidgets('重置回调可点击', (tester) async {
      var resets = 0;
      await tester.pumpWidget(
        _wrap(
          SideDeckEditorView(
            room: _room(),
            onSwapCards: (_, _, _) {},
            onReset: () => resets++,
            onSubmit: () async => null,
            onCancel: () {},
          ),
        ),
      );
      await tester.tap(find.text('重置未提交'));
      expect(resets, 1);
    });

    testWidgets('加载失败态给出重试入口', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SideDeckEditorView(
            room: const DuelRoomState(
              stage: RoomSideDecking(),
              sidingInitFailed: true,
            ),
            onSwapCards: (_, _, _) {},
            onReset: () {},
            onSubmit: () async => null,
            onCancel: () {},
          ),
        ),
      );
      expect(find.text('换备数据初始化失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });
  });

  group('SideWaitingView 等待形态', () {
    testWidgets('显示卡组快照与就绪圈', (tester) async {
      final room = _room(submitted: true);
      await tester.pumpWidget(
        _wrap(
          SideWaitingView(room: room, onResubmit: () {}, onCancelEdit: null),
        ),
      );
      expect(find.text('DECK SNAPSHOT · 换备后卡组'), findsOneWidget);
      expect(find.text('WAITING · 等待对手'), findsOneWidget);
      expect(find.text('已提交'), findsOneWidget);
      expect(find.text('对手换备中…'), findsOneWidget);
    });

    testWidgets('双方就绪后文案切换为已就绪', (tester) async {
      final room = _room(
        submitted: true,
        players: const [
          PlayerInfo(name: 'kaiba', pos: 0, ready: true),
          PlayerInfo(name: 'muto', pos: 1, ready: true),
        ],
      );
      await tester.pumpWidget(
        _wrap(
          SideWaitingView(room: room, onResubmit: () {}, onCancelEdit: null),
        ),
      );
      expect(find.text('muto 已就绪'), findsOneWidget);
      expect(find.text('对手换备中…'), findsNothing);
    });

    testWidgets('重新提交回调可点击', (tester) async {
      var count = 0;
      await tester.pumpWidget(
        _wrap(
          SideWaitingView(
            room: _room(submitted: true),
            onResubmit: () => count++,
            onCancelEdit: null,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('side-waiting-resubmit')));
      expect(count, 1);
    });

    testWidgets('观战者：不展示自有卡组快照，也不给提交按钮', (tester) async {
      final room = _room(submitted: true, selfType: PlayerType.observer);
      await tester.pumpWidget(
        _wrap(
          SideWaitingView(room: room, onResubmit: () {}, onCancelEdit: null),
        ),
      );

      // 观战者本地没有卡组，这份快照要么是空的要么是残留，且底栏已写明
      // 「不展示卡组细节」——整栏必须换成中性说明。
      expect(find.text('SPECTATOR · 观战视角'), findsOneWidget);
      expect(find.text('DECK SNAPSHOT · 换备后卡组'), findsNothing);
      expect(find.text('禁限表校验'), findsNothing);
      expect(find.text('换备 · 观战'), findsOneWidget);
      expect(find.text('WAITING · 换备进行中'), findsOneWidget);
      // 观战者没有卡组可提交。
      expect(find.text('重新提交'), findsNothing);
      expect(find.text('已提交 · 等待'), findsNothing);
      expect(find.text('已提交'), findsNothing);
      // 立场词也要消失（这几句是长文案的一部分，用包含匹配）。
      expect(find.textContaining('等待对手'), findsNothing);
      expect(find.text('对手换备中…'), findsNothing);
      expect(find.textContaining('等对手期间'), findsNothing);
      expect(find.textContaining('不能再改卡组'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('观战者反例：决斗者仍看得到卡组快照', (tester) async {
      // 防止把观战分支做成「所有身份都没有快照」。
      final room = _room(submitted: true);
      await tester.pumpWidget(
        _wrap(
          SideWaitingView(room: room, onResubmit: () {}, onCancelEdit: null),
        ),
      );
      expect(find.text('DECK SNAPSHOT · 换备后卡组'), findsOneWidget);
      expect(find.text('SPECTATOR · 观战视角'), findsNothing);
      expect(find.text('重新提交'), findsOneWidget);
    });

    testWidgets('换牌清单展示 ＋换入 / －换出', (tester) async {
      // 基准主 [101,102,103] 副 [301][302]；当前主 [301][102][103] 副 [101][302]。
      final room = _room(
        main: [_spell(301, '旋风'), _main(102), _main(103)],
        extra: [_extra(201)],
        side: [_main(101, '青眼白龙'), _spell(302)],
        baseMain: [_main(101, '青眼白龙'), _main(102), _main(103)],
        baseSide: [_spell(301, '旋风'), _spell(302)],
        submitted: true,
      );
      await tester.pumpWidget(
        _wrap(
          SideWaitingView(room: room, onResubmit: () {}, onCancelEdit: null),
        ),
      );
      expect(find.text('＋ 旋风 ×1'), findsOneWidget);
      expect(find.text('－ 青眼白龙 ×1'), findsOneWidget);
    });
  });

  group('布局健康度', _layoutHealthChecks);
}

/// 844×390 与几种真实窗口尺寸下的布局健康度。
///
/// 三栏版式的最大风险是横向溢出（主卡组卡宽固定 30、13 列）与右栏纵向
/// 溢出（换牌清单 + 就绪行）。本机 `toImage` 会被系统 kill，无法做截图
/// 比对，改用「渲染不抛异常」替代人工核对——任何 RenderFlex 溢出都会在
/// `pumpWidget` 期间抛出，`takeException` 能捕获到。
void _layoutHealthChecks() {
  const viewports = [
    Size(844, 390), // 设计稿基准
    Size(1280, 720), // 桌面窗口
    Size(960, 540), // 手机横屏
  ];

  for (final vp in viewports) {
    testWidgets('编辑界面在 ${vp.width.toInt()}×${vp.height.toInt()} 无溢出', (
      tester,
    ) async {
      tester.view.physicalSize = vp;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SideDeckEditorView(
              room: _room(
                main: [for (var i = 0; i < 40; i++) _main(1000 + i ~/ 3)],
                extra: [for (var i = 0; i < 15; i++) _extra(2000 + i)],
                side: [for (var i = 0; i < 15; i++) _spell(3000 + i)],
              ),
              onSwapCards: (_, _, _) {},
              onReset: () {},
              onSubmit: () async => null,
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('等待界面在 ${vp.width.toInt()}×${vp.height.toInt()} 无溢出', (
      tester,
    ) async {
      tester.view.physicalSize = vp;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SideWaitingView(
              room: _room(submitted: true),
              onResubmit: () {},
              onCancelEdit: null,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
