import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duel_room3/side_decking/widgets/side_countdown.dart';

/// 换备倒计时读数与格式化的测试。
///
/// 倒计时是**本地**的：服务端不下发换备时限，但久等会被断开 socket。
/// 这里只验证「起始时刻 → mm:ss + 临界态」这段纯逻辑，不依赖真实时钟。
void main() {
  group('formatCountdown', () {
    test('6 分钟显示 06:00', () {
      expect(formatCountdown(const Duration(minutes: 6)), '06:00');
    });

    test('1 分 33 秒补齐前导零', () {
      expect(formatCountdown(const Duration(seconds: 93)), '01:33');
    });

    test('不足一分钟显示 00:ss', () {
      expect(formatCountdown(const Duration(seconds: 41)), '00:41');
    });

    test('归零显示 00:00', () {
      expect(formatCountdown(Duration.zero), '00:00');
    });

    test('超过 100 分钟用 h:mm:ss，不溢出成三位分钟', () {
      expect(formatCountdown(const Duration(minutes: 125)), '2:05:00');
    });
  });

  group('SideCountdown', () {
    Future<void> pump(
      WidgetTester tester, {
      DateTime? startedAt,
      void Function(Duration remaining, bool critical)? onBuild,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SideCountdown(
            startedAt: startedAt,
            builder: (context, remaining, critical) {
              onBuild?.call(remaining, critical);
              return Text(formatCountdown(remaining));
            },
          ),
        ),
      );
    }

    testWidgets('起始时刻为 null 时显示 00:00 且不报错', (tester) async {
      await pump(tester);
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('刚进入换备：剩余接近 6 分钟', (tester) async {
      Duration? got;
      await pump(
        tester,
        startedAt: DateTime.now(),
        onBuild: (r, _) => got = r,
      );
      expect(got, isNotNull);
      // 允许几秒执行误差。
      expect(got!.inSeconds, greaterThan(350));
      expect(got!.inSeconds, lessThanOrEqualTo(360));
    });

    testWidgets('已过 5 分 30 秒：剩余不足 1 分钟，标记为临界', (tester) async {
      var critical = false;
      Duration? got;
      await pump(
        tester,
        startedAt: DateTime.now().subtract(
          const Duration(minutes: 5, seconds: 30),
        ),
        onBuild: (r, c) {
          critical = c;
          got = r;
        },
      );
      expect(critical, true);
      // 执行有毫秒级误差，可能落在 29.9 秒，按范围断言而不是精确 00:30。
      expect(got!.inSeconds, inInclusiveRange(28, 30));
    });

    testWidgets('已超时：剩余夹到 00:00，不会显示负数', (tester) async {
      await pump(
        tester,
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('到点触发 onExpired 一次（用于自动提交）', (tester) async {
      var fired = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SideCountdown(
            startedAt: DateTime.now().subtract(const Duration(minutes: 7)),
            onExpired: () => fired++,
            builder: (context, remaining, critical) =>
                Text(formatCountdown(remaining)),
          ),
        ),
      );
      // 进入页面时已超时：postFrameCallback 补触发一次。
      await tester.pump();
      expect(fired, 1);
      // 再过几个 tick 也不该重复触发（否则会反复自动提交）。
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(fired, 1);
    });

    testWidgets('未超时不触发 onExpired', (tester) async {
      var fired = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SideCountdown(
            startedAt: DateTime.now(),
            onExpired: () => fired++,
            builder: (context, remaining, critical) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();
      expect(fired, 0);
    });

    testWidgets('onExpired 为 null 时到点不报错', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SideCountdown(
            startedAt: DateTime.now().subtract(const Duration(minutes: 7)),
            builder: (context, remaining, critical) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
