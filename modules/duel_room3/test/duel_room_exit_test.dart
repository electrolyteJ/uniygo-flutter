/// room3 退出确认弹窗的行为断言。
///
/// `a2ac6528` 给 `duel_room3/duel_room_exit.dart` 的 `backHomeDialog` 补了
/// `Navigator.of(ctx).pop()`：弹窗推在 root navigator 上，`backHome` 里的
/// `context.go('/')` 只改写 router 内部栈，不 pop 的话弹窗会**悬浮在首页之上**。
///
/// 此前这条修复只有「结构对等 room1 + 95/95 不回归」的间接保证，`test/` 下
/// `backHomeDialog|退出` 零命中。本文件补真正跑一遍：点「退出」→ 确认后
/// **弹窗必须消失**（`AlertDialog` findsNothing），且离房动作真的发生。
library;

import 'dart:typed_data';

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duel_room3/duel_room_exit.dart';
import 'package:duelink/duelink.dart' hide ConnectionState;
import 'package:duelink/duelink.dart' as dl show ConnectionConnected, ConnectionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _homeKey = ValueKey('fake-home');
const _openKey = ValueKey('open-exit-dialog');
const _dialogTitle = '确认退出？';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    YgoSoundService.enabled = false;
  });

  tearDown(() {
    YgoSoundService.enabled = true;
  });

  Future<_Harness> pumpHarness(
    WidgetTester tester, {
    bool alreadyLeaving = false,
  }) async {
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
          builder: (_, _) => const _ExitDialogHost(),
        ),
      ],
    );
    addTearDown(router.dispose);
    router.routerDelegate.addListener(() {
      locations.add(router.routerDelegate.currentConfiguration.uri.toString());
    });

    final container = ProviderContainer(
      overrides: [
        duelRoomProvider.overrideWith(_IdleDuelRoomNotifier.new),
        duelServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    // 模拟「已在离房流程中」：房间页 stage 监听已标记 leaving（幂等去重的
    // 常态），此时再点「退出」，backHome 会直接 return、不导航。
    if (alreadyLeaving) {
      container.read(duelRoomProvider.notifier).markLeaving();
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return _Harness(service: service, locations: locations);
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    expect(find.text(_dialogTitle), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('退出'), findsOneWidget);
  }

  testWidgets('点「取消」：弹窗关闭、不离房、不导航', (tester) async {
    final h = await pumpHarness(tester);
    await openDialog(tester);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text(_dialogTitle), findsNothing);
    expect(h.service.disconnectCount, 0);
    expect(h.landedHome, isFalse);
    expect(find.byKey(_openKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已在离房流程中（backHome 早退不导航）：弹窗仍必须被关掉，不能变死弹窗', (
    tester,
  ) async {
    final h = await pumpHarness(tester, alreadyLeaving: true);
    await openDialog(tester);

    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();

    // 这条是 `Navigator.of(ctx).pop()` 的**判别性**断言：`markLeaving()`
    // 已返回 false 时 backHome 直接 return、不发生任何导航，唯一能关闭弹窗的
    // 就是 pop 那一行。删掉 pop 这条必红（已用「临时回滚 pop」验证过）。
    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'backHome 早退不导航时，弹窗只能靠 pop 关闭；否则用户被死弹窗困住',
    );
    expect(
      h.landedHome,
      isFalse,
      reason: '已在离房流程中时 backHome 早退，不应再次导航',
    );
    expect(h.service.disconnectCount, 0, reason: '早退路径不重复断开');
    expect(find.byKey(_openKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点「退出」：弹窗必须真的关掉（不悬浮在首页上）+ 断连一次回首页', (
    tester,
  ) async {
    final h = await pumpHarness(tester);
    await openDialog(tester);

    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();

    // 核心断言：a2ac6528 的 pop。缺了它 AlertDialog 会留在首页之上。
    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: '确认后弹窗未关闭（root navigator 上的弹窗悬浮在首页）',
    );
    expect(find.text(_dialogTitle), findsNothing);

    // 离房动作真的发生：投降 + 断开 + 回首页。
    expect(h.service.surrendered, isTrue, reason: '退出应发投降（surrenderOnExit）');
    expect(h.service.disconnectCount, 1, reason: '退出应断开一次');
    expect(h.landedHome, isTrue, reason: '退出应导航到 /');
    expect(find.byKey(_homeKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Harness {
  _Harness({required this.service, required this.locations});

  final _CountingDuelService service;

  /// 监听器在首帧也会触发一次（初始 `/duel`），故用 [landedHome] 判定。
  final List<String> locations;

  bool get landedHome => locations.contains('/');
}

/// 只覆写 build：`markLeaving()` / `isLeaving` 走真实实现。
class _IdleDuelRoomNotifier extends DuelRoomNotifier {
  @override
  DuelRoomState build() => const DuelRoomState();
}

/// 带一个「打开退出确认」按钮的宿主页（提供 WidgetRef 与页面 context）。
class _ExitDialogHost extends ConsumerWidget {
  const _ExitDialogHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: _openKey,
          onPressed: () => backHomeDialog(
            context: context,
            ref: ref,
            title: _dialogTitle,
            content: '退出将判负，确定吗？',
          ),
          child: const Text('打开退出确认'),
        ),
      ),
    );
  }
}

class _CountingDuelService implements IDuelService {
  int disconnectCount = 0;
  bool surrendered = false;

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
  void surrender() {
    surrendered = true;
  }

  @override
  void confirmTime() {}
  @override
  void sendChat(String message) {}
}
