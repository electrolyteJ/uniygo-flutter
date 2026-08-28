import 'package:biz/duel/models/select_state.dart';
import 'package:duel_room1/field/widgets/selector/card_selector.dart';
import 'package:duelink/duelink.dart'
    show CARD_ZONE_DECK, CARD_ZONE_GRAVE, CARD_ZONE_MZONE;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('选卡弹窗显示每张卡的来源区域徽标', (tester) async {
    final select = SelectState(
      type: SelectType.card,
      player: 0, // 选择发起方：己方
      min: 1,
      max: 1,
      options: const [
        // 己方墓地
        SelectOption(code: 0, controller: 0, zone: CARD_ZONE_GRAVE),
        // 对方卡组
        SelectOption(code: 0, controller: 1, zone: CARD_ZONE_DECK),
        // 己方场上（怪兽区）
        SelectOption(code: 0, controller: 0, zone: CARD_ZONE_MZONE),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardSelector(
            select: select,
            onSelect: (_) {},
            onCancel: () {},
            onInspectCard: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('墓地'), findsOneWidget);
    expect(find.text('对方卡组'), findsOneWidget);
    expect(find.text('怪兽区'), findsOneWidget);
  });

  testWidgets('效果选项（SelectType.option）不显示来源徽标', (tester) async {
    final select = SelectState(
      type: SelectType.option,
      player: 0,
      options: const [
        SelectOption(code: 0, zone: CARD_ZONE_GRAVE, label: '选项一'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardSelector(
            select: select,
            onSelect: (_) {},
            onCancel: () {},
            onInspectCard: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('墓地'), findsNothing);
  });
}
