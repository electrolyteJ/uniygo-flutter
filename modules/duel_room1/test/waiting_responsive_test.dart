import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:biz/duel/room/duel_room_state.dart' show SidingZone;
import 'package:duel_room1/hand_turn/hand_select_panel.dart';
import 'package:duel_room1/waiting/widgets/overlay_panel.dart';
import 'package:biz/widgets/automation_switch.dart';
import 'package:duel_room1/waiting/widgets/deck_selector.dart';
import 'package:duel_room1/waiting/widgets/playerslot.dart';
import 'package:duel_room1/hand_turn/widgets/select_hand.dart';
import 'package:duel_room1/waiting/widgets/side_decking_panel.dart';
import 'package:duel_room1/hand_turn/widgets/stage_selection_panel_host.dart';
import 'package:duel_room1/hand_turn/turn_select_panel.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/card_info.dart' as resource;
import 'package:resource_data/deck_info.dart';

import 'responsive_test_harness.dart';

void main() {
  const compactViewports = [Size(640, 360), Size(800, 450)];
  final longPlayerName = '玩家名字很长' * 10;
  final longDeckName = '超长卡组名称' * 16;
  final longCardName = '超长换备卡片名称' * 14;

  Widget handPanel({bool isResult = false}) => HandSelectPanel(
    isResult: isResult,
    myHand: 1,
    opponentHand: 2,
    enabled: true,
    onSendHand: (_) {},
  );

  Widget turnPanel() => TurnSelectPanel(enabled: true, onSendTp: (_) {});

  void expectNoLayoutFailure(WidgetTester tester) {
    expect(tester.takeException(), isNull);
    final panelRect = tester.getRect(find.byType(OverlayPanel));
    final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(panelRect.left, greaterThanOrEqualTo(0));
    expect(panelRect.top, greaterThanOrEqualTo(0));
    expect(panelRect.right, lessThanOrEqualTo(viewport.width));
    expect(panelRect.bottom, lessThanOrEqualTo(viewport.height));
    expect(panelRect.center.dx, closeTo(viewport.width / 2, 0.5));
  }

  group('waiting stage panels', () {
    for (final viewport in responsiveViewports) {
      testWidgets('HandSelectPanel fits $viewport', (tester) async {
        await pumpResponsiveWidget(tester, handPanel(), viewport);
        expectNoLayoutFailure(tester);
        expect(find.byType(StageSelectionPanelHost), findsOneWidget);
        expect(
          tester
              .widget<ConstrainedBox>(
                find.byKey(const ValueKey('stage-selection-panel-constraints')),
              )
              .constraints
              .maxWidth,
          lessThanOrEqualTo(520),
        );
      });

      testWidgets('TurnSelectPanel fits $viewport', (tester) async {
        await pumpResponsiveWidget(tester, turnPanel(), viewport);
        expectNoLayoutFailure(tester);
        expect(find.byType(StageSelectionPanelHost), findsOneWidget);
      });

      testWidgets('all five choices have 44px hit targets at $viewport', (
        tester,
      ) async {
        await pumpResponsiveWidget(
          tester,
          Stack(children: [handPanel(), turnPanel()]),
          viewport,
        );

        for (final key in const [
          'hand-select-scissors',
          'hand-select-rock',
          'hand-select-paper',
          'tp-select-first',
          'tp-select-second',
        ]) {
          final size = tester.getSize(find.byKey(ValueKey(key)));
          expect(
            size.width,
            greaterThanOrEqualTo(44),
            reason: '$viewport $key',
          );
          expect(
            size.height,
            greaterThanOrEqualTo(44),
            reason: '$viewport $key',
          );
        }
      });
    }

    testWidgets('fixed titles and result copy fit at 1.3 text scale', (
      tester,
    ) async {
      await pumpResponsiveWidget(
        tester,
        Stack(children: [handPanel(isResult: true), turnPanel()]),
        const Size(640, 360),
        safePadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        textScaler: const TextScaler.linear(1.3),
      );

      expect(tester.takeException(), isNull);
      for (final copy in const ['猜拳定先攻', '猜拳获胜！选择先后攻', '等待对方选择先后攻…']) {
        final text = tester.widget<Text>(find.text(copy));
        expect(text.maxLines, 2, reason: copy);
        expect(text.textAlign, TextAlign.center, reason: copy);
      }
    });

    testWidgets('640x360 scrolls enlarged hand result content', (tester) async {
      await pumpResponsiveWidget(
        tester,
        handPanel(isResult: true),
        const Size(640, 360),
        safePadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        textScaler: const TextScaler.linear(3),
      );

      expectNoLayoutFailure(tester);
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      final before = scrollable.position.pixels;
      await tester.drag(find.byType(Scrollable), const Offset(0, -100));
      await tester.pump();
      expect(scrollable.position.pixels, greaterThan(before));
      expect(find.text('等待对方选择先后攻…'), findsOneWidget);
    });

    testWidgets('640x360 scrolls enlarged turn selection content', (
      tester,
    ) async {
      await pumpResponsiveWidget(
        tester,
        turnPanel(),
        const Size(640, 360),
        safePadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        textScaler: const TextScaler.linear(3),
      );

      expectNoLayoutFailure(tester);
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      final before = scrollable.position.pixels;
      await tester.drag(find.byType(Scrollable), const Offset(0, -100));
      await tester.pump();
      expect(scrollable.position.pixels, greaterThan(before));
      final title = tester.widget<Text>(find.text('猜拳获胜！选择先后攻'));
      expect(title.maxLines, 2);
      expect(title.textAlign, TextAlign.center);
    });
  });

  group('waiting controls remain responsive with long content', () {
    for (final viewport in compactViewports) {
      testWidgets('player slot preserves actions at $viewport', (tester) async {
        var kicks = 0;
        await pumpResponsiveWidget(
          tester,
          Center(
            child: SizedBox(
              width: 280,
              child: PlayerSlot(
                player: PlayerInfo(
                  name: longPlayerName,
                  ready: true,
                  host: true,
                ),
                placeholder: '等待玩家',
                isHostSlot: true,
                canKick: true,
                onKick: () => kicks++,
              ),
            ),
          ),
          viewport,
          textScaler: const TextScaler.linear(1.3),
        );

        expect(tester.takeException(), isNull);
        final name = tester.widget<Text>(find.text(longPlayerName));
        expect(name.maxLines, 1);
        expect(name.overflow, TextOverflow.ellipsis);
        expect(find.text('房主'), findsOneWidget);
        expect(find.byTooltip('踢出玩家'), findsOneWidget);
        final kick = find.ancestor(
          of: find.byIcon(Icons.person_remove),
          matching: find.byType(IconButton),
        );
        final kickSize = tester.getSize(kick);
        expect(kickSize.width, greaterThanOrEqualTo(44));
        expect(kickSize.height, greaterThanOrEqualTo(44));
        expect(
          tester.widget<Icon>(find.byIcon(Icons.person_remove)).semanticLabel,
          isNull,
        );
        final semantics = tester.getSemantics(kick);
        expect(semantics.flagsCollection.isButton, isTrue);
        await tester.tap(kick);
        expect(kicks, 1);
      });

      testWidgets(
        'deck selector truncates names and keeps editing at $viewport',
        (tester) async {
          String? selected;
          var edits = 0;
          final secondDeckName = '$longDeckName二';
          final longError = '卡组错误状态说明' * 20;
          final decks = [
            DeckInfo(deckName: longDeckName),
            DeckInfo(deckName: secondDeckName),
          ];
          await pumpResponsiveWidget(
            tester,
            SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 100,
                  child: DeckSelector(
                    decks: decks,
                    selectedDeckName: longDeckName,
                    selfType: PlayerType.player1,
                    onSelectDeck: (value) => selected = value,
                    onEditDeck: () => edits++,
                    invalidationResult: [longError],
                  ),
                ),
              ),
            ),
            viewport,
            textScaler: const TextScaler.linear(1.3),
          );

          expect(tester.takeException(), isNull);
          final selectedText = tester.widget<Text>(find.text(longDeckName));
          expect(selectedText.maxLines, 1);
          expect(selectedText.overflow, TextOverflow.ellipsis);
          final errorText = tester.widget<Text>(find.text('• $longError'));
          expect(errorText.maxLines, isNotNull);
          final editButton = find.widgetWithText(OutlinedButton, '编辑当前卡组');
          expect(tester.getSize(editButton).width, lessThanOrEqualTo(100));
          await tester.tap(find.text('编辑当前卡组'));
          expect(edits, 1);

          await tester.tap(find.byType(DropdownButton<String>));
          await tester.pumpAndSettle();
          final menuItem = find.byWidgetPredicate(
            (widget) =>
                widget is DropdownMenuItem<String> &&
                widget.value == secondDeckName,
          );
          expect(menuItem, findsOneWidget);
          final menuRect = tester.getRect(menuItem);
          final viewportRect = Offset.zero & viewport;
          expect(viewportRect.contains(menuRect.topLeft), isTrue);
          expect(viewportRect.contains(menuRect.bottomRight), isTrue);
          await tester.tap(menuItem);
          await tester.pumpAndSettle();
          expect(selected, secondDeckName);
        },
      );


      testWidgets('automation switch has a 44px semantic target at $viewport', (
        tester,
      ) async {
        var value = false;
        await pumpResponsiveWidget(
          tester,
          Center(
            child: SizedBox(
              width: 150,
              child: AutomationSwitch(
                label: '自动化开关说明文字很长很长',
                value: value,
                enabled: true,
                onChanged: (next) => value = next,
              ),
            ),
          ),
          viewport,
          textScaler: const TextScaler.linear(1.3),
        );

        expect(tester.takeException(), isNull);
        final target = find.bySemanticsLabel('自动化开关说明文字很长很长');
        expect(target, findsOneWidget);
        final size = tester.getSize(target);
        expect(size.height, greaterThanOrEqualTo(44));
        expect(size.width, lessThanOrEqualTo(150));
        final semantics = tester.getSemantics(target);
        expect(
          semantics.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        tester.semantics.tap(find.semantics.byLabel('自动化开关说明文字很长很长'));
        await tester.pump();
        expect(value, isTrue);
      });

      testWidgets(
        'side decking truncates cards and wraps actions at $viewport',
        (tester) async {
          var resets = 0;
          var confirms = 0;
          final card = resource.CardInfo(
            code: 1,
            type: 0x2,
            name: longCardName,
          );
          await pumpResponsiveWidget(
            tester,
            SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 240,
                  child: SideDeckingPanel(
                    isDuelist: true,
                    sidingMain: [card],
                    sidingExtra: const [],
                    sidingSide: [card],
                    baselineMainCount: 1,
                    baselineExtraCount: 0,
                    baselineSideCount: 1,
                    onMoveCard: (_, _, _) {},
                    onReset: () => resets++,
                    onConfirm: () async => confirms++,
                  ),
                ),
              ),
            ),
            viewport,
            textScaler: const TextScaler.linear(1.3),
          );

          expect(tester.takeException(), isNull);
          for (final text in tester.widgetList<Text>(find.text(longCardName))) {
            expect(text.maxLines, 1);
            expect(text.overflow, TextOverflow.ellipsis);
          }
          final reset = tester.getRect(
            find.widgetWithText(OutlinedButton, '重置'),
          );
          final confirm = tester.getRect(
            find.byKey(const ValueKey('side-decking-confirm')),
          );
          expect(reset.right, lessThanOrEqualTo(viewport.width));
          expect(confirm.right, lessThanOrEqualTo(viewport.width));
          expect(reset.overlaps(confirm), isFalse);
          await tester.tap(find.widgetWithText(OutlinedButton, '重置'));
          await tester.tap(find.byKey(const ValueKey('side-decking-confirm')));
          await tester.pump();
          expect(resets, 1);
          expect(confirms, 1);
        },
      );
    }

    testWidgets(
      'disabled automation switch keeps semantics and does not fire',
      (tester) async {
        var calls = 0;
        await pumpResponsiveWidget(
          tester,
          AutomationSwitch(
            label: '禁用自动化',
            value: true,
            enabled: false,
            onChanged: (_) => calls++,
          ),
          const Size(640, 360),
          textScaler: const TextScaler.linear(1.3),
        );

        final target = find.bySemanticsLabel('禁用自动化');
        final semantics = tester.getSemantics(target);
        expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
        expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
        expect(
          semantics.getSemanticsData().hasAction(SemanticsAction.tap),
          isFalse,
        );
        await tester.tap(target, warnIfMissed: false);
        expect(calls, 0);
      },
    );

    testWidgets(
      'side decking move controls have 44px targets and disable while submitting',
      (tester) async {
        final moves = <(SidingZone, SidingZone, int)>[];
        final confirm = Completer<void>();
        var resets = 0;
        const mainCard = resource.CardInfo(code: 1, type: 0x2, name: '主卡动作');
        const extraCard = resource.CardInfo(code: 2, type: 0x41, name: '额外卡动作');
        const sideMainCard = resource.CardInfo(
          code: 3,
          type: 0x2,
          name: '回主动作',
        );
        const sideExtraCard = resource.CardInfo(
          code: 4,
          type: 0x41,
          name: '回额动作',
        );
        await pumpResponsiveWidget(
          tester,
          SingleChildScrollView(
            child: SizedBox(
              width: 300,
              child: SideDeckingPanel(
                isDuelist: true,
                sidingMain: const [mainCard],
                sidingExtra: const [extraCard],
                sidingSide: const [sideMainCard, sideExtraCard],
                baselineMainCount: 1,
                baselineExtraCount: 1,
                baselineSideCount: 2,
                onMoveCard: (from, to, index) => moves.add((from, to, index)),
                onReset: () => resets++,
                onConfirm: () => confirm.future,
              ),
            ),
          ),
          const Size(640, 360),
          textScaler: const TextScaler.linear(1.3),
        );

        for (final label in const [
          '将 主卡动作 移入副卡组',
          '将 额外卡动作 移入副卡组',
          '将 回主动作 移回主卡组',
          '将 回额动作 移回额外卡组',
        ]) {
          final target = find.bySemanticsLabel(label);
          expect(target, findsOneWidget, reason: label);
          final size = tester.getSize(target);
          expect(size.width, greaterThanOrEqualTo(44), reason: label);
          expect(size.height, greaterThanOrEqualTo(44), reason: label);
          expect(
            tester.getSemantics(target).flagsCollection.isEnabled,
            Tristate.isTrue,
            reason: label,
          );
        }

        await tester.tap(find.bySemanticsLabel('将 主卡动作 移入副卡组'));
        await tester.tap(find.bySemanticsLabel('将 额外卡动作 移入副卡组'));
        await tester.tap(find.bySemanticsLabel('将 回主动作 移回主卡组'));
        await tester.tap(find.bySemanticsLabel('将 回额动作 移回额外卡组'));
        expect(moves, [
          (SidingZone.main, SidingZone.side, 0),
          (SidingZone.extra, SidingZone.side, 0),
          (SidingZone.side, SidingZone.main, 0),
          (SidingZone.side, SidingZone.extra, 1),
        ]);

        await tester.tap(find.byKey(const ValueKey('side-decking-confirm')));
        await tester.pump();
        final beforeDisabledTaps = moves.length;
        for (final label in const ['将 主卡动作 移入副卡组', '将 回主动作 移回主卡组']) {
          final target = find.bySemanticsLabel(label);
          expect(
            tester.getSemantics(target).flagsCollection.isEnabled,
            Tristate.isFalse,
            reason: label,
          );
          await tester.tap(target, warnIfMissed: false);
        }
        expect(moves, hasLength(beforeDisabledTaps));
        final reset = find.widgetWithText(OutlinedButton, '重置');
        expect(tester.widget<OutlinedButton>(reset).onPressed, isNull);
        await tester.tap(reset, warnIfMissed: false);
        expect(resets, 0);

        confirm.complete();
        await tester.pump();
      },
    );

    for (final validation in <List<String>?>[const [], null]) {
      testWidgets(
        'deck selector ${validation == null ? 'unchecked' : 'valid'} status fits narrow width',
        (tester) async {
          await pumpResponsiveWidget(
            tester,
            Center(
              child: SizedBox(
                width: 100,
                child: DeckSelector(
                  decks: [DeckInfo(deckName: '测试卡组')],
                  selectedDeckName: '测试卡组',
                  selfType: PlayerType.player1,
                  onSelectDeck: (_) {},
                  invalidationResult: validation,
                ),
              ),
            ),
            const Size(640, 360),
            textScaler: const TextScaler.linear(1.3),
          );

          expect(tester.takeException(), isNull);
          final label = validation == null ? '卡组未校验' : '卡组合规';
          final rect = tester.getRect(find.text(label));
          final selectorRect = tester.getRect(find.byType(DeckSelector));
          expect(rect.left, greaterThanOrEqualTo(selectorRect.left));
          expect(rect.right, lessThanOrEqualTo(selectorRect.right));
        },
      );
    }
  });

  testWidgets('interaction isolation excludes focused keyboard interaction', (
    tester,
  ) async {
    final key = GlobalKey<_PersistentProbeState>();
    Widget subject(bool active) => MaterialApp(
      home: InteractionIsolation(
        active: active,
        excludeSemantics: true,
        child: _PersistentProbe(key: key),
      ),
    );

    await tester.pumpWidget(subject(true));
    await tester.tap(find.text('probe'));
    expect(key.currentState!.taps, 1);
    key.currentState!.focusNode.requestFocus();
    await tester.pump();
    expect(key.currentState!.focusNode.hasFocus, isTrue);

    await tester.pumpWidget(subject(false));
    expect(key.currentState!.taps, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(key.currentState!.taps, 1);
    expect(key.currentState!.focusNode.hasFocus, isFalse);
    await tester.tap(find.text('probe'), warnIfMissed: false);
    expect(key.currentState!.taps, 1);
    expect(
      tester.widget<ExcludeFocus>(find.byType(ExcludeFocus)).excluding,
      isTrue,
    );

    await tester.pumpWidget(subject(true));
    await tester.tap(find.text('probe'));
    expect(key.currentState!.taps, 2);
  });

  testWidgets('hand choices expose enabled button semantics and callbacks', (
    tester,
  ) async {
    HandType? selected;
    await pumpResponsiveWidget(
      tester,
      HandSelect(onSendHand: (hand) => selected = hand),
      const Size(640, 360),
    );

    final finder = find.byKey(const ValueKey('hand-select-scissors'));
    final semantics = tester.getSemantics(finder);
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isEnabled, Tristate.isTrue);
    await tester.tap(finder);
    expect(selected, HandType.scissors);

    selected = null;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, isNotNull);
  });

  testWidgets(
    'disabled hand choices expose disabled semantics and do not fire',
    (tester) async {
      HandType? selected;
      await pumpResponsiveWidget(
        tester,
        HandSelect(enabled: false, onSendHand: (hand) => selected = hand),
        const Size(640, 360),
      );

      final finder = find.byKey(const ValueKey('hand-select-scissors'));
      final semantics = tester.getSemantics(finder);
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
      await tester.tap(finder, warnIfMissed: false);
      expect(selected, isNull);
    },
  );
}

class _PersistentProbe extends StatefulWidget {
  const _PersistentProbe({super.key});

  @override
  State<_PersistentProbe> createState() => _PersistentProbeState();
}

class _PersistentProbeState extends State<_PersistentProbe> {
  int taps = 0;
  final focusNode = FocusNode();

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      focusNode: focusNode,
      onPressed: () => setState(() => taps++),
      child: const Text('probe'),
    );
  }
}
