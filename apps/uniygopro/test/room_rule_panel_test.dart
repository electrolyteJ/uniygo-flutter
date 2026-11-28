import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/create_room/widgets/room_rule_panel.dart';

void main() {
  testWidgets('规则面板可扩展自定义 key/value 条目', (tester) async {
    int? picked;
    bool? checked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              RoomRulePanel(
                title: '规则设置',
                rows: [
                  RuleRowSpec(
                    key: 'difficulty',
                    label: '难度',
                    options: const ['简单', '困难'],
                    selected: 0,
                    onSelected: (i) => picked = i,
                  ),
                ],
                checks: [
                  RuleCheckSpec(
                    key: 'extra',
                    label: '额外开关',
                    value: false,
                    onChanged: (v) => checked = v,
                  ),
                ],
                collapsed: false,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // 自定义条目按传入的 label/options 渲染。
    expect(find.text('难度'), findsOneWidget);
    expect(find.text('简单'), findsOneWidget);
    expect(find.text('额外开关'), findsOneWidget);

    // 展开并选择“困难” → 回调索引 1。
    await tester.tap(find.text('简单'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rule-option-difficulty-1')));
    await tester.pump();
    expect(picked, 1);

    // 勾选项回调 true。
    await tester.tap(find.byKey(const ValueKey('rule-check-extra')));
    await tester.pump();
    expect(checked, isTrue);
  });


  testWidgets('只读行与底部说明：无箭头、不可点', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              RoomRulePanel(
                title: '408 固定规则',
                rows: const [
                  RuleRowSpec(
                    key: 'master',
                    label: '大师规则',
                    options: ['MR 2020'],
                    selected: 0,
                  ),
                ],
                note: '规则由环境锁定 · 不可修改',
                height: 84,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('大师规则'), findsOneWidget);
    expect(find.text('MR 2020'), findsOneWidget);
    expect(find.text('规则由环境锁定 · 不可修改'), findsOneWidget);

    // 只读行点击不展开选项。
    await tester.tap(find.text('MR 2020'));
    await tester.pump();
    expect(find.byKey(const ValueKey('rule-option-master-0')), findsNothing);
  });
}
