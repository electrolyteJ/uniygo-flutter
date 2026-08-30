/// MSG_SELECT_PLACE 自动选位：连接怪兽优先额外怪兽区（EMZ）的回归测试。
///
/// 背景（线上实测日志）：己方连接召唤「幻兽机 曙光女神百头龙」时，对方
/// 已占用一个额外怪兽区，服务端下发
/// MSG_SELECT_PLACE(player, count:1, field:0xFFFFFFBD)，可用格为
/// 主怪兽区 s1 与 EMZ2（s6）。旧逻辑直接取 mask 位序的第一个可用格
/// （主区永远排在 EMZ 前），把 Link 怪兽放进主区 s1，导致百头龙无法
/// 发动生 3 个衍生物的效果（EMZ 起手展开被卡死）。
///
/// 修复后链路：MSG_HINT(selectMessage) 缓存待放置卡码 → applySelectPlace
/// 查询卡表，连接怪兽在可选格含 EMZ 时优先选 EMZ（先 6 后 5，
/// 与引擎自带 SIMPLE_AI 的 select_place 偏好一致）。
library;

import 'dart:typed_data';

import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_settings.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/ygo_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 幻兽机 曙光女神百头龙（连接怪兽，type 含 TYPE_LINK=0x4000000）。
const int _kAuroradon = 44097050;

/// 嵌合狂暴龙（融合怪兽，type 不含 TYPE_LINK）。
const int _kRampageDragon = 84058253;

/// 线协议位图：己方主怪兽区 s1 与额外怪兽区 s6（EMZ2）可用，
/// 其余置位不可用（0xFFFFFFBD，与实测日志一致）。
const int _kMaskMain1AndEmz2 = 4294967229;

/// 己方主怪兽区 s1 与额外怪兽区 s5（EMZ1）可用。
final int _kMaskMain1AndEmz1 =
    0xFFFFFFFF & ~((1 << 1) | (1 << 5)) & 0xFFFFFFFF;

class _StubCardService extends ICardService {
  _StubCardService(this._cards);

  final Map<int, CardInfo> _cards;

  @override
  dynamic envType;
  @override
  Future<CardInfo?> getCard(int code) async => _cards[code];
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
  CtosGameMsgResponse? lastResponse;

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
  void playGameResponse(CtosGameMsgResponse response) {
    lastResponse = response;
  }

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
  late _FakeDuelService duelService;
  late YgoDataService dataService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    duelService = _FakeDuelService();
    dataService = YgoDataService(
      cardService: _StubCardService({
        _kAuroradon: const CardInfo(
          code: _kAuroradon,
          // MONSTER|EFFECT|LINK
          type: 0x1 | 0x20 | 0x4000000,
          name: '幻兽机 曙光女神百头龙',
        ),
        _kRampageDragon: const CardInfo(
          code: _kRampageDragon,
          // MONSTER|EFFECT|FUSION
          type: 0x1 | 0x20 | 0x40,
          name: '嵌合狂暴龙',
        ),
      }),
      deckService: _StubDeckService(),
      banlistService: _StubBanlistService(),
    );
    container = ProviderContainer(overrides: [
      duelServiceProvider.overrideWithValue(duelService),
      dataServiceProvider.overrideWithValue(dataService),
      ygoSoundServiceProvider.overrideWithValue(YgoSoundService()),
    ]);
    // 打开「自动选择怪兽位置」全局设置，并预热卡表缓存
    // （getCardCached 只读已缓存数据）。
    container
        .read(ygoSettingsProvider.notifier)
        .setAutoMonsterPosition(true);
    await dataService.getCard(_kAuroradon);
    await dataService.getCard(_kRampageDragon);
  });
  tearDown(() => container.dispose());

  SelectWindowNotifier selectN() =>
      container.read(selectWindowProvider.notifier);

  CtosSelectPlace? lastPlace() => duelService.lastResponse?.selectPlace;

  test('连接召唤：可选格含 EMZ2 时自动放进 EMZ2 而非主区（回归）', () {
    selectN().setPendingPlaceCardCode(_kAuroradon);
    selectN().applySelectPlace(
      const MsgSelectPlace(player: 0, count: 1, field: _kMaskMain1AndEmz2),
    );

    final place = lastPlace();
    expect(place, isNotNull, reason: '自动选位必须已回包');
    expect(place!.zone, CARD_ZONE_MZONE);
    expect(place.sequence, 6, reason: '连接怪兽必须进额外怪兽区（EMZ2=s6）');
  });

  test('连接召唤：仅 EMZ1 可用时自动放进 EMZ1', () {
    selectN().setPendingPlaceCardCode(_kAuroradon);
    selectN().applySelectPlace(
      MsgSelectPlace(player: 0, count: 1, field: _kMaskMain1AndEmz1),
    );

    expect(lastPlace()?.zone, CARD_ZONE_MZONE);
    expect(lastPlace()?.sequence, 5);
  });

  test('非连接额外怪兽（融合）维持原行为：取第一个可用主区', () {
    selectN().setPendingPlaceCardCode(_kRampageDragon);
    selectN().applySelectPlace(
      const MsgSelectPlace(player: 0, count: 1, field: _kMaskMain1AndEmz2),
    );

    expect(lastPlace()?.zone, CARD_ZONE_MZONE);
    expect(
      lastPlace()?.sequence,
      1,
      reason: 'MR5 下融合/同调/超量应留在主区，不占 EMZ',
    );
  });

  test('无待放置卡码（服务端未下发提示）维持原行为：取第一个可用格', () {
    selectN().applySelectPlace(
      const MsgSelectPlace(player: 0, count: 1, field: _kMaskMain1AndEmz2),
    );

    expect(lastPlace()?.sequence, 1);
  });

  test('卡码不跨窗口残留：中间开过其它窗口后恢复默认选位', () {
    selectN().setPendingPlaceCardCode(_kAuroradon);
    // 中间插入一个非放置窗口（如是否发动效果），消费掉缓存的卡码。
    selectN().applySelectYesNo(
      const MsgSelectYesNo(player: 0, effectDescription: 0),
    );
    selectN().respondSelectYesNo(true);

    selectN().applySelectPlace(
      const MsgSelectPlace(player: 0, count: 1, field: _kMaskMain1AndEmz2),
    );
    expect(lastPlace()?.sequence, 1, reason: '残留卡码不得影响后续放置窗口');
  });
}
