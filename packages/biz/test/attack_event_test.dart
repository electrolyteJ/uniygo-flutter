/// 攻击宣言事件序号（attackEventId）测试。
///
/// 背景：表现层（duel_room3 桥接）曾按 lastAttackFrom/To 字符串 diff
/// 播攻击动画——「同攻击方+同目标」的连续攻击在 900ms 清理窗口期内
/// 第二次无 diff 被吞。attackEventId 与 lpEventId 同构单调递增，
/// handleStart 局间清理 lastAttackFrom/To。
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

MsgAttack _attack({int to = 1}) => MsgAttack(
  attacker: const CardLocation(
    controller: 0,
    location: CARD_ZONE_MZONE,
    sequence: 0,
    position: 0x1,
  ),
  target: CardLocation(
    controller: 1,
    location: CARD_ZONE_MZONE,
    sequence: to,
    position: 0x1,
  ),
);

MsgStart _start() => const MsgStart(
  playerType: 0,
  life1: 8000,
  life2: 8000,
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
  DuelFieldNotifier notifier() => container.read(duelFieldProvider.notifier);

  group('attackEventId', () {
    test('默认 0', () {
      expect(read().attackEventId, 0);
    });

    test('同攻击方+同目标连续攻击：事件序号照涨（不被 diff 吞）', () {
      notifier().handleAttack(_attack());
      final first = read();
      expect(first.attackEventId, 1);
      expect(first.lastAttackFrom, isNotNull);

      // 清理计时器触发前的第二次同 key 攻击
      notifier().handleAttack(_attack());
      final second = read();
      expect(second.attackEventId, 2);
      expect(second.lastAttackFrom, first.lastAttackFrom);
      expect(second.lastAttackTo, first.lastAttackTo);
    });

    test('handleStart 清攻击残留（Match 局间）', () {
      notifier().handleAttack(_attack());
      expect(read().lastAttackFrom, isNotNull);

      notifier().handleStart(_start());
      expect(read().lastAttackFrom, isNull);
      expect(read().lastAttackTo, isNull);
      // attackEventId 不归零也无妨（单调递增语义），但残留 key 必须清掉
    });
  });
}
