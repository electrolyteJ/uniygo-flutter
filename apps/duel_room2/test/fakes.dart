import 'dart:async';
import 'dart:typed_data';

import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:ygo_data/ygo_data.dart';

/// 记录 [submitDeck] / [ready] / [unready] 调用的假决斗服务。
///
/// 通过 [stageController] 向订阅方（DuelRoomNotifier.start）推送房间阶段。
class RecordingDuelService implements IDuelService {
  final List<({Uint8List main, Uint8List extra, Uint8List? side})>
      submittedDecks = [];
  int readyCount = 0;
  int unreadyCount = 0;

  final StreamController<RoomStage> stageController =
      StreamController<RoomStage>.broadcast();
  final StreamController<YgoStocMsg> _msgController =
      StreamController<YgoStocMsg>.broadcast();

  void emitStage(RoomStage stage) => stageController.add(stage);

  @override
  void submitDeck(Uint8List mainDeck, Uint8List extraDeck,
      [Uint8List? sideDeck]) {
    submittedDecks.add((main: mainDeck, extra: extraDeck, side: sideDeck));
  }

  @override
  void ready() => readyCount++;

  @override
  void unready() => unreadyCount++;

  @override
  Stream<YgoStocMsg> get onServerMessage => _msgController.stream;

  @override
  Stream<YgoStocMsg> get onChatServerMessage => const Stream.empty();

  @override
  Stream<RoomStage> get onRoomStageChange => stageController.stream;

  @override
  Stream<DuelPhase> get onDuelPhaseMessage => const Stream.empty();

  @override
  ConnectionState get connectionState => ConnectionState.connected;

  // ── 其余接口：测试中不参与断言，空实现 ──

  @override
  Future<void> connect(Uri address) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void setPlayerName(String name) {}

  @override
  void enterRoom(String password) {}

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

/// 按 code 直接生成卡信息的假卡片服务。
///
/// [hang] 为 true 时 [getCard] 永不返回（模拟加载未完成，
/// 用于测试换备数据未就绪的窗口）。
class FakeCardService implements ICardService {
  final Map<int, CardInfo> overrides;
  bool hang = false;

  FakeCardService({Map<int, CardInfo>? overrides})
      : overrides = overrides ?? {};

  @override
  dynamic get envType => null;

  @override
  set envType(dynamic value) {}

  @override
  String getCardImageUrl(int code) => '';

  @override
  Future<Uint8List> getCardImage(int code) async => Uint8List(0);

  @override
  Future<CardInfo?> getCard(int code) {
    if (hang) return Completer<CardInfo?>().future;
    return Future.value(
      overrides[code] ?? CardInfo(code: code, type: 0x1, name: '卡片$code'),
    );
  }

  @override
  Future<List<CardInfo>> searchCards(String keyword) async => const [];

  @override
  Future<List<CardInfo>> searchCombined({
    String? query,
    int? cardType,
    int? attribute,
    int? race,
    int maxResults = 100,
  }) async =>
      const [];
}

/// 内存卡组列表的假卡组服务。
class FakeDeckService implements IDeckService {
  final List<DeckInfo> decks;

  FakeDeckService({List<DeckInfo>? decks}) : decks = decks ?? [];

  @override
  Future<List<DeckInfo>> loadDeckList() async => decks;

  @override
  Future<DeckInfo?> loadDeck(String deckKey) async {
    for (final d in decks) {
      if (d.deckName == deckKey) return d;
    }
    return null;
  }

  @override
  Future<bool> saveDeck(DeckInfo deck) async => true;

  @override
  Future<bool> deleteDeck(String deckKey) async => true;

  @override
  String exportToYdk(DeckInfo deck) => '';

  @override
  Future<DeckInfo?> importFromYdk(String content, String deckKey) async =>
      null;
}

/// 可控禁限表的假禁限服务：[table] 为 null 时表示「无禁限表」。
class FakeBanlistService implements IBanlistService {
  LfTable? table;

  @override
  List<String> validateDeck(
    List<CardInfo> main,
    List<CardInfo> extra,
    List<CardInfo> side,
  ) =>
      const [];

  @override
  Future<Map<int, LfTable>> getAllLfTable() async =>
      table == null ? {} : {table!.hash: table!};

  @override
  Future<LfTable?> getLfTable(int hash) async => table;
}
