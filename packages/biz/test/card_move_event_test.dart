/// CardMoveEvent 生成矩阵测试（applyMove → 飞牌事件）。
///
/// 断言矩阵：各方向移动生成事件 / 涉及对方手牌隐私 code=0 /
/// 抽卡（卡组→手牌）不生成（走 drawAnimationEvent 管线）/ tick 单调。
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
import 'package:ygo_data/ygo_data.dart';

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

CardLocation loc(int controller, int location, int sequence) => CardLocation(
  controller: controller,
  location: location,
  sequence: sequence,
  position: 0x1,
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
    // 锚定己方 controller=0
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

  void move(int code, CardLocation from, CardLocation to) {
    notifier().applyMove(MsgMove(code: code, from: from, to: to, reason: 0));
  }

  group('CardMoveEvent 生成矩阵', () {
    test('手牌→墓地：生成事件，code 保留', () {
      move(89631139, loc(0, CARD_ZONE_HAND, 0), loc(0, CARD_ZONE_GRAVE, 0));
      final e = read().cardMoveEvent;
      expect(e, isNotNull);
      expect(e!.code, 89631139);
      expect(e.fromLocation, CARD_ZONE_HAND);
      expect(e.toLocation, CARD_ZONE_GRAVE);
      expect(read().cardMoveTick, e.id);
    });

    test('墓地→手牌 / 场上→墓地 / 墓地→场上 / 场上→手牌：都生成', () {
      move(100, loc(0, CARD_ZONE_GRAVE, 0), loc(0, CARD_ZONE_HAND, 0));
      expect(read().cardMoveEvent!.toLocation, CARD_ZONE_HAND);
      move(200, loc(0, CARD_ZONE_MZONE, 0), loc(0, CARD_ZONE_GRAVE, 0));
      expect(read().cardMoveEvent!.fromLocation, CARD_ZONE_MZONE);
      move(300, loc(0, CARD_ZONE_GRAVE, 1), loc(0, CARD_ZONE_MZONE, 2));
      expect(read().cardMoveEvent!.toLocation, CARD_ZONE_MZONE);
      move(400, loc(0, CARD_ZONE_MZONE, 1), loc(0, CARD_ZONE_HAND, 0));
      expect(read().cardMoveEvent!.toLocation, CARD_ZONE_HAND);
    });

    test('涉及对方手牌：code 置 0（隐私）', () {
      // 对方手牌 → 对方墓地
      move(89631139, loc(1, CARD_ZONE_HAND, 0), loc(1, CARD_ZONE_GRAVE, 0));
      expect(read().cardMoveEvent!.code, 0);
      // 对方墓地 → 对方手牌
      move(89631139, loc(1, CARD_ZONE_GRAVE, 0), loc(1, CARD_ZONE_HAND, 0));
      expect(read().cardMoveEvent!.code, 0);
    });

    test('对方区域间移动（不涉及手牌）：code 保留', () {
      move(89631139, loc(1, CARD_ZONE_MZONE, 0), loc(1, CARD_ZONE_GRAVE, 0));
      expect(read().cardMoveEvent!.code, 89631139);
    });

    test('抽卡（卡组→手牌）不生成 CardMoveEvent', () {
      // 己方抽卡
      move(89631139, loc(0, CARD_ZONE_DECK, 0), loc(0, CARD_ZONE_HAND, 0));
      expect(read().cardMoveEvent, isNull);
      // 对方抽卡：走既有 drawAnimationEvent 管线
      move(0, loc(1, CARD_ZONE_DECK, 0), loc(1, CARD_ZONE_HAND, 0));
      expect(read().cardMoveEvent, isNull);
      expect(read().drawAnimationEvent, isNotNull);
    });

    test('tick 单调递增', () {
      move(1, loc(0, CARD_ZONE_MZONE, 0), loc(0, CARD_ZONE_GRAVE, 0));
      move(2, loc(0, CARD_ZONE_MZONE, 1), loc(0, CARD_ZONE_GRAVE, 1));
      move(3, loc(0, CARD_ZONE_GRAVE, 0), loc(0, CARD_ZONE_REMOVED, 0));
      expect(read().cardMoveTick, 3);
      expect(read().cardMoveEvent!.id, 3);
    });

    test('msg.code<=0 时从 from 位置字段卡补充卡码', () {
      // 先放一张字段卡（经 MSG_MOVE 上场无法直接构造，用 copyWith 快照）
      // —— 里侧怪被送墓时 MSG_MOVE 的 code 为 0，但场上已知卡码。
      // 这里通过先一次带码 move 上场（hand→mzone）建立字段卡，
      // 再一次 code=0 的 move 送墓验证补充逻辑。
      move(46986414, loc(0, CARD_ZONE_HAND, 0), loc(0, CARD_ZONE_MZONE, 0));
      move(0, loc(0, CARD_ZONE_MZONE, 0), loc(0, CARD_ZONE_GRAVE, 0));
      expect(read().cardMoveEvent!.code, 46986414);
    });
  });
}
