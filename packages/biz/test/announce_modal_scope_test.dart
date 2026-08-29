/// MSG_ANNOUNCE_CARD 宣言窗口在房间 ProviderScope 下的呈现方式回归测试。
///
/// 背景（线上日志）：抹杀之指名者连锁发动后服务端下发 MSG_ANNOUNCE_CARD，
/// biz 侧 applyAnnounceCard 已执行（日志可见），但 duel_room1 页面没有
/// 弹出宣言弹窗，对局卡死。
library;

import 'dart:typed_data';

import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_derived.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/field_overlay_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/field_card.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resource_data/ygo_data.dart';

class _StubCardService extends ICardService {
  @override
  dynamic envType;

  @override
  Future<CardInfo?> getCard(int code) async =>
      CardInfo(code: code, type: 0x11, name: 'stub');

  @override
  Future<Uint8List> getCardImage(int code) => throw UnimplementedError();

  @override
  String getCardImageUrl(int code) => '';

  @override
  Future<List<CardInfo>> searchCards(String keyword) async => const [];

  @override
  Future<List<CardInfo>> searchCombined(
          {String? query,
          int? cardType,
          int? attribute,
          int? race,
          int maxResults = 100}) async =>
      const [];
}

class _StubDeckService extends IDeckService {
  @override
  Future<List<DeckInfo>> loadDeckList() async => const [];

  @override
  Future<DeckInfo?> loadDeck(String deckKey) async => null;
}

class _StubBanlistService extends IBanlistService {
  @override
  Future<LfTable?> getLfTable(int hash) async => null;
}

class _FakeDuelService implements IDuelService {
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
  void playGameResponse(CtosGameMsgResponse response) {}

  @override
  void surrender() {}

  @override
  void confirmTime() {}

  @override
  void sendChat(String message) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('房间 scope 内 applyAnnounceCard 后 selectPromptMode 应为 modal', () {
    SharedPreferences.setMockInitialValues({});
    // 模拟 DuelRoomPage 的容器结构：服务在应用级父容器（保持单例），
    // 房间级子状态在子容器 override（每次进房重建）。
    final appContainer = ProviderContainer(overrides: [
      duelServiceProvider.overrideWithValue(_FakeDuelService()),
      dataServiceProvider.overrideWithValue(
        YgoDataService(
          cardService: _StubCardService(),
          deckService: _StubDeckService(),
          banlistService: _StubBanlistService(),
        ),
      ),
      ygoSoundServiceProvider.overrideWithValue(YgoSoundService()),
    ]);
    final roomContainer = ProviderContainer(parent: appContainer, overrides: [
      duelRoomProvider.overrideWith(DuelRoomNotifier.new),
      duelFieldProvider.overrideWith(DuelFieldNotifier.new),
      selectWindowProvider.overrideWith(SelectWindowNotifier.new),
      cardConfirmProvider.overrideWith(CardConfirmNotifier.new),
      fieldOverlayProvider.overrideWith(FieldOverlayNotifier.new),
    ]);
    addTearDown(() {
      roomContainer.dispose();
      appContainer.dispose();
    });

    roomContainer.read(selectWindowProvider.notifier).applyAnnounceCard(
          const MsgAnnounceCard(player: 0, count: 0, codes: []),
        );

    expect(
      roomContainer.read(selectWindowProvider).currentSelect?.type,
      SelectType.announceCard,
      reason: '宣言窗口应已开在房间 scope 的 selectWindowProvider 上',
    );
    expect(
      roomContainer.read(selectPromptModeProvider),
      SelectPromptMode.modal,
      reason: '页面按 selectPromptModeProvider 决定是否挂载模态弹窗',
    );
  });

  test('手写 dependencies 的派生 provider 在房间 scope 内正确重解析', () {
    SharedPreferences.setMockInitialValues({});
    final appContainer = ProviderContainer(overrides: [
      duelServiceProvider.overrideWithValue(_FakeDuelService()),
      dataServiceProvider.overrideWithValue(
        YgoDataService(
          cardService: _StubCardService(),
          deckService: _StubDeckService(),
          banlistService: _StubBanlistService(),
        ),
      ),
      ygoSoundServiceProvider.overrideWithValue(YgoSoundService()),
    ]);
    final roomContainer = ProviderContainer(parent: appContainer, overrides: [
      duelRoomProvider.overrideWith(DuelRoomNotifier.new),
      duelFieldProvider.overrideWith(DuelFieldNotifier.new),
      selectWindowProvider.overrideWith(SelectWindowNotifier.new),
      cardConfirmProvider.overrideWith(CardConfirmNotifier.new),
      fieldOverlayProvider.overrideWith(FieldOverlayNotifier.new),
    ]);
    addTearDown(() {
      roomContainer.dispose();
      appContainer.dispose();
    });

    // 手写派生 provider（与生成版同逻辑，但显式声明 dependencies）。
    final scopedModeProvider = Provider<SelectPromptMode>(
      (ref) => resolveSelectPromptMode(
        ref.watch(selectWindowProvider),
        ref.watch(duelFieldProvider),
      ),
      dependencies: [selectWindowProvider, duelFieldProvider],
    );

    roomContainer.read(selectWindowProvider.notifier).applyAnnounceCard(
          const MsgAnnounceCard(player: 0, count: 0, codes: []),
        );

    expect(
      roomContainer.read(scopedModeProvider),
      SelectPromptMode.modal,
      reason: '显式 dependencies 应触发房间 scope 内的重解析',
    );
    // 同一 provider 在根容器读到根状态（互不影响）。
    expect(appContainer.read(scopedModeProvider), SelectPromptMode.none);
  });

  // ── 攻击对象选择应走就地选择（不弹窗）的回归 ──

  test('攻击对象（对方场上怪兽）窗口应解析为 inline 而非 modal', () {
    // 构造：对方（controller=1）怪兽区 0/1 号位各一张卡在场。
    const board = DuelFieldState(
      myController: 0,
      fieldCards: {
        '1_4_0': FieldCard(
          code: 46986414,
          controller: 1,
          zone: CARD_ZONE_MZONE,
          sequence: 0,
          position: 0x1,
        ),
        '1_4_1': FieldCard(
          code: 70781052,
          controller: 1,
          zone: CARD_ZONE_MZONE,
          sequence: 1,
          position: 0x1,
        ),
      },
    );
    const select = SelectWindowState(
      currentSelect: SelectState(
        type: SelectType.card,
        player: 0,
        min: 1,
        max: 1,
        options: [
          SelectOption(
            code: 46986414,
            controller: 1,
            zone: CARD_ZONE_MZONE,
            sequence: 0,
          ),
          SelectOption(
            code: 70781052,
            controller: 1,
            zone: CARD_ZONE_MZONE,
            sequence: 1,
          ),
        ],
      ),
    );
    expect(
      resolveSelectPromptMode(select, board),
      SelectPromptMode.inline,
      reason: '攻击对象都在对方怪兽区，应直接点选场上怪兽，不弹窗',
    );
  });
}
