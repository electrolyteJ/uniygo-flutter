@Timeout(Duration(minutes: 6))
library;

/// biz 层 match（三局两胜）局间流程测试 —— 真实 233 服 AI 房 + 真实
/// DuelRoomNotifier（含 confirmSiding 换备提交路径），定位「换备后第二局
/// 不重开」是否发生在 biz 层。
///
/// 数据服务用桩实现（卡组/卡信息/禁限表），决斗服务用真实
/// SocketDuelService 连 s1.ygo233.com:233，并对出站包打印留证。
import 'dart:async';
import 'dart:typed_data';

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:duelink_socket/duelink_socket.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ygo_data/ygo_data.dart';

// ── 桩：卡片/卡组/禁限表服务 ──

class _StubCardService extends ICardService {
  @override
  dynamic envType;

  @override
  Future<CardInfo?> getCard(int code) async =>
      CardInfo(code: code, type: 0x11, name: 'stub-$code');

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

const _fillers = <int>[
  89631139, 46986414, 13039848, 6368038, 28279543, 74677422, 88819587,
  76184692, 41392891, 15303296, 87796900, 32452818, 89631139, 46986414,
  13039848, 6368038, 28279543, 74677422, 88819587, 76184692, 41392891,
  15303296, 87796900, 32452818, 89631139, 46986414, 13039848, 6368038,
  28279543, 74677422, 88819587, 76184692, 41392891, 15303296, 87796900,
  32452818, 89631139, 46986414, 13039848,
];

class _StubDeckService extends IDeckService {
  @override
  Future<List<DeckInfo>> loadDeckList() async => [
        DeckInfo(
          deckName: 'stub-deck',
          mainDeck: _fillers.map((c) => DeckCard(code: c)).toList(),
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

/// 出站包间谍：打印关键的房间/对局动作，证明包确实发出。
class _SpySocketService extends SocketDuelService {
  @override
  void submitDeck(Uint8List mainDeck, Uint8List extraDeck,
      [Uint8List? sideDeck]) {
    // ignore: avoid_print
    print('[out] submitDeck main=${mainDeck.length}B extra=${extraDeck.length}B side=${sideDeck?.length ?? 0}B');
    super.submitDeck(mainDeck, extraDeck, sideDeck);
  }

  @override
  void ready() {
    // ignore: avoid_print
    print('[out] ready');
    super.ready();
  }

  @override
  void startDuel() {
    // ignore: avoid_print
    print('[out] startDuel');
    super.startDuel();
  }

  @override
  void chooseHand(HandType hand) {
    // ignore: avoid_print
    print('[out] chooseHand $hand');
    super.chooseHand(hand);
  }

  @override
  void chooseTurnOrder(bool goFirst) {
    // ignore: avoid_print
    print('[out] chooseTurnOrder $goFirst');
    super.chooseTurnOrder(goFirst);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('biz 全链路: 233 AI match 换备后第二局应重开', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = _SpySocketService();
    final container = ProviderContainer(overrides: [
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
    addTearDown(() async {
      if (svc.connectionState is ConnectionConnected) {
        svc.surrender();
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      await svc.disconnect();
      container.dispose();
    });

    final roomN = container.read(duelRoomProvider.notifier);
    final states = <DuelRoomState>[];
    container.listen(duelRoomProvider, (prev, next) {
      if (prev?.stage.runtimeType != next.stage.runtimeType) {
        // ignore: avoid_print
        print('[biz stage] ${next.stage.runtimeType}');
      }
      states.add(next);
      // 反应式驱动：猜拳/选先攻自动应答（与 UI 手动等价）。
      if (next.stage is RoomSelectingHand &&
          (states.length < 2 || states[states.length - 2].stage is! RoomSelectingHand)) {
        roomN.sendHand(HandType.rock);
      }
      if (next.stage is RoomSelectingTurn &&
          (states.length < 2 || states[states.length - 2].stage is! RoomSelectingTurn)) {
        roomN.sendTp(true);
      }
    });

    DuelRoomState s() => container.read(duelRoomProvider);

    Future<void> waitFor(bool Function(DuelRoomState) p, String hint,
        {Duration timeout = const Duration(seconds: 30)}) async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (p(s())) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      throw TimeoutException(
          'wait $hint; stage=${s().stage.runtimeType}');
    }

    // ── 连接 + 进 AI 房（match）──
    await svc.connect(Uri.parse('tcp://s1.ygo233.com:233'));
    svc.setPlayerName('BizProbe');
    svc.enterRoom('AI,M,MR5,NC,NS');
    roomN.start();
    await waitFor((st) => st.stage is RoomInLobby, 'RoomInLobby');
    await Future<void>.delayed(const Duration(seconds: 2));
    if (s().players.length < 2) svc.sendChat('/ai');
    await waitFor((st) => st.players.length >= 2, 'AI 进房',
        timeout: const Duration(seconds: 20));

    // ── 卡组加载（桩）→ 准备 → 开局 ──
    await waitFor((st) => st.selectedDeckName != null, '卡组列表就绪');
    final readyError = await roomN.toggleReady();
    expect(readyError, isNull, reason: '准备失败: $readyError');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    roomN.startDuel();

    // ── 第一局 ──
    await waitFor((st) => st.stage is RoomInDuel, '第一局 RoomInDuel',
        timeout: const Duration(seconds: 60));

    // ── 投降结束第一局 → 换备阶段 → biz 初始化换备数据 ──
    svc.surrender();
    await waitFor((st) => st.stage is RoomSideDecking, 'RoomSideDecking',
        timeout: const Duration(seconds: 20));
    await waitFor((st) => st.sidingDeck != null || st.sidingInitFailed,
        '换备数据初始化');
    expect(s().sidingInitFailed, isFalse, reason: '换备初始化不应失败');
    expect(s().sidingDeck, isNotNull);

    // ── 确认换备（与 UI 按钮同路径）──
    final sidingError = await roomN.confirmSiding();
    expect(sidingError, isNull, reason: '确认换备失败: $sidingError');

    // ── 期望第二局重开 ──
    await waitFor((st) => st.stage is RoomInDuel, '第二局 RoomInDuel',
        timeout: const Duration(seconds: 45));
    // ignore: avoid_print
    print('[result] 第二局已进入 RoomInDuel，biz 链路 OK');
  });
}
