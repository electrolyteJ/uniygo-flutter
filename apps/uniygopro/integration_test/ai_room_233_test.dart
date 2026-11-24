/// 233 服 AI 房间流程集成测试（真实外网服务器 s1.ygo233.com:233）。
///
/// 流程：开屏分流 → 游客进入大厅 → 连接 → 进房 → 准备 → 猜拳 →
/// （胜则选先攻）→ 进入决斗场。
///
/// 入口契约：`config/route.dart` 的 `initialLocation` 是 `/splash`，
/// 无登录态时开屏 1200ms 动画后分流到 `/login`。因此不能
/// `pumpAndSettle()` 后直接点大厅控件，必须先过开屏、点
/// `login-guest-entry`（与 spec 首启链路一致）。
///
/// 与本地 AI 测试不同，233 服务器端 AI 出拳是伪随机的、无法通过
/// [AiDuelService.fixedAiHandChoice] 固定，因此本测试对猜拳胜负
/// 不做强断言：无论输赢都应在合理时间内进入 RoomInDuel。
///
/// 运行方式（需联网，且当前环境能访问 ygo233.com）：
/// - macOS: `flutter test integration_test/ai_room_233_test.dart -d macos`
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uniygopro/main.dart' as app;
import 'package:biz/ygo_sound_service.dart';

const _aiRoomKey = ValueKey('home-server-ai-room');
const _guestEntryKey = ValueKey('login-guest-entry');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('233 服 AI: 连接→准备→猜拳→进入决斗', (tester) async {
    // 禁用音频，避免 audioplayers 的 FramePositionUpdater 在 teardown
    // 留下 transient callbacks。
    YgoSoundService.enabled = false;
    app.main();
    // 启动链路异步（SharedPreferences / 渲染器偏好 restore），首帧到达前
    // pumpAndSettle 会立刻返回，因此按条件等首屏。
    await _enterLobby(tester);
    _failIfFlutterException(tester, 'after entering lobby');

    // ── 1. 进入 AI 房并切换到「233 服 AI」──
    await tester.tap(find.byKey(const ValueKey('home-server-ai-room')));
    await tester.pumpAndSettle();

    // SegmentedButton 里选择「233 服 AI」。
    final server233Segment = find.text('233 服 AI');
    await tester.ensureVisible(server233Segment);
    await tester.tap(server233Segment);
    await tester.pumpAndSettle();
    _failIfFlutterException(tester, 'after switching to 233 AI');

    // 233 分支才会显示房间串预览。
    expect(find.textContaining('房间串:'), findsOneWidget);

    // ── 2. 连接 233 服 AI ──
    final startButton = find.byKey(const ValueKey('ai-room-start-server233'));
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    _failIfFlutterException(tester, 'after starting 233 AI room');

    expect(find.byKey(const ValueKey('duel-room-page')), findsOneWidget);

    // ── 3. 等待进大厅 → 发送 /ai 唤醒 233 服务器 AI ──
    await _pumpUntilStage(tester, 'RoomInLobby');
    await _sendChat(tester, '/ai');
    // 给服务器一点时间生成 AI 并加入房间。
    await tester.pump(const Duration(seconds: 2));
    _failIfFlutterException(tester, 'after summoning 233 AI');

    // ── 4. 准备 ──
    await tester.tap(find.byKey(const ValueKey('waiting-room-ready')));
    await tester.pump();

    // ── 5. 猜拳/选先攻/进入决斗（对胜负不做假设）──
    await _driveUntilDuel(tester);

    final status = _readStatusText(tester);
    // ignore: avoid_print
    print('FINAL_STATUS:$status');
    expect(status, contains('connectionState=connected'));
    expect(status, contains('stage=RoomInDuel'));
    expect(status, contains('errorMessage=<none>'));
  });
}

/// 从开屏进入大厅：已登录直接在大厅，未登录点「游客进入」。
///
/// LiveBinding 下不能靠 `pump(Duration)` 推进时钟，只能「泵一帧 + 真实
/// 等待」交替；开屏 1200ms 动画期间条件不成立，靠超时窗口自然覆盖。
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

/// 在等待房聊天输入框发送消息（用于 `/ai` 唤醒 233 服务器 AI）。
Future<void> _sendChat(WidgetTester tester, String text) async {
  final field = find.byType(TextField).first;
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.tap(find.byIcon(Icons.send));
  await tester.pump();
}

/// 驱动到 RoomInDuel：遇猜拳阶段出石头，遇选先攻阶段选先攻；
/// 服务器 AI 出拳随机，因此胜负与选先攻分支不强制。
Future<void> _driveUntilDuel(
  WidgetTester tester, {
  Duration timeout = const Duration(minutes: 3),
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
      fail('233 AI room failed to connect. Last status: $status');
    }
    if (!status.contains('errorMessage=<none>')) {
      fail('233 AI room reported an application error. Last status: $status');
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
      fail('233 AI room failed to connect. Last status: $status');
    }
    if (!status.contains('errorMessage=<none>')) {
      fail('233 AI room reported an application error. Last status: $status');
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
