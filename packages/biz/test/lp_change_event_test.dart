/// LP 变动事件流测试。
///
/// DuelFieldNotifier 在 handleDamage / handleRecover / handlePayLife /
/// handleLpUpdate 时除更新 LP 数值外，还要推一条 LpChangeEvent
/// （lpChangeTick 自增 + lpChangeEvent 记录最新一条），供 Flame 侧
/// LP 变动锚定 toast 按 tick diff 消费。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/models/lp_change_event.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resource_data/ygo_data.dart';

// ── 桩（对齐 field_start_lp_test） ──

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

  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(overrides: [
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
    container.read(duelFieldProvider.notifier).handleStart(
          const MsgStart(
            playerType: 0,
            life1: 8000,
            life2: 8000,
            deckSize1: 40,
            extraSize1: 15,
            deckSize2: 40,
            extraSize2: 15,
          ),
        );
  });

  tearDown(() => container.dispose());

  DuelFieldState read() => container.read(duelFieldProvider);
  DuelFieldNotifier notifier() => container.read(duelFieldProvider.notifier);

  group('LP 变动事件流', () {
    test('初始：无事件，tick 为 0', () {
      expect(read().lpChangeTick, 0);
      expect(read().lpChangeEvent, isNull);
    });

    test('handleDamage：kind=damage，delta 为负，tick 自增', () {
      notifier().handleDamage(const MsgDamage(player: 1, value: 2000));
      final e = read().lpChangeEvent!;
      expect(read().lpChangeTick, 1);
      expect(e.player, 1);
      expect(e.delta, -2000);
      expect(e.kind, LpChangeKind.damage);
    });

    test('handleRecover：kind=recover，delta 为正', () {
      notifier().handleRecover(const MsgRecover(player: 0, value: 500));
      final e = read().lpChangeEvent!;
      expect(e.player, 0);
      expect(e.delta, 500);
      expect(e.kind, LpChangeKind.recover);
    });

    test('handlePayLife：kind=pay，delta 为负', () {
      notifier().handlePayLife(const MsgPayLpCost(player: 0, value: 1000));
      final e = read().lpChangeEvent!;
      expect(e.player, 0);
      expect(e.delta, -1000);
      expect(e.kind, LpChangeKind.pay);
    });

    test('handleLpUpdate：kind=set，delta 为新旧差值', () {
      notifier().handleLpUpdate(const MsgLpUpdate(player: 1, newLp: 4000));
      final e = read().lpChangeEvent!;
      expect(e.player, 1);
      expect(e.delta, -4000);
      expect(e.kind, LpChangeKind.set);
    });

    test('handleLpUpdate 差值为 0：不发事件', () {
      notifier().handleLpUpdate(const MsgLpUpdate(player: 0, newLp: 8000));
      expect(read().lpChangeTick, 0);
      expect(read().lpChangeEvent, isNull);
    });

    test('连续变动：tick 单调自增，同帧保留最新一条', () {
      notifier().handleDamage(const MsgDamage(player: 1, value: 800));
      notifier().handleDamage(const MsgDamage(player: 1, value: 1200));
      expect(read().lpChangeTick, 2);
      expect(read().lpChangeEvent!.delta, -1200);
    });
  });
}
