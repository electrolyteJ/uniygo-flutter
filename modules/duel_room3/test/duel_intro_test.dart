import 'package:duel_room3/loading/intro/duel_intro_overlay.dart';
import 'package:duel_room3/loading/intro/duel_intro_timeline.dart';
import 'package:duel_room3/loading/intro/intro_phases.dart';
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
  });

  group('DuelIntroOverlay 播放与跳过', () {
    testWidgets('默认允许跳过：设计稿要求全程可跳过', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DuelIntroOverlay(data: _data, onFinished: () => finished++),
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
          home: DuelIntroOverlay(data: _data, onFinished: () => finished++),
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
          home: DuelIntroOverlay(
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
          home: DuelIntroOverlay(
            data: _data,
            skippable: true,
            onFinished: () => finished++,
          ),
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
          home: DuelIntroOverlay(
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

  group('各相位冒烟', () {
    Future<void> pumpPhase(
      WidgetTester tester,
      DuelIntroPhase phase,
      double t,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildIntroPhase(phase: phase, t: t, data: _data),
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

    testWidgets('vs 显示 VS、DUEL START 与双方先后攻', (tester) async {
      await pumpPhase(tester, DuelIntroPhase.vs, 1);
      expect(find.text('VS'), findsWidgets);
      expect(find.text('DUEL START'), findsOneWidget);
      expect(find.text('先攻  ·  TURN 01'), findsOneWidget);
      expect(find.text('TURN 01  ·  后攻'), findsOneWidget);
      expect(find.text('决斗开始  ·  双方 LP 8000'), findsOneWidget);
    });

    testWidgets('每个相位底栏都带状态文案与相位角标', (tester) async {
      const stages = {
        DuelIntroPhase.tunnel: '正在载入  ·  场地数据',
        DuelIntroPhase.field: '正在载入  ·  场地成形',
        DuelIntroPhase.vs: '正在载入  ·  引擎预热',
      };
      for (final entry in stages.entries) {
        await pumpPhase(tester, entry.key, 1);
        expect(
          find.text(entry.value),
          findsOneWidget,
          reason: '${entry.key} 底栏文案',
        );
        final n = DuelIntroTimeline.ordinalOf(
          entry.key,
        ).toString().padLeft(2, '0');
        expect(
          find.text('PHASE $n / 03'),
          findsOneWidget,
          reason: '${entry.key} 角标',
        );
      }
    });
  });
}
