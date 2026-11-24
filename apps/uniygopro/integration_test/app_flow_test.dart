/// 首页各建房入口的完整导航流程（真实 App 启动）。
///
/// 流程：开屏分流 →（未登录时）游客进入大厅 → 依次打开
/// 竞技匹配 / 娱乐匹配 / 自由房间 / 残局房 / AI 对决 面板 →
/// 卡组编辑器入口 → 「我的」分区探活。
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

  testWidgets('开屏 → 大厅 → 各建房面板 → 卡组编辑器入口', (tester) async {
    YgoSoundService.enabled = false;
    app.main();
    // 启动链路本身是异步的（SharedPreferences / DuelRoomRendererPreference
    // .restore()），首帧到达前 pumpAndSettle 会立刻返回，因此按条件等首屏。
    await _enterLobby(tester);
    _failIfFlutterException(tester, 'after entering lobby');

    // 大厅「决斗」分区：AI 入口 key 是 spec 必须保留项。
    expect(find.byKey(_aiRoomKey), findsOneWidget);

    // ── 竞技匹配 sheet（游客态用户名标签带后缀，故用 textContaining）──
    await _tapAfterScroll(tester, find.text('竞技匹配'));
    expect(find.text('开始匹配'), findsOneWidget);
    expect(find.textContaining('用户名'), findsOneWidget);
    _failIfFlutterException(tester, 'in 竞技匹配 sheet');
    // 关闭弹层（点击遮罩）
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── 娱乐匹配 sheet ──
    await _tapAfterScroll(tester, find.text('娱乐匹配'));
    expect(find.text('开始匹配'), findsOneWidget);
    _failIfFlutterException(tester, 'in 娱乐匹配 sheet');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── 自由房间 sheet（默认 Koishi 只能加入）──
    await _tapAfterScroll(tester, find.text('自由房间'));
    expect(find.text('加入房间'), findsOneWidget);
    expect(find.text('对战环境'), findsOneWidget);
    _failIfFlutterException(tester, 'in 自由房间 sheet');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── 残局房 sheet（移动横屏下在「对战模式」网格折叠线以下）──
    await _tapAfterScroll(tester, find.text('残局房'));
    expect(find.text('搜索残局…'), findsOneWidget);
    _failIfFlutterException(tester, 'in 残局房 sheet');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── AI 对决 sheet → 切到 233 → 校验 AI 密码预览 ──
    // 预览文案是「AI 密码: <token>」（ai_room_sheet._roomStringPreview），
    // 与自由房「最终房间串」不是同一处，别按「房间串」断言。
    await _tapAfterScroll(tester, find.byKey(_aiRoomKey));
    expect(find.text('开始人机对战'), findsOneWidget);
    _failIfFlutterException(tester, 'in AI sheet (local)');
    await tester.tap(find.text('233 服 AI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI 密码:'), findsOneWidget);
    _failIfFlutterException(tester, 'in AI sheet (233)');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // ── 卡组编辑器入口 ──
    // 该 IconButton 挂在「决斗」分区的玩家信息条（_PlayerBar）上，
    // 只有决斗分区可见；切到其它分区会被懒构建替换成 SizedBox.shrink。
    // 前面的 ensureVisible 会把列表滚下去，信息条被懒列表回收，需先滚回顶部。
    await _tapNavIcon(tester);
    expect(find.text('卡组编辑器'), findsOneWidget);
    _failIfFlutterException(tester, 'after opening deck editor');

    // ── 返回大厅，探活「我的」分区（四级导航的另一端）──
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await _openTab(tester, '我的');
    // 「全局设置」是「我的」分区的常驻项（与登录态无关）。
    expect(find.text('全局设置'), findsOneWidget);
    _failIfFlutterException(tester, 'after visiting profile tab');
  });
}

/// 从开屏进入大厅：已登录直接在大厅，未登录点「游客进入」。
Future<void> _enterLobby(WidgetTester tester) async {
  // 1) 等首屏出现（开屏 / 登录 / 大厅任一）。
  await _pumpUntil(
    tester,
    () => _onLobby() || _guestEntry().evaluate().isNotEmpty,
    reason: '启动后既没进大厅也没出现登录页',
  );
  // 2) 未登录 → 游客进入（开屏 1200ms 动画结束后才分流，条件等待已覆盖）。
  if (_onLobby()) return;
  await tester.tap(_guestEntry());
  await tester.pumpAndSettle();
  await _pumpUntil(tester, _onLobby, reason: '点「游客进入」后未回到大厅');
}

bool _onLobby() => find.byKey(_aiRoomKey).evaluate().isNotEmpty;

Finder _guestEntry() => find.byKey(_guestEntryKey);

/// 切换大厅一级分区（compact 为底部 Tab，regular/wide 为左侧 Rail）。
Future<void> _openTab(WidgetTester tester, String label) async {
  final tab = find.text(label);
  expect(tab, findsOneWidget, reason: '未找到一级入口「$label」');
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

/// 按条件等待真实时间：集成测试用的是 LiveBinding，不能靠 `pump(Duration)`
/// 推进时钟，必须「泵一帧 + 真实等待」交替，直到条件成立或超时。
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

void _failIfFlutterException(WidgetTester tester, String stage) {
  final exception = tester.takeException();
  if (exception != null) {
    fail('Unexpected Flutter exception $stage: $exception');
  }
}

/// 先滚到可见再点：移动横屏（逻辑约 780×360）下「对战模式」网格的第 5/6 张卡
/// （残局房 / 怪兽动画）在首屏折叠线以下，直接 tap 命中不到。
Future<void> _tapAfterScroll(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 滚回列表顶部的玩家信息条，点其中的卡组编辑器入口。
Future<void> _tapNavIcon(WidgetTester tester) async {
  final icon = find.byIcon(Icons.card_membership);
  await tester.dragUntilVisible(
    icon,
    find.byType(ListView).first,
    const Offset(0, 200),
  );
  await tester.pumpAndSettle();
  expect(icon, findsOneWidget);
  await tester.tap(icon);
  await tester.pumpAndSettle();
}
