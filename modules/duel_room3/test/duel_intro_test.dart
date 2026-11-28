import 'package:duel_room3/loading/duel_field_loading_page.dart';
import 'package:duel_room3/loading/models/duel_intro_timeline.dart';
import 'package:duel_room3/loading/widgets/intro_painters.dart';
import 'package:duel_room3/loading/widgets/intro_phases.dart';
import 'package:duel_room3/theme/cyber_intro_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _data = DuelIntroSceneData(
  myName: '混沌龙博士',
  opponentName: '剑斗士 K',
  iGoFirst: true,
);

/// 设计稿基准毫秒 → 实际毫秒（跟随 [DuelIntroTimeline.speed]）。
///
/// 断言一律走这个换算，调 speed 时无需改动测试。
int _ms(int baseMs) => (baseMs * DuelIntroTimeline.speed).round();

void main() {
  group('DuelIntroTimeline 相位边界', () {
    test('每个相位起点解析到自身', () {
      for (final span in DuelIntroTimeline.spans) {
        expect(
          DuelIntroTimeline.phaseAt(span.startMs),
          span.phase,
          reason: '${span.phase} 起始 ${span.startMs}ms 应解析到自身',
        );
      }
    });

    test('相位终点归下一相位（左闭右开）', () {
      // 设计稿 07：01 tunnel 0–900 / 02 field 900–1900 / 03 vs 1900–2700。
      expect(DuelIntroTimeline.phaseAt(_ms(899)), DuelIntroPhase.tunnel);
      expect(DuelIntroTimeline.phaseAt(_ms(900)), DuelIntroPhase.field);
      expect(DuelIntroTimeline.phaseAt(_ms(1899)), DuelIntroPhase.field);
      expect(DuelIntroTimeline.phaseAt(_ms(1900)), DuelIntroPhase.vs);
      expect(DuelIntroTimeline.phaseAt(_ms(2699)), DuelIntroPhase.vs);
    });

    test('相位首尾相接无空洞无重叠', () {
      for (var i = 1; i < DuelIntroTimeline.spans.length; i++) {
        expect(
          DuelIntroTimeline.spans[i].startMs,
          DuelIntroTimeline.spans[i - 1].endMs,
          reason: '第 $i 段应紧接上一段',
        );
      }
      // 设计稿：2700ms 演完即交接，不存在额外的兜底窗口。
      expect(DuelIntroTimeline.totalMs, _ms(2700));
    });

    test('调速倍率是有限正数，且时间轴确实按它换算', () {
      expect(DuelIntroTimeline.speed, greaterThan(0));
      expect(DuelIntroTimeline.speed.isFinite, isTrue);

      // 相位窗口必须是「基准 × speed」，不能有人绕过 speed 手写毫秒。
      final baselines = {
        DuelIntroPhase.tunnel: 900,
        DuelIntroPhase.field: 1900,
        DuelIntroPhase.vs: 2700,
      };
      for (final entry in baselines.entries) {
        expect(
          DuelIntroTimeline.spanOf(entry.key).endMs,
          _ms(entry.value),
          reason: '${entry.key} 的终点应由 speed 换算得出',
        );
      }
    });

    test('入场动画只含三个相位，先后攻与抽卡不单独演', () {
      final names = DuelIntroTimeline.spans.map((s) => s.phase.name).toList();
      expect(names, ['tunnel', 'field', 'vs']);
      // 先后攻与抽卡已移交对局页，不在这里出现。
      expect(names, isNot(contains('reveal')));
      expect(names, isNot(contains('draw')));
      expect(names, isNot(contains('confirm')));
      expect(names, isNot(contains('handoff')));
    });

    test('负时间归首相位，超时归末相位', () {
      expect(DuelIntroTimeline.phaseAt(-100), DuelIntroPhase.tunnel);
      expect(DuelIntroTimeline.phaseAt(999999), DuelIntroPhase.vs);
    });

    test('isDone 以总时长为界', () {
      expect(DuelIntroTimeline.isDone(_ms(2699)), isFalse);
      expect(DuelIntroTimeline.isDone(_ms(2700)), isTrue);
      expect(DuelIntroTimeline.isDone(_ms(9999)), isTrue);
    });

    test('相位内进度线性且收敛到 0/1', () {
      final span = DuelIntroTimeline.spanOf(DuelIntroPhase.tunnel);
      final end = span.endMs;
      expect(span.progressAt(0), 0);
      expect(span.progressAt(end ~/ 2), closeTo(0.5, 0.01));
      expect(span.progressAt(end), 1);
      // 越界钳位。
      expect(span.progressAt(-50), 0);
      expect(span.progressAt(end * 2), 1);
    });

    test('ordinalOf 从 1 起编号，共三段', () {
      expect(DuelIntroTimeline.ordinalOf(DuelIntroPhase.tunnel), 1);
      expect(DuelIntroTimeline.ordinalOf(DuelIntroPhase.field), 2);
      expect(DuelIntroTimeline.ordinalOf(DuelIntroPhase.vs), 3);
      expect(DuelIntroPhase.values.length, 3);
    });

    test('进度区间首尾相接且只增不减', () {
      // 页面级进度条要在跨相位时保持连续：0→64 / 64→92 / 92→99。
      final ranges = DuelIntroPhase.values.map(progressRangeOf).toList();
      expect(ranges.first.$1, 0);
      for (var i = 1; i < ranges.length; i++) {
        expect(
          ranges[i].$1,
          ranges[i - 1].$2,
          reason: '第 $i 段起点应等于上一段终点（进度条不可回退）',
        );
      }
      expect(ranges.last.$2, closeTo(0.99, 1e-9));
    });
  });

  group('DuelFieldLoadingPage 播放与跳过', () {
    testWidgets('默认允许跳过：设计稿要求全程可跳过', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DuelFieldLoadingPage(data: _data, onFinished: () => finished++),
        ),
      );
      await tester.pump();

      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(finished, 1, reason: '默认 skippable = true，点击应立刻跳过');
    });

    testWidgets('演出播完立即回调', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DuelFieldLoadingPage(data: _data, onFinished: () => finished++),
        ),
      );

      // 首帧：tunnel 相位。
      expect(find.text('LINK'), findsWidgets);
      expect(finished, 0);

      await tester.pump(Duration(milliseconds: _ms(2700) + 50));
      expect(finished, 1, reason: '基准 2700ms 播完即交接');
    });

    testWidgets('skippable=false 时点击不打断演出', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DuelFieldLoadingPage(
            data: _data,
            skippable: false,
            onFinished: () => finished++,
          ),
        ),
      );
      await tester.pump();

      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(finished, 0, reason: '关掉 skippable 后点击不应跳过');

      await tester.pump(const Duration(milliseconds: 1000));
      expect(finished, 0);
    });

    testWidgets('跳过只回调一次', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DuelFieldLoadingPage(data: _data, onFinished: () => finished++),
        ),
      );
      await tester.pump();

      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(finished, 1);

      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(finished, 1, reason: '重复点击/自然播完都不应重复回调');
    });

    testWidgets('autoPlay=false 时停在起始相位', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DuelFieldLoadingPage(
            data: _data,
            autoPlay: false,
            onFinished: () => finished++,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 7));
      expect(finished, 0);
      expect(find.text('LINK'), findsWidgets);
    });
  });

  group('页面级常驻框架', () {
    /// 整个页面里百分比标签的个数 —— 必须恒为 1（只有一份进度条）。
    int barCount(WidgetTester tester) => find
        .byWidgetPredicate((w) => w is MonoLabel && w.text.endsWith(' %'))
        .evaluate()
        .length;

    testWidgets('进度条始终只有一份', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DuelFieldLoadingPage(data: _data, onFinished: () {}),
        ),
      );
      expect(barCount(tester), 1, reason: 'tunnel 相位只有一条进度条');
      expect(find.byType(IntroProgressBar), findsOneWidget);

      // 逐相位推进，每个相位都仍只有一份。
      for (final at in [_ms(1000), _ms(2000)]) {
        await tester.pump(Duration(milliseconds: at));
        expect(find.byType(IntroProgressBar), findsOneWidget);
        expect(barCount(tester), 1);
      }
    });

    testWidgets('百分比跨相位单调不减（进度条不回退）', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DuelFieldLoadingPage(data: _data, onFinished: () => finished++),
        ),
      );

      String percentText() {
        final label = tester
            .widgetList<MonoLabel>(find.byType(MonoLabel))
            .firstWhere((w) => w.text.endsWith(' %'));
        return label.text;
      }

      int percentOf(String s) => int.parse(s.replaceAll('%', '').trim());

      final seen = <int>[percentOf(percentText())];
      // 每 300ms 采一次，跨过 tunnel/field/vs 三个相位。
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
        seen.add(percentOf(percentText()));
      }

      for (var i = 1; i < seen.length; i++) {
        expect(
          seen[i],
          greaterThanOrEqualTo(seen[i - 1]),
          reason: '进度不应回退：$seen',
        );
      }
      expect(seen.last, greaterThan(seen.first), reason: '进度确实在前进');
    });

    testWidgets('进度条填充色恒定青色，不随相位换色', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DuelFieldLoadingPage(data: _data, onFinished: () {}),
        ),
      );
      final colors = <Color>{};
      for (var i = 0; i < 3; i++) {
        colors.add(
          tester.widget<IntroProgressBar>(find.byType(IntroProgressBar)).color,
        );
        await tester.pump(Duration(milliseconds: _ms(1000)));
      }
      expect(colors, {CyberIntroTokens.cyan}, reason: '设计稿四帧进度条颜色一致');
    });
  });

  group('各相位冒烟', () {
    Future<void> pumpPhase(
      WidgetTester tester,
      DuelIntroPhase phase,
      double t, {
      DuelIntroSceneData data = _data,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildIntroPhase(phase: phase, t: t, data: data),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('tunnel 显示 LINK 与传输读数', (tester) async {
      await pumpPhase(tester, DuelIntroPhase.tunnel, 1);
      expect(find.text('LINK'), findsWidgets);
      expect(
        find.text('ARENA STREAM  1024 KB/s   //   ZONE 07'),
        findsOneWidget,
      );
    });

    testWidgets('field 显示 DUEL FIELD 与 SEAT 标识', (tester) async {
      await pumpPhase(tester, DuelIntroPhase.field, 1);
      expect(find.text('DUEL FIELD'), findsWidgets);
      expect(find.text('YOU  ▸  SEAT A'), findsOneWidget);
      expect(find.text('SEAT B  ◂  RIVAL'), findsOneWidget);
    });

    testWidgets('观战者 field 相位不出现 YOU / RIVAL', (tester) async {
      const spectator = DuelIntroSceneData(
        myName: '混沌龙博士',
        opponentName: '剑斗士 K',
        iGoFirst: true,
        isSpectator: true,
      );
      await pumpPhase(tester, DuelIntroPhase.field, 1, data: spectator);
      expect(find.text('DUEL FIELD'), findsWidgets);
      expect(find.text('SEAT A'), findsOneWidget);
      expect(find.text('SEAT B'), findsOneWidget);
      // 旧实现把这两个标签写死，观战者会把引擎玩家 1 误读成自己。
      expect(find.text('YOU  ▸  SEAT A'), findsNothing);
      expect(find.text('SEAT B  ◂  RIVAL'), findsNothing);
    });

    testWidgets('vs 显示 VS、DUEL START 与双方先后攻', (tester) async {
      await pumpPhase(tester, DuelIntroPhase.vs, 1);
      expect(find.text('VS'), findsWidgets);
      expect(find.text('DUEL START'), findsOneWidget);
      expect(find.text('先攻  ·  TURN 01'), findsOneWidget);
      expect(find.text('TURN 01  ·  后攻'), findsOneWidget);
      expect(find.text('决斗开始  ·  双方 LP 8000'), findsOneWidget);
    });

    testWidgets('相位画面不再自带进度条（进度条归页面）', (tester) async {
      for (final phase in DuelIntroPhase.values) {
        await pumpPhase(tester, phase, 0.5);
        expect(
          find.byType(IntroProgressBar),
          findsNothing,
          reason: '${phase.name} 不应各画一份进度条',
        );
      }
    });
  });

  group('DuelIntroSceneData 席位标签', () {
    const spectator = DuelIntroSceneData(
      myName: '混沌龙博士',
      opponentName: '剑斗士 K',
      iGoFirst: true,
      isSpectator: true,
    );

    test('决斗者保留 YOU / RIVAL', () {
      expect(_data.leftSeatTag, 'YOU  ▸  SEAT A');
      expect(_data.rightSeatTag, 'SEAT B  ◂  RIVAL');
    });

    test('观战者退化为纯席位号', () {
      expect(spectator.leftSeatTag, 'SEAT A');
      expect(spectator.rightSeatTag, 'SEAT B');
      expect(spectator.leftSeatTag, isNot(contains('YOU')));
      expect(spectator.rightSeatTag, isNot(contains('RIVAL')));
    });
  });
}
