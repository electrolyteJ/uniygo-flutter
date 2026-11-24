/// 方案 2 —— AI 对决房间流程的 UI 集成测试（真实 App，真实引擎）。
///
/// 流程：开屏分流 → 游客进入大厅 → 连接 → 进房 → 准备 → 猜拳 →
/// 进入决斗场（RoomInDuel）。
///
/// 入口契约：`config/route.dart` 的 `initialLocation` 是 `/splash`，
/// `splash_page` 在 1200ms 动画后按登录态分流（无登录态 → `/login`）。
/// 因此不能 `pumpAndSettle()` 后直接点大厅控件，必须先过开屏、点
/// `login-guest-entry`（与 spec 首启链路一致），否则第一处断言就红。
///
/// 运行方式：
/// - macOS:  `flutter test integration_test/ai_room_flow_test.dart -d macos`
/// - Web:    `flutter drive --driver=test_driver/integration_test.dart \
///              --target=integration_test/ai_room_flow_test.dart -d web-server`
///
/// 说明：本地 AI 出拳伪随机（[AiDuelService.fixedAiHandChoice] 挂在
/// ServiceSingleton 单例上，与决斗房经 Riverpod provider 创建的
/// AiDuelService 不是同一实例，无法稳定生效），因此本测试对猜拳胜负
/// 不做假设：无论输赢都在合理时间内进入 RoomInDuel。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uniygopro/main.dart' as app;
import 'package:biz/ygo_sound_service.dart';
import 'package:cardlive/cardlive.dart' show Summon3DOverlay;

const _aiRoomKey = ValueKey('home-server-ai-room');
const _guestEntryKey = ValueKey('login-guest-entry');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI 房间流程: 连接→猜拳→选先攻→进入决斗', (tester) async {
    // 禁用音频：audioplayers 的 FramePositionUpdater 会在 teardown 时
    // 留下 transient callbacks，导致测试框架报「animation still running」。
    YgoSoundService.enabled = false;
    app.main();
    // 启动链路本身是异步的（SharedPreferences / DuelRoomRendererPreference
    // .restore()），首帧到达前 pumpAndSettle 会立刻返回，因此按条件等首屏。
    await _enterLobby(tester);
    _failIfFlutterException(tester, 'after entering lobby');

    // ── 1. 进入本地 AI 房（触发连接 + 进房）──
    await tester.tap(find.byKey(const ValueKey('home-server-ai-room')));
    await tester.pumpAndSettle();

    final startButton = find.byKey(const ValueKey('ai-room-start-local'));
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    _failIfFlutterException(tester, 'after starting local AI room');

    expect(find.byKey(const ValueKey('duel-room-page')), findsOneWidget);

    // ── 2. 等待进大厅 → 准备（自动提交当前选中卡组）──
    await _pumpUntilStage(tester, 'RoomInLobby');
    await tester.tap(find.byKey(const ValueKey('waiting-room-ready')));
    await tester.pump();

    // ── 3. 猜拳/选先攻/进入决斗（对胜负不做假设）──
    await _driveUntilDuel(tester);
    _failIfFlutterException(tester, 'after entering duel');

    // ── 4. 电子龙 3D 召唤演出（flame_3d / Flutter GPU 管线冒烟）──
    // debug 按钮触发完整 3D overlay：初始化 Flutter GPU → 加载程序化
    // 机械龙 → 播放 1.55s 演出 → 自动移除。任何 GPU/渲染异常都会经
    // takeException 暴露。
    final summonButton = find.byKey(const ValueKey('debug-summon-cyber-dragon'));
    expect(summonButton, findsOneWidget);
    await tester.tap(summonButton);
    await tester.pump();
    expect(find.byType(Summon3DOverlay), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    _failIfFlutterException(tester, 'during cyber dragon summon 3D');
    // 演出结束 overlay 应已自动移除（1.55s < 2.4s 泵送窗口）。
    expect(find.byType(Summon3DOverlay), findsNothing);

    final status = _readStatusText(tester);
    // Printed so flutter drive logs expose the last observed runtime state.
    // ignore: avoid_print
    print('FINAL_STATUS:$status');
    expect(status, contains('connectionState=connected'));
    expect(status, contains('stage=RoomInDuel'));
    expect(status, contains('errorMessage=<none>'));
  });
}

/// 从开屏进入大厅：已登录直接在大厅，未登录点「游客进入」。
///
/// 开屏 `SplashPage` 有 1200ms 有限次动画，`pumpAndSettle()` 在真实
/// 首帧到达前会立刻返回，所以按条件等（LiveBinding 下不能靠
/// `pump(Duration)` 推进时钟，只能「泵一帧 + 真实等待」交替）。
Future<void> _enterLobby(WidgetTester tester) async {
  await _pumpUntil(
    tester,
    () => _onLobby() || _guestEntry().evaluate().isNotEmpty,
    reason: '启动后既没进大厅也没出现登录页',
  );
  if (_onLobby()) return;
  await tester.tap(_guestEntry());
  await tester.pumpAndSettle();
  await _pumpUntil(tester, _onLobby, reason: '点「游客进入」后未回到大厅');
}

bool _onLobby() => find.byKey(_aiRoomKey).evaluate().isNotEmpty;

Finder _guestEntry() => find.byKey(_guestEntryKey);

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
  required String reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('等待超时（${timeout.inSeconds}s）：$reason');
}

/// 驱动到 RoomInDuel：遇猜拳阶段出石头，遇选先攻阶段选先攻；
/// 本地 AI 出拳随机，因此胜负与选先攻分支不强制。
Future<void> _driveUntilDuel(
  WidgetTester tester, {
  Duration timeout = const Duration(minutes: 2),
  Duration step = const Duration(milliseconds: 250),
}) async {
  var handSent = false;
  var turnSent = false;
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    final exception = tester.takeException();
    if (exception != null) {
      fail('Unexpected Flutter exception while driving to duel: $exception');
    }
    final status = _readStatusText(tester);
    if (status.contains('connectionState=error')) {
      fail('AI room failed to connect. Last status: $status');
    }
    if (!status.contains('errorMessage=<none>')) {
      fail('AI room reported an application error. Last status: $status');
    }
    if (status.contains('stage=RoomInDuel')) {
      return;
    }
    if (!handSent && status.contains('stage=RoomSelectingHand')) {
      await tester.tap(find.byKey(const ValueKey('hand-select-rock')));
      await tester.pump();
      handSent = true;
      continue;
    }
    if (!turnSent && status.contains('stage=RoomSelectingTurn')) {
      await tester.tap(find.byKey(const ValueKey('tp-select-first')));
      await tester.pump();
      turnSent = true;
    }
  }
  fail(
    'Timed out waiting for RoomInDuel. Last status: ${_readStatusText(tester)}',
  );
}

Future<void> _pumpUntilStage(
  WidgetTester tester,
  String stage, {
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    final exception = tester.takeException();
    if (exception != null) {
      fail('Unexpected Flutter exception while waiting for $stage: $exception');
    }
    final status = _readStatusText(tester);
    if (status.contains('connectionState=error')) {
      fail('AI room failed to connect. Last status: $status');
    }
    if (!status.contains('errorMessage=<none>')) {
      fail('AI room reported an application error. Last status: $status');
    }
    if (status.contains('stage=$stage')) {
      return;
    }
  }
  fail(
    'Timed out waiting for stage $stage. Last status: ${_readStatusText(tester)}',
  );
}

String _readStatusText(WidgetTester tester) {
  final statusFinder = find.byKey(const ValueKey('duel-room-debug-status'));
  if (statusFinder.evaluate().isEmpty) {
    return '<missing>';
  }
  final debugText = tester.widget<Text>(statusFinder);
  return debugText.data ?? '';
}

void _failIfFlutterException(WidgetTester tester, String stage) {
  final exception = tester.takeException();
  if (exception != null) {
    fail('Unexpected Flutter exception $stage: $exception');
  }
}
