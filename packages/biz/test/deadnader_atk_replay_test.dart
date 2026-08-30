/// 日志重放测试：雷火沸动死旋爆震机（34909328，超量）召唤到 MZONE s5 后，
/// 右上角 ATK 徽章所需的 attack 字段必须在场。
library;

import 'dart:typed_data';

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/ygo_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });
  tearDown(() => container.dispose());

  DuelFieldState read() => container.read(duelFieldProvider);
  DuelFieldNotifier notifier() => container.read(duelFieldProvider.notifier);

  test('死旋爆震机召唤到 s5 后 attack 在整区重建后仍为 3100', () {
    // 1. MSG_MOVE：EXTRA s9 → MZONE s5（表侧攻击表示）
    notifier().applyMove(
      const MsgMove(
        code: 34909328,
        from: CardLocation(
            controller: 0, location: CARD_ZONE_EXTRA, sequence: 9, position: 8),
        to: CardLocation(
            controller: 0, location: CARD_ZONE_MZONE, sequence: 5, position: 1),
        reason: 2048,
      ),
    );
    const key = '0_4_5';
    expect(read().fieldCards[key], isNotNull);
    expect(read().fieldCards[key]!.attack, isNull,
        reason: 'MOVE 阶段尚无攻守，徽章只显示 ATK 字样');

    // 2. MSG_UPDATE_CARD：全量数据（atk=3100 def=2500）
    notifier().applyUpdateCard(
      MsgUpdateCard(
        player: 0,
        zone: CARD_ZONE_MZONE,
        sequence: 5,
        chunkLength: null,
        rawData: Uint8List(0),
        action: const MsgUpdateAction(
          flag: 0xf81fff,
          code: 34909328,
          location: CardLocation(
              controller: 0,
              location: CARD_ZONE_MZONE,
              sequence: 5,
              position: 1),
          attack: 3100,
          defense: 2500,
          baseAttack: 3000,
          baseDefense: 2500,
          rank: 4,
          type: 8388641,
          attribute: 16,
          race: 128,
          alias: 34909328,
          reason: 2048,
          status: 0,
          lscale: 0,
          rscale: 0,
          link: 0,
        ),
      ),
    );
    expect(read().fieldCards[key]!.attack, 3100);

    // 3/4. MSG_UPDATE_DATA MZONE 快照（encode→decode 全链路）
    Uint8List snapshotWire(int deadnaderFlag) {
      final msg = MsgUpdateData(
        player: 0,
        zone: CARD_ZONE_MZONE,
        actions: [
          const MsgUpdateAction(
            flag: 0x3,
            code: 7511613,
            location: CardLocation(
                controller: 0,
                location: CARD_ZONE_MZONE,
                sequence: 2,
                position: 1),
          ),
          MsgUpdateAction(
            flag: deadnaderFlag,
            code: 34909328,
            location: const CardLocation(
                controller: 0,
                location: CARD_ZONE_MZONE,
                sequence: 5,
                position: 1),
            status: deadnaderFlag == 0x80003 ? 8 : null,
          ),
        ],
        rawData: Uint8List(0),
      );
      return msg.encode();
    }

    notifier().applyUpdateData(MsgUpdateData.decode(snapshotWire(0x80003)));
    expect(read().fieldCards[key]!.attack, 3100,
        reason: '第一次整区重建后 attack 必须由 fallback 保留');
    expect(read().fieldCards[key]!.defense, 2500);

    notifier().applyUpdateData(MsgUpdateData.decode(snapshotWire(0x3)));
    expect(read().fieldCards[key]!.attack, 3100,
        reason: '第二次整区重建后 attack 必须保留');

    // 5. 徽章渲染条件核对：表侧 → 非里侧；EMZ 槽位解析兜底 self 0_4_5。
    final card = read().fieldCards[key]!;
    expect(card.position & POS_FACEDOWN, 0, reason: '表侧卡徽章必须渲染');
    final resolved = read().fieldCards['1_4_6'] ?? read().fieldCards['0_4_5'];
    expect(resolved, isNotNull);
    expect(resolved!.attack, 3100,
        reason: 'EMZ 槽位解析到的卡必须带 attack，徽章显示 ATK 3100');
  });
}
