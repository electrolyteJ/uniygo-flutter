/// 方案 2 —— AI 对决房间流程的 UI 集成测试（真实 App，真实引擎）。
///
/// 流程：连接 → 进房 → 准备 → 猜拳（人类石头胜 AI 剪刀）
/// → 选先攻 → 进入决斗场（RoomInDuel）。
///
/// 运行方式：
/// - macOS:  `flutter test integration_test/ai_room_flow_test.dart -d macos`
/// - Web:    `flutter drive --driver=test_driver/integration_test.dart \
///              --target=integration_test/ai_room_flow_test.dart -d web-server`
///
/// 确定性说明：[AiDuelService.fixedAiHandChoice] 固定 AI 出剪刀，
/// 否则 AI 伪随机出拳，赢的时候不下发 STOC_SELECT_TP，「选先攻」分支
/// 无法稳定复现。测试与 App 同进程运行，直接设置单例即可生效。
library;

import 'package:duelink/duelink.dart' show HandType;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uniygopro/main.dart' as app;
import 'package:duel_room1/service_singleton.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI 房间流程: 连接→猜拳→选先攻→进入决斗', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    _failIfFlutterException(tester, 'after app startup');

    // AI 固定剪刀，人类出石头必胜 → 必然走到「选先攻」分支。
    // 注意必须在 app.main() 之后设置：服务注册发生在 main() 里。
    ServiceSingleton.instance.aiDuelService.fixedAiHandChoice =
        HandType.scissors.value;
    addTearDown(
      () => ServiceSingleton.instance.aiDuelService.fixedAiHandChoice = null,
    );

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

    // ── 3. 猜拳：出石头 ──
    await _pumpUntilStage(tester, 'RoomSelectingHand');
    await tester.tap(find.byKey(const ValueKey('hand-select-rock')));
    await tester.pump();

    // ── 4. 人类胜 → 选先攻 ──
    await _pumpUntilStage(tester, 'RoomSelectingTurn');
    await tester.tap(find.byKey(const ValueKey('tp-select-first')));
    await tester.pump();

    // ── 5. 进入决斗场 ──
    await _pumpUntilStage(
      tester,
      'RoomInDuel',
      timeout: const Duration(minutes: 1),
    );
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
