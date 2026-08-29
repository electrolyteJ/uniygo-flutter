/// 指示物分配 / 宣言卡名 / LP 条 / 卡片详情面板的 widget 测试。
library;

import 'package:biz/duel/models/select_state.dart';
import 'package:duel_room3/hud/announce_card_dialog.dart';
import 'package:duel_room3/hud/card_detail_panel.dart';
import 'package:duel_room3/hud/counter_allocator_dialog.dart';
import 'package:duel_room3/hud/hud_theme.dart';
import 'package:duel_room3/hud/lp_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/card_info.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('CounterAllocatorDialog', () {
    const select = SelectState(
      type: SelectType.counter,
      player: 0,
      counterRequired: 2,
      options: [
        SelectOption(code: 89631139, level: 3),
        SelectOption(code: 46986414, level: 2),
      ],
    );

    testWidgets('分配总数恰好等于需求才能确认', (tester) async {
      List<int>? submitted;
      await tester.pumpWidget(
        _wrap(
          CounterAllocatorDialog(
            select: select,
            cardNameBuilder: (code) => 'Card #$code',
            onSubmit: (counts) => submitted = counts,
          ),
        ),
      );
      FilledButton confirm() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '确认'),
      );
      // 初始 0/2 → 禁用
      expect(confirm().onPressed, isNull);
      // 第一张卡 +2（点两次加号）
      final addButtons = find.byIcon(Icons.add_circle_outline);
      await tester.tap(addButtons.first);
      await tester.tap(addButtons.first);
      await tester.pump();
      expect(confirm().onPressed, isNotNull);
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pump();
      expect(submitted, [2, 0]);
    });

    testWidgets('onCancel 为 null 时不显示取消按钮', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CounterAllocatorDialog(
            select: select,
            cardNameBuilder: (code) => '#$code',
            onSubmit: (_) {},
          ),
        ),
      );
      expect(find.text('取消'), findsNothing);
    });
  });

  group('AnnounceCardDialog', () {
    testWidgets('自由宣言（declarableCodes=null）：搜索出结果并可点选', (
      tester,
    ) async {
      int? picked;
      await tester.pumpWidget(
        _wrap(
          AnnounceCardDialog(
            declarableCodes: null, // 自由宣言：旧实现此时列表恒空死锁
            onSearch: (q) async => [
              const CardInfo(code: 89631139, type: 0x21, name: '青眼白龙'),
            ],
            onSelect: (code) => picked = code,
          ),
        ),
      );
      expect(find.text('请输入卡名开始搜索'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '青眼');
      await tester.pump(); // 防抖 180ms
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(); // 搜索结果落盘
      expect(find.text('青眼白龙'), findsOneWidget);
      await tester.tap(find.text('青眼白龙'));
      await tester.pump();
      expect(picked, 89631139);
    });

    testWidgets('受限宣言：打开即加载候选并直接罗列', (tester) async {
      int? picked;
      await tester.pumpWidget(
        _wrap(
          AnnounceCardDialog(
            declarableCodes: const {46986414},
            onLoadDeclarable: () async => [
              const CardInfo(code: 46986414, type: 0x21, name: '黑魔术师'),
            ],
            onSearch: (_) async => const [],
            onSelect: (code) => picked = code,
          ),
        ),
      );
      await tester.pump(); // 加载完成
      expect(find.text('黑魔术师'), findsOneWidget);
      // 受限宣言无搜索框
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('黑魔术师'));
      await tester.pump();
      expect(picked, 46986414);
    });
  });

  group('LpBar 比例分档', () {
    Color barColorOf(WidgetTester tester) {
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      return (indicator.valueColor as AlwaysStoppedAnimation<Color?>).value!;
    }

    testWidgets('match 16000 初始：半血 8000 仍是满格色系而非红', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LpBar(playerName: '我', lp: 8000, maxLp: 16000, alignLeft: true)),
      );
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.5);
      // ratio=0.5 → 中血档（gold）；旧绝对阈值下 8000>4000 会错误显示满血 cyan
      expect(barColorOf(tester), HudTheme.gold);
      await tester.pumpWidget(
        _wrap(const LpBar(playerName: '我', lp: 3000, maxLp: 16000, alignLeft: true)),
      );
      // 3000/16000 = 0.1875 → 危险档（danger 红）；
      // 旧绝对阈值下 3000>2000 会错误显示 gold
      expect(barColorOf(tester), HudTheme.danger);
    });
  });

  group('CardDetailPanel 攻守显示', () {
    testWidgets('魔法卡不显示 ATK/DEF', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CardDetailPanel(
            code: 55144522,
            info: const CardInfo(code: 55144522, type: 0x2, name: '融合'),
            onClose: () {},
          ),
        ),
      );
      expect(find.textContaining('ATK'), findsNothing);
    });

    testWidgets('怪兽显示 ATK/DEF；连接怪不显示 DEF', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CardDetailPanel(
            code: 89631139,
            info: const CardInfo(
              code: 89631139,
              type: 0x11, // 怪兽|通常
              name: '青眼白龙',
              attack: 3000,
              defense: 2500,
            ),
            onClose: () {},
          ),
        ),
      );
      expect(find.text('ATK 3000 / DEF 2500'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          CardDetailPanel(
            code: 1,
            info: const CardInfo(
              code: 1,
              type: 0x4000001, // 怪兽|连接
              name: '连接怪',
              attack: 1500,
            ),
            onClose: () {},
          ),
        ),
      );
      expect(find.text('ATK 1500'), findsOneWidget);
      expect(find.textContaining('DEF'), findsNothing);
    });

    testWidgets('负攻守显示 ?', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CardDetailPanel(
            code: 2,
            info: const CardInfo(
              code: 2,
              type: 0x11,
              name: '?怪',
              attack: -1,
              defense: -1,
            ),
            onClose: () {},
          ),
        ),
      );
      expect(find.text('ATK ? / DEF ?'), findsOneWidget);
    });
  });
}
