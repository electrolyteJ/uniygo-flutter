/// 对方怪兽攻守缺失的卡查库兜底测试。
///
/// 背景（截图实测）：对方召唤「宵星之机神 丁吉尔苏」后，场地徽章只显示
/// "ATK" 字样没有数值。协议上服务器不给非控制方推送该卡全量数据
/// （MZONE 快照 flag=0x3 只带 code+position；MSG_UPDATE_CARD 是
/// CTOS_UPDATE_CARD 回包，本客户端不发；攻守仅变化/战斗时广播），
/// 客户端 attack 恒为 null。官方客户端此处读本地 cards.cdb 基础值，
/// 本修复在卡信息入库后回退基础攻守（服务器当前值仍优先）。
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

/// 丁吉尔苏（93808927，2600/2100）；「?」怪（攻击 -2）用一个占位 code。
class _StubCardService extends ICardService {
  @override
  dynamic envType;
  @override
  Future<CardInfo?> getCard(int code) async {
    if (code == 93808927) {
      return const CardInfo(
        code: 93808927,
        type: 0x800021, // XYZ|效果
        attack: 2600,
        defense: 2100,
        name: '宵星之机神 丁吉尔苏',
        desc: '',
      );
    }
    if (code == 99999999) {
      return const CardInfo(
        code: 99999999,
        type: 0x21, // 效果怪兽
        attack: -2, // ?
        defense: -2,
        name: '问号怪',
        desc: '',
      );
    }
    if (code == 40605147) {
      // 神之宣告（陷阱）：攻守为 0，不得回填到魔陷区。
      return const CardInfo(
        code: 40605147,
        type: 0x20000,
        name: '神之宣告',
        desc: '',
      );
    }
    return null;
  }

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

/// 组一条 MZONE 快照线数据（flag=0x3：code+position，与服务器实测一致）。
Uint8List mzoneSnapshot(int player, List<(int code, int seq)> cards) {
  final msg = MsgUpdateData(
    player: player,
    zone: CARD_ZONE_MZONE,
    actions: [
      for (final (code, seq) in cards)
        MsgUpdateAction(
          flag: 0x3,
          code: code,
          location: CardLocation(
            controller: player,
            location: CARD_ZONE_MZONE,
            sequence: seq,
            position: POS_FACEUP_ATTACK,
          ),
        ),
    ],
    rawData: Uint8List(0),
  );
  return msg.encode();
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

  test('对方召唤丁吉尔苏：无服务器攻守 → 卡查库基础值兜底，服务器值后达仍优先', () async {
    // 对方（c:1）从墓地特殊召唤丁吉尔苏到 MZONE s4（MSG_MOVE 不含攻守）。
    notifier().applyMove(
      const MsgMove(
        code: 93808927,
        from: CardLocation(
            controller: 1, location: CARD_ZONE_GRAVE, sequence: 2, position: 8),
        to: CardLocation(
            controller: 1, location: CARD_ZONE_MZONE, sequence: 4, position: 1),
        reason: 2048,
      ),
    );
    const key = '1_4_4';
    expect(read().fieldCards[key]!.attack, isNull,
        reason: '截图实测：徽章只显示 ATK 字样（attack == null）');

    // 整区快照反复到达（flag=0x3 不带攻守），值仍然缺失。
    notifier().applyUpdateData(
      MsgUpdateData.decode(mzoneSnapshot(1, [(93808927, 4)])),
    );
    expect(read().fieldCards[key]!.attack, isNull);

    // 卡查库入库后回退基础攻守（applyMove 触发的 ensureCardInfo 异步完成）。
    await notifier().ensureCardInfo(93808927);
    expect(read().fieldCards[key]!.attack, 2600);
    expect(read().fieldCards[key]!.defense, 2100);

    // 后续整区重建不得丢值（fallback 链 base.attack 已非 null）。
    notifier().applyUpdateData(
      MsgUpdateData.decode(mzoneSnapshot(1, [(93808927, 4)])),
    );
    expect(read().fieldCards[key]!.attack, 2600);

    // 服务器之后推送的当前值（如被效果减半）覆盖基础值。
    notifier().applyUpdateCard(
      MsgUpdateCard(
        player: 1,
        zone: CARD_ZONE_MZONE,
        sequence: 4,
        chunkLength: null,
        rawData: Uint8List(0),
        action: const MsgUpdateAction(
          flag: 0x103, // code|position|attack
          code: 93808927,
          location: CardLocation(
              controller: 1,
              location: CARD_ZONE_MZONE,
              sequence: 4,
              position: 1),
          attack: 1300,
        ),
      ),
    );
    expect(read().fieldCards[key]!.attack, 1300, reason: '服务器当前值优先');
    expect(read().fieldCards[key]!.defense, 2100, reason: '未推送的字段保留');
  });

  test('魔陷区卡片不回填攻守；? 怪（负值）不兜底', () async {
    // 对方发动神之宣告（SZONE s3）。
    notifier().applyMove(
      const MsgMove(
        code: 40605147,
        from: CardLocation(
            controller: 1, location: CARD_ZONE_HAND, sequence: 0, position: 10),
        to: CardLocation(
            controller: 1, location: CARD_ZONE_SZONE, sequence: 3, position: 4),
        reason: 0,
      ),
    );
    await notifier().ensureCardInfo(40605147);
    expect(read().fieldCards['1_8_3']!.attack, isNull,
        reason: '魔陷不回填攻守（否则误显示 ATK 0）');

    // ? 怪（攻击 -2）：不兜底，保持 null（徽章维持现状只显示字样）。
    notifier().applyMove(
      const MsgMove(
        code: 99999999,
        from: CardLocation(
            controller: 0, location: CARD_ZONE_DECK, sequence: 0, position: 0),
        to: CardLocation(
            controller: 0, location: CARD_ZONE_MZONE, sequence: 0, position: 1),
        reason: 2048,
      ),
    );
    await notifier().ensureCardInfo(99999999);
    expect(read().fieldCards['0_4_0']!.attack, isNull);
  });
}
