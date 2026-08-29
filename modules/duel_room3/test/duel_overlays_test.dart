/// 选择窗口 HUD 的 widget 级测试。
///
/// 覆盖 code review 的对局级修复：
/// - 是/否弹窗「否」恒显（否则无法拒绝发动效果）；
/// - 选项落在墓地等不可点击区域时回退 modal 卡网格（否则软锁）；
/// - modal 有遮罩 + 可取消连锁显示「不连锁」出口。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:biz/widgets/card_image.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:duel_room3/hud/duel_overlays.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resource_data/ygo_data.dart';

// ── 桩（对齐 packages/biz/test 的测试基座） ──

class _StubCardService extends ICardService {
  @override
  dynamic envType;
  @override
  Future<CardInfo?> getCard(int code) async => null;
  @override
  Future<Uint8List> getCardImage(int code) => throw UnimplementedError();
  @override
  String getCardImageUrl(int code) => '';
  @override
  Future<List<CardInfo>> searchCards(String keyword) async => const [];
  @override
  Future<List<CardInfo>> searchCombined({
    String? query,
    int? cardType,
    int? attribute,
    int? race,
    int maxResults = 100,
  }) async => const [];
}

class _StubDeckService extends IDeckService {
  @override
  Future<List<DeckInfo>> loadDeckList() async => const [];
}

class _StubBanlistService extends IBanlistService {
  @override
  Future<LfTable?> getLfTable(int hash) async => null;
}

/// 记录回包的假决斗服务。
class _RecordingDuelService implements IDuelService {
  final responses = <CtosGameMsgResponse>[];

  @override
  void playGameResponse(CtosGameMsgResponse response) {
    responses.add(response);
  }

  @override
  Stream<RoomStage> get onRoomStageChange => const Stream.empty();
  @override
  Stream<YgoStocMsg> get onServerMessage => const Stream.empty();
  @override
  Stream<YgoStocMsg> get onChatServerMessage => const Stream.empty();
  @override
  Stream<DuelPhase> get onDuelPhaseMessage => const Stream.empty();
  @override
  ConnectionState get connectionState => ConnectionConnected();
  @override
  Future<void> connect(Uri address) async {}
  @override
  Future<void> disconnect() async {}
  @override
  void setPlayerName(String name) {}
  @override
  void enterRoom(String password) {}
  @override
  void submitDeck(Uint8List mainDeck, Uint8List extraDeck,
      [Uint8List? sideDeck]) {}
  @override
  void ready() {}
  @override
  void unready() {}
  @override
  void startDuel() {}
  @override
  void kickPlayer(int pos) {}
  @override
  void becomeObserver() {}
  @override
  void becomeDuelist() {}
  @override
  void chooseHand(HandType hand) {}
  @override
  void chooseTurnOrder(bool goFirst) {}
  @override
  void surrender() {}
  @override
  void confirmTime() {}
  @override
  void sendChat(String message) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingDuelService svc;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    svc = _RecordingDuelService();
    container = ProviderContainer(overrides: [
      duelServiceProvider.overrideWithValue(svc),
      dataServiceProvider.overrideWithValue(
        YgoDataService(
          cardService: _StubCardService(),
          deckService: _StubDeckService(),
          banlistService: _StubBanlistService(),
        ),
      ),
      ygoSoundServiceProvider.overrideWithValue(YgoSoundService()),
    ]);
  });
  tearDown(() => container.dispose());

  Future<void> pumpOverlay(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Stack(children: [DuelSelectOverlay()])),
        ),
      ),
    );
  }

  void openWindow(SelectState select) {
    container.read(selectWindowProvider.notifier).setSelect(select);
  }

  group('是否弹窗', () {
    testWidgets('「是」「否」按钮恒显，点「否」回 selectEffectYn(0)', (
      tester,
    ) async {
      await pumpOverlay(tester);
      // cancelable=false（biz 从不对 yesNo 设置 cancelable）：
      // 旧实现此时不显示「否」，玩家无法拒绝发动效果。
      openWindow(
        const SelectState(type: SelectType.yesNo, player: 0, min: 1, max: 1),
      );
      await tester.pump();

      expect(find.text('是'), findsOneWidget);
      expect(find.text('否'), findsOneWidget);

      await tester.tap(find.text('否'));
      await tester.pump();
      expect(svc.responses, hasLength(1));
      expect(svc.responses.single.selectEffectYnResult, 0);
    });

    testWidgets('effectYn 同样恒显「否」', (tester) async {
      await pumpOverlay(tester);
      openWindow(
        const SelectState(
          type: SelectType.effectYn,
          player: 0,
          min: 1,
          max: 1,
          options: [SelectOption(code: 89631139)],
        ),
      );
      await tester.pump();
      expect(find.text('否'), findsOneWidget);
      await tester.tap(find.text('是'));
      await tester.pump();
      expect(svc.responses.single.selectEffectYnResult, 1);
    });
  });

  group('modal 回退（选项在非可见区域）', () {
    testWidgets('墓地取对象的 card 选择弹卡网格而非软锁', (tester) async {
      await pumpOverlay(tester);
      openWindow(
        const SelectState(
          type: SelectType.card,
          player: 0,
          min: 1,
          max: 2,
          // 两个墓地选项（单个必选项会被 biz 的 isForcedSingleSelect
          // 自动代答，那不是弹窗路径）。
          options: [
            SelectOption(
              code: 89631139,
              controller: 0,
              zone: CARD_ZONE_GRAVE,
              sequence: 0,
            ),
            SelectOption(
              code: 46986414,
              controller: 0,
              zone: CARD_ZONE_GRAVE,
              sequence: 1,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CardGridSelectDialog), findsOneWidget);
      // 多选：勾选两张后确认
      await tester.tap(find.byType(CardImage).at(0));
      await tester.tap(find.byType(CardImage).at(1));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pump();
      expect(svc.responses.single.selectMultiPtrs, [0, 1]);
    });

    testWidgets('可取消连锁显示「不连锁」，点了回 -1', (tester) async {
      await pumpOverlay(tester);
      openWindow(
        const SelectState(
          type: SelectType.chain,
          player: 0,
          min: 0,
          max: 1,
          cancelable: true,
          options: [
            SelectOption(
              code: 46986414,
              controller: 0,
              zone: CARD_ZONE_GRAVE,
              sequence: 1,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('不连锁'), findsOneWidget);
      await tester.tap(find.text('不连锁'));
      await tester.pump();
      expect(svc.responses.single.selectSinglePtr, -1);
    });

    testWidgets('modal 有遮罩（阻断场地点击穿透）', (tester) async {
      await pumpOverlay(tester);
      openWindow(
        const SelectState(
          type: SelectType.card,
          player: 0,
          min: 1,
          max: 2,
          options: [
            SelectOption(
              code: 89631139,
              controller: 0,
              zone: CARD_ZONE_GRAVE,
              sequence: 0,
            ),
            SelectOption(
              code: 46986414,
              controller: 0,
              zone: CARD_ZONE_GRAVE,
              sequence: 1,
            ),
          ],
        ),
      );
      await tester.pump();
      // 65% 黑遮罩存在
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.color == Colors.black.withValues(alpha: 0.65),
        ),
        findsOneWidget,
      );
    });
  });

  group('CardGridSelectDialog', () {
    SelectState multiSelect() => const SelectState(
      type: SelectType.card,
      player: 0,
      min: 2,
      max: 2,
      options: [
        SelectOption(code: 89631139),
        SelectOption(code: 46986414),
        SelectOption(code: 15025844),
      ],
    );

    Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('多选：数量不足不能确认，选满后提交', (tester) async {
      List<int>? submitted;
      await tester.pumpWidget(
        wrap(
          CardGridSelectDialog(
            select: multiSelect(),
            title: '选择卡片',
            onSubmit: (indices) => submitted = indices,
          ),
        ),
      );
      // 未选满：确认禁用
      final confirmBefore = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '确认'),
      );
      expect(confirmBefore.onPressed, isNull);

      await tester.tap(find.byType(CardImage).at(0));
      await tester.tap(find.byType(CardImage).at(2));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pump();
      expect(submitted, [0, 2]);
    });

    testWidgets('排序模式：按点选顺序提交', (tester) async {
      List<int>? submitted;
      await tester.pumpWidget(
        wrap(
          CardGridSelectDialog(
            select: multiSelect(),
            title: '排序',
            ordered: true,
            submitLabel: '确认排序',
            onSubmit: (indices) => submitted = indices,
          ),
        ),
      );
      await tester.tap(find.byType(CardImage).at(2));
      await tester.tap(find.byType(CardImage).at(0));
      await tester.pump();
      // 未选满不可提交
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '确认排序 (2/3)'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(CardImage).at(1));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '确认排序 (3/3)'));
      await tester.pump();
      expect(submitted, [2, 0, 1]); // 保序
    });

    testWidgets('unselect：点卡即 toggle，finishable 时显示「完成」', (
      tester,
    ) async {
      final toggled = <int>[];
      var finished = false;
      await tester.pumpWidget(
        wrap(
          CardGridSelectDialog(
            select: const SelectState(
              type: SelectType.unselect,
              player: 0,
              min: 1,
              max: 1,
              finishable: true,
              immediateSingleToggle: true,
              // 模拟服务端一轮 toggle 后重开的窗口：已有 1 张勾选
              initialSelectedIndices: [0],
              options: [SelectOption(code: 89631139)],
            ),
            title: '解除选择',
            onImmediateTap: toggled.add,
            submitLabel: '完成',
            onSubmit: (_) => finished = true,
          ),
        ),
      );
      await tester.tap(find.byType(CardImage).first);
      expect(toggled, [0]);
      await tester.tap(find.widgetWithText(FilledButton, '完成'));
      await tester.pump();
      expect(finished, isTrue);
    });
  });
}
