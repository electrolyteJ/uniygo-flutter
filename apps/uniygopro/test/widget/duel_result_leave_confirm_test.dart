/// 换备阶段「返回首页」弃权二次确认 —— **生产缺省路径**（`onLeave == null`）。
///
/// 单测（`duel_room1/test/duel_result_page_test.dart`、
/// `duel_room3/test/duel_result_overlay_responsive_test.dart`）只覆盖了
/// 注入 `onLeave` 的分支，缺省分支
/// `onLeave == null → leaveRoomAfterNotJoined(context, ref) → context.go('/')`
/// 此前没有任何自动化覆盖。本文件补这条：
///
/// 换备阶段 → 结算面板 → 点「返回首页」→ 弹「放弃本场比赛？」→
/// 取消（不离房、不导航）/ 确认（断开一次 + 落到 `/`）。
///
/// 用 `MaterialApp.router` + 真 `GoRouter` 观察 location 变化，不注入
/// `onLeave`（注入版与生产路径不是同一条代码）。
library;

import 'dart:typed_data';

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duel_room1/duel_result_page.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:duel_room3/duel_result_overlay.dart';
// ConnectionState 在 duelink 与 flutter/widgets 同名，假实现里显式取 duelink 那份。
import 'package:duelink/duelink.dart' hide ConnectionState;
import 'package:duelink/duelink.dart' as dl show ConnectionConnected, ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _panelKey = ValueKey('duel-result-panel');
const _leaveKey = ValueKey('duel-result-leave');
const _cancelKey = ValueKey('duel-result-leave-cancel');
const _confirmKey = ValueKey('duel-result-leave-confirm');
const _homeKey = ValueKey('fake-home');
const _dialogTitle = '放弃本场比赛？';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    YgoSoundService.enabled = false;
  });

  tearDown(() {
    YgoSoundService.enabled = true;
  });

  /// 只覆写 build，`markLeaving()` / `isLeaving` 仍走真实实现——
  /// 本用例要验的正是那段幂等去重。
  Future<_Harness> pumpHarness(
    WidgetTester tester, {
    required bool room3,
  }) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = _CountingDuelService();
    final locations = <String>[];

    final router = GoRouter(
      initialLocation: '/duel',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('HOME', key: _homeKey)),
          ),
        ),
        GoRoute(
          path: '/duel',
          builder: (context, _) => room3
              ? const DuelResultOverlay()
              : DuelRoomLayout(
                  spec: DuelRoomLayoutSpec.resolve(
                    const Size(1280, 720),
                    EdgeInsets.zero,
                  ),
                  child: DuelResultPage(result: _winResult),
                ),
        ),
      ],
    );
    addTearDown(router.dispose);
    router.routerDelegate.addListener(() {
      locations.add(router.routerDelegate.currentConfiguration.uri.toString());
    });

    final container = ProviderContainer(
      overrides: [
        duelFieldProvider.overrideWithValue(
          const DuelFieldState(duelResult: _winResult),
        ),
        duelRoomProvider.overrideWith(() => _SideDeckingNotifier(_sideDecking)),
        duelServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return _Harness(service: service, locations: locations);
  }

  /// 打开二次确认弹窗。
  Future<void> openDialog(WidgetTester tester) async {
    expect(find.byKey(_leaveKey), findsOneWidget);
    await tester.tap(find.byKey(_leaveKey));
    await tester.pumpAndSettle();
    expect(find.text(_dialogTitle), findsOneWidget);
    expect(find.byKey(_cancelKey), findsOneWidget);
    expect(find.byKey(_confirmKey), findsOneWidget);
  }

  for (final room3 in [false, true]) {
    final label = room3 ? 'room3 overlay' : 'room1 DuelResultPage';

    group('$label 弃权二次确认（生产缺省路径 onLeave == null）', () {
      testWidgets('点「返回首页」先弹确认，不直接离房', (tester) async {
        final h = await pumpHarness(tester, room3: room3);

        expect(tester.takeException(), isNull);
        expect(find.byKey(_panelKey), findsOneWidget);

        await openDialog(tester);

        // 只是弹窗，没断开、没导航。
        expect(h.service.disconnectCount, 0);
        expect(h.landedHome, isFalse, reason: '弹窗阶段不应导航');
        expect(find.byKey(_panelKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('取消：留在结算页，不断开、不导航', (tester) async {
        final h = await pumpHarness(tester, room3: room3);
        await openDialog(tester);

        await tester.tap(find.byKey(_cancelKey));
        await tester.pumpAndSettle();

        expect(find.text(_dialogTitle), findsNothing);
        expect(h.service.disconnectCount, 0);
        expect(h.landedHome, isFalse, reason: '取消后不应导航');
        expect(find.byKey(_panelKey), findsOneWidget);
        expect(find.byKey(_homeKey), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('确认：断开一次并落到 /', (tester) async {
        final h = await pumpHarness(tester, room3: room3);
        await openDialog(tester);

        await tester.tap(find.byKey(_confirmKey));
        await tester.pumpAndSettle();

        expect(h.service.disconnectCount, 1, reason: '确认后应走 leaveRoomAfterNotJoined → disconnect');
        expect(h.locations, isNotEmpty, reason: '确认后应发生导航');
        expect(h.locations.last, '/', reason: '应落到首页路由');
        expect(find.byKey(_homeKey), findsOneWidget);
        expect(find.byKey(_panelKey), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }
}

class _Harness {
  _Harness({required this.service, required this.locations});

  final _CountingDuelService service;

  /// 每次 GoRouter location 变化记录的新地址（用于断言「真的导航了」）。
  /// 监听器在首帧也会触发一次（初始 `/duel`），所以断言用 [landedHome]。
  final List<String> locations;

  /// 是否发生过「导航到 `/`」。
  bool get landedHome => locations.contains('/');
}

class _SideDeckingNotifier extends DuelRoomNotifier {
  _SideDeckingNotifier(this._state);

  final DuelRoomState _state;

  @override
  DuelRoomState build() => _state;
}

/// 只关心 `disconnect()` 次数：生产路径用它断开连接。
class _CountingDuelService implements IDuelService {
  int disconnectCount = 0;

  @override
  Stream<RoomStage> get onRoomStageChange => const Stream.empty();
  @override
  Stream<YgoStocMsg> get onServerMessage => const Stream.empty();
  @override
  Stream<YgoStocMsg> get onChatServerMessage => const Stream.empty();
  @override
  Stream<DuelPhase> get onDuelPhaseMessage => const Stream.empty();
  @override
  dl.ConnectionState get connectionState => dl.ConnectionConnected();
  @override
  Future<void> connect(Uri address) async {}
  @override
  Future<void> disconnect() async {
    disconnectCount++;
  }

  @override
  void setPlayerName(String name) {}
  @override
  void enterRoom(String password) {}
  @override
  void submitDeck(Uint8List mainDeck, Uint8List extraDeck, [
    Uint8List? sideDeck,
  ]) {}
  @override
  void ready() {}
  @override
  void unready() {}
  @override
  void startDuel() {}
  @override
  void kickPlayer(int pos) {}
  @override
  void becomeObserver() {}
  @override
  void becomeDuelist() {}
  @override
  void chooseHand(HandType hand) {}
  @override
  void chooseTurnOrder(bool goFirst) {}
  @override
  void playGameResponse(CtosGameMsgResponse response) {}
  @override
  void surrender() {}
  @override
  void confirmTime() {}
  @override
  void sendChat(String message) {}
}
