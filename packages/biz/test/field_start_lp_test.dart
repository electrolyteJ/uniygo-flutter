/// MSG_START 初始 LP（startLp）记录测试。
///
/// 背景：room3 LP 条曾硬编码 maxLp=8000，match/tag 初始 LP 16000 时
/// 比例/分档全错。DuelFieldNotifier.handleStart 现在记录 startLp
/// （取双方初始 LP 最大值兜底），页面 LP 条以它为满格基准。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resource_data/ygo_data.dart';

// ── 桩（对齐 hand_result_hold_test） ──

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

MsgStart _msg({int playerType = 0, int life1 = 8000, int life2 = 8000}) =>
    MsgStart(
      playerType: playerType,
      life1: life1,
      life2: life2,
      deckSize1: 40,
      extraSize1: 15,
      deckSize2: 40,
      extraSize2: 15,
    );

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
  });

  tearDown(() => container.dispose());

  DuelFieldState read() => container.read(duelFieldProvider);

  group('handleStart 记录初始 LP', () {
    test('默认兜底：未开局时 startLp=8000', () {
      expect(read().startLp, 8000);
    });

    test('标准单局 8000：双方 LP 与 startLp 均为 8000', () {
      container.read(duelFieldProvider.notifier).handleStart(_msg());
      expect(read().selfLp, 8000);
      expect(read().opponentLp, 8000);
      expect(read().startLp, 8000);
    });

    test('match/tag 16000：startLp 记录真实初始 LP', () {
      container.read(duelFieldProvider.notifier).handleStart(
        _msg(life1: 16000, life2: 16000),
      );
      expect(read().startLp, 16000);
      expect(read().selfLp, 16000);
    });

    test('视角为引擎 1 号玩家：self/opponent 正确镜像，startLp 不变', () {
      container.read(duelFieldProvider.notifier).handleStart(
        _msg(playerType: 1, life1: 16000, life2: 16000),
      );
      expect(read().myController, 1);
      expect(read().selfLp, 16000);
      expect(read().startLp, 16000);
    });

    test('双方不等（非标准）：startLp 取最大值兜底', () {
      container.read(duelFieldProvider.notifier).handleStart(
        _msg(life1: 4000, life2: 8000),
      );
      expect(read().startLp, 8000);
    });
  });
}
