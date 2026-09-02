import 'package:biz/duel/models/select_state.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:duel_room1/field/widgets/selector/card_selector.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:duelink/duelink.dart'
    show CARD_ZONE_DECK, CARD_ZONE_GRAVE, CARD_ZONE_MZONE;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' show Tristate;

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

  testWidgets('20 张卡按 layout spec 列数铺满网格且卡图保持 59:86', (tester) async {
    const size = Size(800, 450);
    final spec = DuelRoomLayoutSpec.resolve(size);
    final select = SelectState(
      type: SelectType.card,
      player: 0,
      min: 1,
      max: 20,
      options: List.generate(20, (index) => SelectOption(code: index + 1)),
    );

    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DuelRoomLayout(
            spec: spec,
            child: CardSelector(
              select: select,
              onSelect: (_) {},
              onCancel: () {},
              onInspectCard: (_) {},
            ),
          ),
        ),
      ),
    );

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, spec.gridColumns);
    expect(delegate.childAspectRatio, closeTo(59 / 86, 0.001));
    final cardImage = find.byType(CardImage).first;
    final aspectRatio = find.ancestor(
      of: cardImage,
      matching: find.byType(AspectRatio),
    );
    expect(aspectRatio, findsOneWidget);
    expect(
      tester.widget<AspectRatio>(aspectRatio).aspectRatio,
      closeTo(59 / 86, 0.001),
    );
    final imageSize = tester.getSize(cardImage);
    expect(imageSize.width / imageSize.height, closeTo(59 / 86, 0.001));
    expect(tester.getSize(aspectRatio), imageSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets('长效果选项不横向溢出且仍可选择', (tester) async {
    final selected = <int>[];
    final select = SelectState(
      type: SelectType.option,
      player: 0,
      options: const [
        SelectOption(
          code: 0,
          label: '这是一个非常长的效果选项说明，用于验证狭窄窗口中不会横向溢出并且仍然可以点击选择',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardSelector(
            select: select,
            onSelect: selected.addAll,
            onCancel: () {},
            onInspectCard: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.textContaining('这是一个非常长'));
    await tester.pump();
    await tester.tap(find.text('确认'));
    expect(selected, [0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同 generation 补全 label 时保留勾选，新 generation 重置', (tester) async {
    late StateSetter update;
    var select = const SelectState(
      type: SelectType.card,
      player: 0,
      generation: 7,
      options: [SelectOption(code: 1)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return CardSelector(
                select: select,
                onSelect: (_) {},
                onCancel: () {},
                onInspectCard: (_) {},
              );
            },
          ),
        ),
      ),
    );
    final option = find.byKey(const ValueKey('card-selector-option-0'));
    await tester.tap(option);
    await tester.pump();
    expect(
      tester.getSemantics(option).flagsCollection.isSelected,
      Tristate.isTrue,
    );

    update(() {
      select = const SelectState(
        type: SelectType.card,
        player: 0,
        generation: 7,
        options: [SelectOption(code: 1, label: '补全名称')],
      );
    });
    await tester.pump();
    expect(
      tester.getSemantics(option).flagsCollection.isSelected,
      Tristate.isTrue,
    );

    update(() => select = select.copyWith(generation: 8));
    await tester.pump();
    expect(
      tester.getSemantics(option).flagsCollection.isSelected,
      Tristate.isFalse,
    );
  });

  testWidgets('卡片选项提供来源选择语义且键盘可激活', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardSelector(
            select: const SelectState(
              type: SelectType.card,
              player: 0,
              min: 0,
              max: 1,
              options: [
                SelectOption(code: 1, zone: CARD_ZONE_GRAVE, label: '测试卡'),
              ],
            ),
            onSelect: selected.addAll,
            onCancel: () {},
            onInspectCard: (_) {},
          ),
        ),
      ),
    );
    final option = find.byKey(const ValueKey('card-selector-option-0'));
    final semantics = tester.getSemantics(option);
    expect(semantics.label, contains('测试卡'));
    expect(semantics.label, contains('墓地'));
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isEnabled, Tristate.isTrue);
    expect(semantics.flagsCollection.isSelected, Tristate.isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.tap(find.text('确认'));
    expect(selected, [0]);
  });
}
