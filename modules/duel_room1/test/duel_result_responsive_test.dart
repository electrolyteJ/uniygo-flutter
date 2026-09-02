import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duel_room1/duel_result_page.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

const _safePadding = EdgeInsets.fromLTRB(44, 8, 21, 16);
const _longName =
    '这是一个用于验证结算页面单行省略且不会挤压生命值显示的超长玩家名称'
    '这是一个用于验证结算页面单行省略且不会挤压生命值显示的超长玩家名称';
const _longReason =
    '这是一个长度超过八十个字符的自定义结束原因，用于验证结算内容能够在低高度横屏设备中滚动，'
    '同时底部主要操作按钮始终固定在安全区域内，不会因内容增长而溢出或被系统区域遮挡。';

void main() {
  final cases =
      <
        ({
          String name,
          String title,
          bool didWin,
          int? winPlayer,
          PlayerType type,
        })
      >[
        (
          name: '胜利',
          title: '胜利',
          didWin: true,
          winPlayer: 0,
          type: PlayerType.player1,
        ),
        (
          name: '失败',
          title: '失败',
          didWin: false,
          winPlayer: 1,
          type: PlayerType.player1,
        ),
        (
          name: '平局',
          title: '平局',
          didWin: false,
          winPlayer: 2,
          type: PlayerType.player1,
        ),
        (
          name: '观战',
          title: '决斗结束',
          didWin: true,
          winPlayer: 0,
          type: PlayerType.observer,
        ),
      ];

  for (final size in responsiveViewports) {
    for (final testCase in cases) {
      testWidgets('${testCase.name}结算在 $size 内安全且 action 固定', (tester) async {
        var actionCount = 0;
        await pumpResponsiveWidget(
          tester,
          ProviderScope(
            overrides: [
              duelRoomProvider.overrideWith(
                () => _ResultRoomNotifier(
                  DuelRoomState(
                    stage: const RoomDuelEnded(),
                    selfType: testCase.type,
                  ),
                ),
              ),
            ],
            child: DuelResultPage(
              result: {
                'didWin': testCase.didWin,
                'winPlayer': testCase.winPlayer,
                'selfName': _longName,
                'opponentName': _longName,
                'selfLp': 8000,
                'opponentLp': 123456,
                'reason': _longReason,
              },
              onAction: () => actionCount++,
            ),
          ),
          size,
          safePadding: _safePadding,
        );

        final panel = find.byKey(const ValueKey('duel-result-panel'));
        final action = find.byKey(const ValueKey('duel-result-action'));
        final spec = DuelRoomLayoutSpec.resolve(
          size,
          safePadding: _safePadding,
        );
        expect(panel, findsOneWidget);
        expect(action, findsOneWidget);
        expect(spec.safeRect.contains(tester.getRect(panel).topLeft), isTrue);
        expect(
          spec.safeRect.contains(tester.getRect(panel).bottomRight),
          isTrue,
        );
        expect(spec.safeRect.contains(tester.getRect(action).topLeft), isTrue);
        expect(
          spec.safeRect.contains(tester.getRect(action).bottomRight),
          isTrue,
        );
        expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
        expect(
          find.descendant(of: panel, matching: find.byType(Scrollable)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(Scrollable),
            matching: find.text(testCase.title),
          ),
          findsOneWidget,
        );
        for (final text in tester.widgetList<Text>(find.text(_longName))) {
          expect(text.maxLines, 1);
          expect(text.overflow, TextOverflow.ellipsis);
        }
        expect(find.text('LP 8000'), findsOneWidget);
        expect(find.text('LP 123456'), findsOneWidget);
        expect(find.text('结束原因：未知'), findsOneWidget);
        expect(find.textContaining(_longReason), findsNothing);
        await tester.tap(action);
        expect(actionCount, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('换备 action 仍 dismiss 且不调用 override', (tester) async {
    var actionCount = 0;
    var dismissedCount = 0;
    await pumpResponsiveWidget(
      tester,
      ProviderScope(
        overrides: [
          duelRoomProvider.overrideWith(
            () => _ResultRoomNotifier(
              const DuelRoomState(
                stage: RoomSideDecking(),
                selfType: PlayerType.player1,
              ),
            ),
          ),
        ],
        child: DuelResultPage(
          result: const {'didWin': true, 'selfLp': 8000, 'opponentLp': 0},
          onAction: () => actionCount++,
          onDismissed: () => dismissedCount++,
        ),
      ),
      const Size(640, 360),
    );
    await tester.tap(find.byKey(const ValueKey('duel-result-action')));
    await tester.pump();
    expect(find.byKey(const ValueKey('duel-result-panel')), findsOneWidget);
    expect(actionCount, 0);
    expect(dismissedCount, 1);
  });

  testWidgets('结算保留不可 dismiss 的 ModalBarrier', (tester) async {
    await pumpResponsiveWidget(
      tester,
      ProviderScope(
        overrides: [
          duelRoomProvider.overrideWith(
            () => _ResultRoomNotifier(
              const DuelRoomState(selfType: PlayerType.player1),
            ),
          ),
        ],
        child: DuelResultPage(result: const {'didWin': true}, onAction: () {}),
      ),
      const Size(640, 360),
    );
    final barrier = tester.widget<ModalBarrier>(
      find.descendant(
        of: find.byType(DuelResultPage),
        matching: find.byType(ModalBarrier),
      ),
    );
    expect(barrier.dismissible, isFalse);
  });
}

class _ResultRoomNotifier extends DuelRoomNotifier {
  _ResultRoomNotifier(this.initialState);

  final DuelRoomState initialState;

  @override
  DuelRoomState build() => initialState;
}
