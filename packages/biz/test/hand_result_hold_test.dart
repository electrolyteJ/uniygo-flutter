/// 猜拳结果（RoomHandResult）最短展示时长测试。
///
/// 背景：结果面板完全由服务器下一条消息驱动退出，AI 房/低延迟网络下
/// HAND_RESULT → SELECT_TP/MSG_START 只有几毫秒，结果一闪而过。
/// biz 层对紧随其后的启动流程阶段做最短停留兜底
/// （[DuelRoomNotifier.handResultMinDisplay]）。
///
/// 数据/声音服务用桩实现，决斗服务用内存假实现（直接发阶段事件）。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ygo_data/ygo_data.dart';

// ── 桩：卡片/卡组/禁限表服务（对齐 match_siding_233_test） ──

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
  Future<List<DeckInfo>> loadDeckList() async => [
        DeckInfo(
          deckName: 'stub-deck',
          mainDeck: const [DeckCard(code: 89631139)],
        ),
      ];

  @override
  Future<DeckInfo?> loadDeck(String deckKey) async =>
      (await loadDeckList()).first;
}

class _StubBanlistService extends IBanlistService {
  @override
  Future<LfTable?> getLfTable(int hash) async => null;
}

/// 内存假决斗服务：测试直接向房间阶段流发事件。
class _FakeDuelService implements IDuelService {
  final _stageCtl = StreamController<RoomStage>();
  final _msgCtl = StreamController<YgoStocMsg>();

  void emitStage(RoomStage stage) => _stageCtl.add(stage);

  @override
  Stream<RoomStage> get onRoomStageChange => _stageCtl.stream;

  @override
  Stream<YgoStocMsg> get onServerMessage => _msgCtl.stream;

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

  const hold = DuelRoomNotifier.handResultMinDisplay;
  const margin = Duration(milliseconds: 300);

  late _FakeDuelService svc;
  late ProviderContainer container;

  DuelRoomState readState() => container.read(duelRoomProvider);

  /// 等异步流事件送达（StreamController 为异步广播）。
  Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    svc = _FakeDuelService();
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
    container.read(duelRoomProvider.notifier).start();
  });

  tearDown(() {
    container.dispose();
  });

  test('结果展示不足最短时长：后继 RoomInDuel 被拦下，到期后才推进', () async {
    svc.emitStage(const RoomSelectingHand());
    await pump();
    svc.emitStage(const RoomHandResult(myHand: 2, opponentHand: 1));
    await pump();
    expect(readState().stage, isA<RoomHandResult>());
    expect(readState().myHandResult, 2);
    expect(readState().opponentHandResult, 1);

    // 服务器立刻推进（AI 房典型时序）：应被停留闸门拦下。
    svc.emitStage(const RoomInDuel(isFirstTurn: true));
    await pump();
    expect(readState().stage, isA<RoomHandResult>(), reason: '展示不足时应停留');

    await Future<void>.delayed(hold + margin);
    expect(readState().stage, isA<RoomInDuel>(), reason: '到期后应推进');
    expect(readState().isFirstTurn, isTrue);
    // 进入对局后猜拳结果被清空。
    expect(readState().myHandResult, 0);
  });

  test('结果展示已满最短时长：后继阶段立即生效', () async {
    svc.emitStage(const RoomHandResult(myHand: 1, opponentHand: 3));
    await pump();
    await Future<void>.delayed(hold + margin);

    svc.emitStage(const RoomSelectingTurn());
    await pump();
    expect(readState().stage, isA<RoomSelectingTurn>());
  });

  test('停留期间多条后继阶段：只应用最新一条（RoomStartDuel 被 RoomInDuel 取代）',
      () async {
    svc.emitStage(const RoomHandResult(myHand: 1, opponentHand: 3));
    await pump();
    svc.emitStage(const RoomStartDuel());
    svc.emitStage(const RoomInDuel(isFirstTurn: false));
    await pump();
    expect(readState().stage, isA<RoomHandResult>());

    await Future<void>.delayed(hold + margin);
    final stage = readState().stage;
    expect(stage, isA<RoomInDuel>());
    expect((stage as RoomInDuel).isFirstTurn, isFalse);
  });

  test('平局重猜：停留到期后回到 RoomSelectingHand', () async {
    svc.emitStage(const RoomSelectingHand());
    await pump();
    svc.emitStage(const RoomHandResult(myHand: 3, opponentHand: 3));
    await pump();
    svc.emitStage(const RoomSelectingHand());
    await pump();
    expect(readState().stage, isA<RoomHandResult>());

    await Future<void>.delayed(hold + margin);
    expect(readState().stage, isA<RoomSelectingHand>());
  });

  test('停留期间被非启动流程打断（离房）：拦下的后继阶段被丢弃、不复活', () async {
    svc.emitStage(const RoomHandResult(myHand: 2, opponentHand: 3));
    await pump();
    svc.emitStage(const RoomInDuel(isFirstTurn: true));
    await pump();
    svc.emitStage(const RoomNotJoined());
    await pump();
    expect(readState().stage, isA<RoomNotJoined>());

    await Future<void>.delayed(hold + margin);
    expect(readState().stage, isA<RoomNotJoined>(), reason: '过期阶段不得复活');
  });
}
