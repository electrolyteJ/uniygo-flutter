/// 方案 2 —— AI 对决房间流程的 UI 集成测试（真实 App，真实引擎）。
///
/// 流程：连接 → 进房 → 准备 → 猜拳 → 进入决斗场（RoomInDuel）。
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI 房间流程: 连接→猜拳→选先攻→进入决斗', (tester) async {
    // 禁用音频：audioplayers 的 FramePositionUpdater 会在 teardown 时
    // 留下 transient callbacks，导致测试框架报「animation still running」。
    YgoSoundService.enabled = false;
    app.main();
    await tester.pumpAndSettle();
    _failIfFlutterException(tester, 'after app startup');

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

    final status = _readStatusText(tester);
    // Printed so flutter drive logs expose the last observed runtime state.
    // ignore: avoid_print
    print('FINAL_STATUS:$status');
    expect(status, contains('connectionState=connected'));
    expect(status, contains('stage=RoomInDuel'));
    expect(status, contains('errorMessage=<none>'));
  });
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
