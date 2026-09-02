import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:duel_room1/field/widgets/selector/announce_card_dialog.dart';
import 'package:duel_room1/field/widgets/selector/announce_choice_dialog.dart';
import 'package:duel_room1/field/widgets/selector/card_selector.dart';
import 'package:duel_room1/field/widgets/selector/counter_select_dialog.dart';
import 'package:duel_room1/field/widgets/selector/duel_select_prompt.dart';
import 'package:duel_room1/field/widgets/selector/position_selector.dart';
import 'package:duel_room1/field/widgets/selector/yes_no_dialog.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/ygo_data.dart' as resource;
import 'package:duelink/duelink.dart' show CARD_ZONE_HAND, CARD_ZONE_MZONE;

import 'responsive_test_harness.dart';

const _safePadding = EdgeInsets.fromLTRB(28, 8, 20, 12);

void main() {
  final cards = List.generate(
    20,
    (index) => SelectOption(code: index + 1, label: '卡片 $index'),
  );
  final positions = List.generate(
    4,
    (index) => SelectOption(
      code: 46986414,
      position: 1 << index,
      label: '非常长的表示形式标签 ${index + 1}',
    ),
  );
  final counters = List.generate(
    10,
    (index) => SelectOption(code: index + 1, level: 3),
  );

  group('七类 selector 响应式矩阵', () {
    for (final size in responsiveViewports) {
      testWidgets('$size CardSelector actions 命中高度至少 44', (tester) async {
        Future<void> expectActions(
          SelectState select,
          List<String> labels,
        ) async {
          await _pump(
            tester,
            size,
            CardSelector(
              select: select,
              onSelect: (_) {},
              onCancel: () {},
              onInspectCard: (_) {},
            ),
          );
          for (final label in labels) {
            final button = find.ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate(
                (widget) => widget is TextButton || widget is ElevatedButton,
              ),
            );
            expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
            final buttonWidget = tester.widget<ButtonStyleButton>(button);
            expect(
              buttonWidget.style?.minimumSize?.resolve({})?.height,
              greaterThanOrEqualTo(44),
            );
          }
        }

        await expectActions(
          SelectState(
            type: SelectType.card,
            player: 0,
            min: 0,
            max: 1,
            cancelable: true,
            options: cards.take(1).toList(),
          ),
          ['取消', '确认'],
        );
        await expectActions(
          SelectState(
            type: SelectType.unselect,
            player: 0,
            min: 0,
            max: 1,
            immediateSingleToggle: true,
            finishable: true,
            options: cards.take(1).toList(),
          ),
          ['完成'],
        );
      });

      testWidgets('$size Counter 确认命中高度至少 44', (tester) async {
        await _pump(
          tester,
          size,
          CounterSelectDialog(
            select: SelectState(
              type: SelectType.counter,
              player: 0,
              options: counters.take(1).toList(),
              counterRequired: 0,
            ),
            onSelect: (_) {},
            onInspectCard: (_) {},
          ),
        );
        final button = find.ancestor(
          of: find.text('确认'),
          matching: find.byType(ElevatedButton),
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
        expect(
          tester
              .widget<ElevatedButton>(button)
              .style
              ?.minimumSize
              ?.resolve({})
              ?.height,
          greaterThanOrEqualTo(44),
        );
      });

      testWidgets('$size CardSelector 无 overflow 且确认在安全区', (tester) async {
        await _pump(
          tester,
          size,
          CardSelector(
            select: SelectState(
              type: SelectType.card,
              player: 0,
              min: 0,
              max: 20,
              options: cards,
            ),
            onSelect: (_) {},
            onCancel: () {},
            onInspectCard: (_) {},
          ),
        );
        _expectButtonSafe(tester, '确认', size);
        _expectPanelSafe(tester, size);
      });

      testWidgets('$size PositionSelector 无 overflow 且选项在安全区', (tester) async {
        await _pump(
          tester,
          size,
          PositionSelector(
            select: SelectState(
              type: SelectType.position,
              player: 0,
              options: positions,
            ),
            onSelect: (_) {},
          ),
        );
        _expectPanelSafe(tester, size);
      });

      testWidgets('$size CounterSelectDialog 无 overflow 且确认固定', (tester) async {
        await _pump(
          tester,
          size,
          CounterSelectDialog(
            select: SelectState(
              type: SelectType.counter,
              player: 0,
              options: counters,
              counterRequired: 0,
            ),
            onSelect: (_) {},
            onInspectCard: (_) {},
          ),
        );
        _expectButtonSafe(tester, '确认', size);
        _expectPanelSafe(tester, size);
      });

      testWidgets('$size YesNo 长消息无 overflow 且 actions 固定', (tester) async {
        await _pump(
          tester,
          size,
          YesNoDialog(
            message: '是否确认执行这个非常长的操作说明？' * 20,
            cardCode: 46986414,
            onYes: () {},
            onNo: () {},
          ),
        );
        _expectButtonSafe(tester, '是', size);
        _expectButtonSafe(tester, '否', size);
        _expectPanelSafe(tester, size);
      });

      testWidgets('$size AnnounceChoice 长文案无横溢', (tester) async {
        await _pump(
          tester,
          size,
          AnnounceChoiceDialog(
            title: '这是一个非常长的宣言标题，用来验证标题在狭窄屏幕中正常换行',
            options: List.generate(
              8,
              (index) => SelectOption(
                code: index,
                label: '这是一个非常长的宣言选项 ${index + 1}，需要正常换行显示',
              ),
            ),
            onSelect: (_) {},
          ),
        );
        _expectPanelSafe(tester, size);
      });

      testWidgets('$size AnnounceCard 键盘下标题和搜索框可见', (tester) async {
        await _pump(
          tester,
          size,
          AnnounceCardDialog(onSearch: (_) async => [], onSelect: (_) {}),
          viewInsets: const EdgeInsets.only(bottom: 180),
        );
        _expectPanelSafe(tester, size, keyboardBottom: 180);
        final titleRect = tester.getRect(find.text('宣言卡名'));
        final inputRect = tester.getRect(find.byType(TextField));
        expect(inputRect.height, greaterThanOrEqualTo(44));
        expect(inputRect.top, greaterThanOrEqualTo(titleRect.bottom));
        final spec = DuelRoomLayoutSpec.resolve(
          size,
          safePadding: _safePadding,
        );
        final panelPadding = find.byKey(
          const ValueKey('responsive-panel-safe-padding'),
        );
        expect(panelPadding, findsOneWidget);
        expect(
          tester.widget<Padding>(panelPadding).padding,
          EdgeInsets.all(spec.pagePadding),
        );
      });

      testWidgets('$size DuelSelectPrompt none 穿透且不显示提示', (tester) async {
        var tapped = false;
        await _pumpPrompt(
          tester,
          size,
          const SelectWindowState(),
          onFieldTap: () => tapped = true,
        );
        await tester.tap(find.text('场地'));
        expect(tapped, isTrue);
        expect(find.textContaining('请选择'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$size DuelSelectPrompt modal 使用 barrier 并显示 YesNo', (
        tester,
      ) async {
        var tapped = false;
        await _pumpPrompt(
          tester,
          size,
          const SelectWindowState(
            currentSelect: SelectState(
              type: SelectType.yesNo,
              player: 0,
              hint: '是否执行真实模态选择？',
            ),
          ),
          onFieldTap: () => tapped = true,
        );
        expect(find.text('确认'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('select-modal-barrier')),
          findsOneWidget,
        );
        _expectButtonSafe(tester, '是', size);
        _expectButtonSafe(tester, '否', size);
        _expectPanelSafe(tester, size);
        await tester.tapAt(const Offset(2, 2));
        expect(tapped, isFalse);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$size DuelSelectPrompt place 提示穿透场地', (tester) async {
        var tapped = false;
        await _pumpPrompt(
          tester,
          size,
          const SelectWindowState(
            currentSelect: SelectState(
              type: SelectType.place,
              player: 0,
              options: [
                SelectOption(zone: CARD_ZONE_MZONE, code: 0, sequence: 0),
                SelectOption(zone: CARD_ZONE_MZONE, code: 0, sequence: 1),
              ],
            ),
          ),
          onFieldTap: () => tapped = true,
        );
        expect(find.text('请选择放置区域（可选 2 处）'), findsOneWidget);
        _expectPromptPanelSafe(tester, 'select-place-hint', size);
        await tester.tap(find.text('场地'));
        expect(tapped, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$size DuelSelectPrompt inline 长提示与 actions 安全', (
        tester,
      ) async {
        const hint = '这是一个非常长的就地选择提示，需要在狭窄屏幕中换行且不能挤出取消与确认按钮';
        await _pumpPrompt(
          tester,
          size,
          const SelectWindowState(
            currentSelect: SelectState(
              type: SelectType.card,
              player: 0,
              min: 0,
              max: 2,
              cancelable: true,
              hint: hint,
              options: [
                SelectOption(code: 1, controller: 0, zone: CARD_ZONE_HAND),
              ],
            ),
          ),
        );
        expect(find.text('$hint (0/2)'), findsOneWidget);
        _expectButtonSafe(tester, '取消', size);
        _expectButtonSafe(tester, '确认', size);
        _expectPromptPanelSafe(tester, 'select-inline-bar', size);
        expect(tester.takeException(), isNull);
      });
    }
  });

  for (final count in [1, 2, 3, 4]) {
    testWidgets('PositionSelector 支持 $count 项且点击区域至少 44', (tester) async {
      await _pump(
        tester,
        const Size(320, 240),
        PositionSelector(
          select: SelectState(
            type: SelectType.position,
            player: 0,
            options: positions.take(count).toList(),
          ),
          onSelect: (_) {},
        ),
      );
      final target = find.byType(InkWell).first;
      expect(tester.getSize(target).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Counter options 长度变化后 counts 重置且不越界', (tester) async {
    SelectState state(int count) => SelectState(
      type: SelectType.counter,
      player: 0,
      options: counters.take(count).toList(),
      counterRequired: 1,
    );
    late StateSetter update;
    var count = 1;
    await _pump(
      tester,
      const Size(640, 360),
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return CounterSelectDialog(
            select: state(count),
            onSelect: (_) {},
            onInspectCard: (_) {},
          );
        },
      ),
    );
    update(() => count = 3);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_circle_outline).last);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Counter 同长度新 SelectState 窗口重置 counts', (tester) async {
    SelectState state(int generation) => SelectState(
      type: SelectType.counter,
      player: 0,
      options: counters.take(1).toList(),
      counterRequired: 2,
      generation: generation,
    );
    late StateSetter update;
    var select = state(1);
    await _pump(
      tester,
      const Size(640, 360),
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return CounterSelectDialog(
            select: select,
            onSelect: (_) {},
            onInspectCard: (_) {},
          );
        },
      ),
    );
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    String countValue() => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('counter-count-0')),
            matching: find.byType(Text),
          ),
        )
        .data!;
    expect(countValue(), '1');

    update(() => select = state(2));
    await tester.pump();

    expect(countValue(), '0');
  });

  testWidgets('Counter compact 卡图检视为 44px 语义按钮并触发回调', (tester) async {
    final inspected = <int>[];
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      const Size(640, 360),
      CounterSelectDialog(
        select: SelectState(
          type: SelectType.counter,
          player: 0,
          options: counters.take(1).toList(),
          counterRequired: 1,
        ),
        onSelect: (_) {},
        onInspectCard: inspected.add,
      ),
    );
    final inspectButton = find.ancestor(
      of: find.byType(CardImage),
      matching: find.byType(InkWell),
    );
    expect(inspectButton, findsOneWidget);
    expect(tester.getSize(inspectButton).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(inspectButton).height, greaterThanOrEqualTo(44));
    final inspectSemantics = find.byKey(const ValueKey('counter-inspect-0'));
    expect(inspectSemantics, findsOneWidget);
    expect(
      tester.getSemantics(inspectSemantics).flagsCollection.isButton,
      isTrue,
    );

    await tester.tap(inspectButton);
    expect(inspected, [1]);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Counter 步进器提供独立 tooltip、语义与 enabled 状态', (tester) async {
    await _pump(
      tester,
      const Size(640, 360),
      CounterSelectDialog(
        select: SelectState(
          type: SelectType.counter,
          player: 0,
          options: counters.take(1).toList(),
          counterRequired: 1,
        ),
        onSelect: (_) {},
        onInspectCard: (_) {},
      ),
    );
    final decrease = find.byKey(const ValueKey('counter-decrease-0'));
    final increase = find.byKey(const ValueKey('counter-increase-0'));
    expect(decrease, findsOneWidget);
    expect(increase, findsOneWidget);
    expect(tester.getSemantics(decrease).label, '减少该卡指示物');
    expect(tester.getSemantics(increase).label, '增加该卡指示物');
    expect(
      tester.getSemantics(decrease).flagsCollection.isEnabled,
      Tristate.isFalse,
    );
    expect(
      tester.getSemantics(increase).flagsCollection.isEnabled,
      Tristate.isTrue,
    );
    expect(find.byTooltip('减少该卡指示物'), findsOneWidget);
    expect(find.byTooltip('增加该卡指示物'), findsOneWidget);
    await tester.tap(increase);
    await tester.pump();
    expect(
      tester.getSemantics(decrease).flagsCollection.isEnabled,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(increase).flagsCollection.isEnabled,
      Tristate.isFalse,
    );
  });

  testWidgets('AnnounceCard 自由切受限时清空查询、忽略旧搜索并加载候选', (tester) async {
    final oldSearch = Completer<List<resource.CardInfo>>();
    const restrictedCard = resource.CardInfo(code: 2, type: 0, name: '受限候选');
    late StateSetter update;
    var restricted = false;
    await _pump(
      tester,
      const Size(800, 450),
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return AnnounceCardDialog(
            generation: restricted ? 2 : 1,
            declarableCodes: restricted ? const {2} : null,
            onLoadDeclarable: () async => [restrictedCard],
            onSearch: (_) => oldSearch.future,
            onSelect: (_) {},
          );
        },
      ),
    );
    await tester.enterText(find.byType(TextField), '旧查询');
    await tester.pump(const Duration(milliseconds: 200));
    update(() => restricted = true);
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('受限候选'), findsOneWidget);

    oldSearch.complete([
      const resource.CardInfo(code: 1, type: 0, name: '旧搜索结果'),
    ]);
    await tester.pump();
    expect(find.text('旧搜索结果'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AnnounceCard 行选择与卡图检视有独立语义并支持键盘', (tester) async {
    const card = resource.CardInfo(code: 9, type: 0, name: '语义卡');
    final selected = <int>[];
    final inspected = <int>[];
    await _pump(
      tester,
      const Size(800, 450),
      AnnounceCardDialog(
        generation: 1,
        declarableCodes: const {9},
        onLoadDeclarable: () async => [card],
        onSearch: (_) async => [],
        onSelect: selected.add,
        onInspectCard: inspected.add,
      ),
    );
    await tester.pump();
    final selectButton = find.byKey(const ValueKey('announce-card-select-9'));
    final inspectButton = find.byKey(const ValueKey('announce-card-inspect-9'));
    expect(selectButton, findsOneWidget);
    expect(inspectButton, findsOneWidget);
    expect(tester.getSemantics(selectButton).label, '宣言卡片：语义卡');
    expect(tester.getSemantics(inspectButton).label, '查看卡片：语义卡');
    expect(tester.getSemantics(selectButton).flagsCollection.isButton, isTrue);
    expect(tester.getSemantics(inspectButton).flagsCollection.isButton, isTrue);
    await tester.tap(inspectButton);
    expect(inspected, [9]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, [9]);
  });

  testWidgets('AnnounceCard provider 推进 generation 时重置输入状态', (tester) async {
    final container = ProviderContainer(
      overrides: [
        selectWindowProvider.overrideWith(
          () => _SeededSelectNotifier(
            const SelectWindowState(
              currentSelect: SelectState(
                type: SelectType.announceCard,
                player: 0,
                generation: 1,
              ),
            ),
          ),
        ),
        duelFieldProvider.overrideWithValue(const DuelFieldState()),
      ],
    );
    addTearDown(container.dispose);
    await pumpResponsiveWidget(
      tester,
      UncontrolledProviderScope(
        container: container,
        child: SizedBox.expand(
          child: Stack(children: [DuelSelectPrompt(onInspectCard: (_) {})]),
        ),
      ),
      const Size(800, 450),
    );
    await tester.enterText(find.byType(TextField), '上一窗口输入');
    (container.read(selectWindowProvider.notifier) as _SeededSelectNotifier)
        .replace(
          const SelectWindowState(
            currentSelect: SelectState(
              type: SelectType.announceCard,
              player: 0,
              generation: 2,
            ),
          ),
        );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text('请输入卡名开始搜索'), findsOneWidget);
  });

  testWidgets('AnnounceCard 卸载后旧搜索完成不 setState', (tester) async {
    final search = Completer<List<resource.CardInfo>>();
    await _pump(
      tester,
      const Size(800, 450),
      AnnounceCardDialog(
        generation: 1,
        onSearch: (_) => search.future,
        onSelect: (_) {},
      ),
    );
    await tester.enterText(find.byType(TextField), '等待请求');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    search.complete(const []);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Size size,
  Widget child, {
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  await pumpResponsiveWidget(
    tester,
    Center(child: child),
    size,
    safePadding: _safePadding,
    viewInsets: viewInsets,
  );
  expect(tester.takeException(), isNull);
}

Future<void> _pumpPrompt(
  WidgetTester tester,
  Size size,
  SelectWindowState state, {
  VoidCallback? onFieldTap,
}) async {
  await pumpResponsiveWidget(
    tester,
    ProviderScope(
      overrides: [
        selectWindowProvider.overrideWith(() => _SeededSelectNotifier(state)),
        duelFieldProvider.overrideWithValue(const DuelFieldState()),
      ],
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: TextButton(onPressed: onFieldTap, child: const Text('场地')),
            ),
            DuelSelectPrompt(onInspectCard: (_) {}),
          ],
        ),
      ),
    ),
    size,
    safePadding: _safePadding,
  );
}

void _expectButtonSafe(WidgetTester tester, String label, Size size) {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  expect(button, findsOneWidget);
  _expectRectSafe(tester, tester.getRect(button), size);
}

void _expectPanelSafe(
  WidgetTester tester,
  Size size, {
  double keyboardBottom = 0,
}) {
  final panel = find.byKey(const ValueKey('responsive-panel-chrome'));
  expect(panel, findsOneWidget);
  _expectRectSafe(
    tester,
    tester.getRect(panel),
    size,
    keyboardBottom: keyboardBottom,
  );
}

void _expectRectSafe(
  WidgetTester tester,
  Rect rect,
  Size size, {
  double keyboardBottom = 0,
}) {
  final safeRect = DuelRoomLayoutSpec.resolve(
    size,
    safePadding: _safePadding,
  ).safeRect;
  expect(rect.left, greaterThanOrEqualTo(safeRect.left));
  expect(rect.top, greaterThanOrEqualTo(safeRect.top));
  expect(rect.right, lessThanOrEqualTo(safeRect.right));
  expect(
    rect.bottom,
    lessThanOrEqualTo(math.min(safeRect.bottom, size.height - keyboardBottom)),
  );
  expect(tester.takeException(), isNull);
}

void _expectPromptPanelSafe(WidgetTester tester, String key, Size size) {
  final panel = find.byKey(ValueKey(key));
  expect(panel, findsOneWidget);
  _expectRectSafe(tester, tester.getRect(panel), size);
}

class _SeededSelectNotifier extends SelectWindowNotifier {
  _SeededSelectNotifier(this.initialState);

  final SelectWindowState initialState;

  @override
  SelectWindowState build() => initialState;

  void replace(SelectWindowState value) => state = value;
}
