/// 对局场地 HUD 新增组件的 widget 测试。
///
/// 覆盖本子域新增的四个纯展示组件：
/// - ConfirmCardsDialog（确认多卡弹窗 A2a）
/// - ConfirmFloatingCard（顶部浮动确认卡 A2b）
/// - ZoneCountBar（区域计数条 B2）
/// - TurnOrderHint（先后攻提示 B4）
///
/// 这些组件都不读取 Riverpod 状态，数据/回调由调用方注入，故直接用
/// 无 ProviderScope 的 MaterialApp 包裹即可（B3 回合倒计时内联在页面里，
/// 属既有徽章区扩展，不在此单独测试）。
library;

import 'package:duel_room3/hud/confirm_cards_dialog.dart';
import 'package:duel_room3/hud/confirm_floating_card.dart';
import 'package:duel_room3/hud/turn_order_hint.dart';
import 'package:duel_room3/hud/zone_count_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('ZoneCountBar', () {
    testWidgets('渲染 HAND/DECK/EXTRA/GY/B 计数', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ZoneCountBar(
            handCount: 5,
            deckCount: 35,
            extraCount: 8,
            graveCount: 3,
            removedCount: 1,
          ),
        ),
      );

      expect(find.text('HAND 5'), findsOneWidget);
      expect(find.text('DECK 35'), findsOneWidget);
      expect(find.text('EXTRA 8'), findsOneWidget);
      expect(find.text('GY 3'), findsOneWidget);
      expect(find.text('B 1'), findsOneWidget);
    });

    testWidgets('EXTRA/GY/B 可点击，HAND/DECK 只读', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _wrap(
          ZoneCountBar(
            handCount: 5,
            deckCount: 35,
            extraCount: 8,
            graveCount: 3,
            removedCount: 1,
            onExtraTap: () => taps.add('extra'),
            onGraveTap: () => taps.add('grave'),
            onRemovedTap: () => taps.add('removed'),
          ),
        ),
      );

      await tester.tap(find.text('EXTRA 8'));
      await tester.tap(find.text('GY 3'));
      await tester.tap(find.text('B 1'));
      // HAND/DECK 无回调：点它不报错也不追加记录。
      await tester.tap(find.text('HAND 5'));
      await tester.tap(find.text('DECK 35'));

      expect(taps, ['extra', 'grave', 'removed']);
    });
  });

  group('ConfirmCardsDialog', () {
    testWidgets('展示标题/数量/确认按钮，点确认关闭', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _wrap(
          ConfirmCardsDialog(
            title: '确认卡组',
            codes: const [89631139, 46986414],
            cardNameBuilder: (code) => code == 89631139 ? '青眼白龙' : '黑魔导',
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      expect(find.text('确认卡组'), findsOneWidget);
      expect(find.text('2 张'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);

      await tester.tap(find.text('确认'));
      expect(dismissed, isTrue);
    });

    testWidgets('点击弹窗任意处（标题区域）关闭', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _wrap(
          ConfirmCardsDialog(
            title: '确认卡组',
            codes: const [89631139],
            cardNameBuilder: (_) => '青眼白龙',
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      await tester.tap(find.text('确认卡组'));
      expect(dismissed, isTrue);
    });
  });

  group('ConfirmFloatingCard', () {
    testWidgets('渲染 notifier 下标指向的卡与序号', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ConfirmFloatingCard(
            codes: const [89631139, 46986414],
            currentIndex: 0,
            title: '卡组顶部',
            cardNameBuilder: (code) => code == 89631139 ? '青眼白龙' : '黑魔导',
          ),
        ),
      );

      expect(find.text('卡组顶部'), findsOneWidget);
      expect(find.text('青眼白龙'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);

      // 完成装饰动画（forward），避免遗留活动 ticker。
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('切换 currentIndex 渲染下一张卡', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ConfirmFloatingCard(
            codes: const [89631139, 46986414],
            currentIndex: 1,
            title: '额外卡组顶部',
            cardNameBuilder: (code) => code == 89631139 ? '青眼白龙' : '黑魔导',
          ),
        ),
      );

      expect(find.text('额外卡组顶部'), findsOneWidget);
      expect(find.text('黑魔导'), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('TurnOrderHint', () {
    testWidgets('先攻显示文案并在约 2 秒后淡出回调', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _wrap(
          TurnOrderHint(isFirst: true, onDismiss: () => dismissed = true),
        ),
      );
      await tester.pump(); // 首帧后置 opacity=1
      expect(find.text('你先攻'), findsOneWidget);
      expect(find.text('First Turn'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2100)); // 停留 2000ms 到点
      await tester.pump(const Duration(milliseconds: 500)); // 淡出 400ms 到点
      expect(dismissed, isTrue);
    });

    testWidgets('后攻显示对应文案', (tester) async {
      await tester.pumpWidget(_wrap(const TurnOrderHint(isFirst: false)));
      await tester.pump();
      expect(find.text('你后攻'), findsOneWidget);
      expect(find.text('Second Turn'), findsOneWidget);

      // 让两个 Timer 走完，避免测试结束时有 pending timer。
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
