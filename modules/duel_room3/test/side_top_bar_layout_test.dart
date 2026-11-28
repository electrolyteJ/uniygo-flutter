/// 换备页顶条（[SideTopBar]）的布局回归测试。
///
/// 起因是线上真机报错：
///
/// ```text
/// A RenderFlex overflowed by 12 pixels on the right.
/// Row file:.../side_top_bar.dart:244:12
/// constraints: BoxConstraints(w=180.0, 0.0<=h<=51.0)
/// ```
///
/// 根因有两层：
/// 1. 右段写过 `SizedBox(width: 180)`——倒计时框 + 间距固定，右侧说明
///    文字按内容撑开就超了。
/// 2. 改成柔性后仍然溢出，因为比分格里的固定开销（两个 15px 数字 +
///    虚线 + 间距）在极窄格子里下不去。
///
/// 现在的策略是**按可用宽度分档降级**，任何宽度都不溢出：
///
/// | 宽度      | 比分 | 名字 | 计时 | 说明文字 |
/// |-----------|------|------|------|----------|
/// | < 360     | ✓    | —    | ✓    | —        |
/// | 360~479   | ✓    | —    | ✓    | —        |
/// | ≥ 390     | ✓    | ✓    | ✓    | —        |
/// | ≥ 480     | ✓    | ✓    | ✓    | ✓        |
///
/// 所以断言不能写「某段文字一定存在」，而要按宽度断言**降级是否合理**：
/// 比分与计时（不可替代的信息）永远在；名字与说明（陪衬）按空间出现。
library;

import 'package:duel_room3/side_decking/widgets/side_top_bar.dart';
import 'package:duel_room3/theme/cyber_side_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 把顶条塞进指定宽度里渲染。
Future<void> _pumpAt(WidgetTester tester, double width, Widget bar) async {
  tester.view.physicalSize = Size(width, 400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF05070F),
        body: Align(alignment: Alignment.topCenter, child: bar),
      ),
    ),
  );
  await tester.pump();
}

/// 带倒计时的完整顶条（真实换备页最复杂的那一态）。
Widget _bar({
  String timerHint = '换备计时',
  String timerSubHint = '本地计时 · 仅供参考',
  String? timerText = '05:32',
  int? myScore = 1,
  int? opponentScore = 0,
  String? myName = 'kaiba',
  String? opponentName = 'muto·游戏',
}) {
  return SideTopBar(
    title: '替换备牌',
    subtitle: 'MAIN 40 · EXTRA 15 · SIDE 15',
    accent: CyberSideTokens.acid,
    gameLabel: 'GAME 2 / 3',
    myName: myName,
    opponentName: opponentName,
    myScore: myScore,
    opponentScore: opponentScore,
    timerText: timerText,
    timerHint: timerHint,
    timerSubHint: timerSubHint,
  );
}

/// 断言渲染期没有溢出异常。
///
/// Flutter 把 RenderFlex 溢出报成 FlutterError，交给
/// `tester.takeException()` 取；非 null 即失败。
void _expectNoOverflow(WidgetTester tester) {
  final error = tester.takeException();
  expect(
    error,
    isNull,
    reason: '顶条不应溢出：${error?.toString().split('\n').first}',
  );
}

bool _has(WidgetTester tester, String text) =>
    find.text(text).evaluate().isNotEmpty;

void main() {
  // ── 核心约束：任何宽度都不许溢出 ──
  //
  // 这是这条 bug 的唯一硬性要求。宽度覆盖「小屏手机 → 折叠屏 → 平板」，
  // 另外 320 是 iPhone SE 一代的宽度，390 是 iPhone 12~15 的逻辑宽度。
  group('SideTopBar 不溢出', () {
    for (final width in <double>[320, 340, 360, 375, 390, 414, 430, 480, 540, 768, 1024]) {
      testWidgets('宽度 ${width.toInt()} 下无溢出', (tester) async {
        await _pumpAt(tester, width, _bar());
        _expectNoOverflow(tester);
      });
    }

    testWidgets('更长的提示文案不挤爆顶条', (tester) async {
      await _pumpAt(
        tester,
        390,
        _bar(timerHint: '换备剩余时间', timerSubHint: '本地计时 · 到点自动提交'),
      );
      _expectNoOverflow(tester);
    });

    testWidgets('超长玩家名不挤爆顶条', (tester) async {
      await _pumpAt(
        tester,
        390,
        _bar(myName: '一个非常非常长的玩家名字', opponentName: '另一个同样很长的名字'),
      );
      _expectNoOverflow(tester);
    });

    testWidgets('无比分（观战）时中段回落 vs，仍不溢出', (tester) async {
      await _pumpAt(tester, 390, _bar(myScore: null, opponentScore: null));
      _expectNoOverflow(tester);
    });

    testWidgets('无倒计时（已提交等待）时走 alert 分支，不溢出', (tester) async {
      await _pumpAt(
        tester,
        320,
        const SideTopBar(
          title: '等待对手',
          subtitle: 'SIDE 15',
          accent: CyberSideTokens.acid,
          gameLabel: 'GAME 2 / 3',
          myName: 'kaiba',
          opponentName: 'muto·游戏',
          myScore: 1,
          opponentScore: 0,
          alertLabel: '比分由本机统计',
          alertValue: 'GAME 3',
        ),
      );
      _expectNoOverflow(tester);
    });
  });

  // ── 降级策略：不许「为了不溢出」把关键信息全砍掉 ──
  //
  // 修复溢出时最容易犯的错是「全用 Flexible + ellipsis」，结果信息全被
  // 截成一串省略号——技术上不报错了，功能上等于没有。这里按档断言。
  group('SideTopBar 信息优先级', () {
    testWidgets('窄屏（320）保留比分与计时这两项硬信息', (tester) async {
      await _pumpAt(tester, 320, _bar());
      _expectNoOverflow(tester);
      // 比分和计时是玩家在换备阶段必须看到的，任何宽度都不能丢。
      expect(_has(tester, '1'), isTrue, reason: '我方比分必须可见');
      expect(_has(tester, '0'), isTrue, reason: '对手比分必须可见');
      expect(_has(tester, '05:32'), isTrue, reason: '倒计时必须可见');
    });

    testWidgets('常规手机（390）显示玩家名', (tester) async {
      await _pumpAt(tester, 390, _bar());
      _expectNoOverflow(tester);
      expect(_has(tester, 'kaiba'), isTrue, reason: '390 宽放得下名字');
    });

    testWidgets('宽屏（768）显示完整信息（含说明文字）', (tester) async {
      await _pumpAt(tester, 768, _bar());
      _expectNoOverflow(tester);
      expect(_has(tester, 'SIDE'), isTrue);
      expect(_has(tester, '替换备牌'), isTrue);
      expect(_has(tester, 'GAME 2 / 3'), isTrue);
      expect(_has(tester, 'kaiba'), isTrue);
      expect(_has(tester, 'muto·游戏'), isTrue);
      expect(_has(tester, '换备计时'), isTrue);
      expect(_has(tester, '05:32'), isTrue);
    });

    testWidgets('倒计时归零不崩', (tester) async {
      await _pumpAt(tester, 390, _bar(timerText: '00:00'));
      _expectNoOverflow(tester);
      expect(_has(tester, '00:00'), isTrue);
    });
  });
}
