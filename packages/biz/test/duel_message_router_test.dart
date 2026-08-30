/// 对局消息节奏泵在 DuelMessageRouter 的接线测试。
///
/// 背景：竞技观战中途加入时服务器一次性推送开局以来的全部消息，
/// 收到即分发导致 UI 瞬间刷新几百次。router 现经 MessagePump 按自适应
/// 节奏消费：空闲直通、爆发降档、MSG_START 清队、TIME_LIMIT 绕过队列，
/// MSG_NEW_PHASE 并入队列与画面同源同节奏（不再走 onDuelPhaseMessage
/// 独立流）。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/duel_message_router.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_settings.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/ygo_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }) async =>
      const [];
}

class _StubDeckService extends IDeckService {
  @override
  Future<List<DeckInfo>> loadDeckList() async => const [];
}

class _StubBanlistService extends IBanlistService {
  @override
  Future<LfTable?> getLfTable(int hash) async => null;
}

/// 同步广播消息流的假决斗服务：emit 即送达 listener（无事件循环跳跃），
/// 便于在 fakeAsync 里精确控制入队时序。
class _FakeDuelService implements IDuelService {
  final _msgController = StreamController<YgoStocMsg>.broadcast(sync: true);

  void emit(YgoStocMsg msg) => _msgController.add(msg);

  @override
  Stream<YgoStocMsg> get onServerMessage => _msgController.stream;
  @override
  Stream<RoomStage> get onRoomStageChange => const Stream.empty();
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

/// 开启「跳到当前局面」的设置桩。
class _JumpSettingsNotifier extends YgoSettingsNotifier {
  @override
  YgoSettings build() => const YgoSettings(spectateJumpToCurrent: true);
}

/// 记录音效调用时刻 suppress 状态的音效服务：router 的静音包装
/// 在调用 play* 前应已置位 suppress。
class _RecordingSoundService extends YgoSoundService {
  final List<bool> newPhaseSuppressStates = [];
  int duelStartCount = 0;

  @override
  Future<void> playNewPhase() async {
    newPhaseSuppressStates.add(suppress);
  }

  @override
  Future<void> playDuelStart() async {
    duelStartCount++;
  }
}

YgoStocMsg _startMsg() => YgoStocMsg.gameMsg(
      const StocGameMessage(
        func: MSG_START,
        innerMsg: MsgStart(
          playerType: 0,
          life1: 8000,
          life2: 8000,
          deckSize1: 40,
          extraSize1: 15,
          deckSize2: 40,
          extraSize2: 15,
        ),
      ),
    );

/// 观战身份开局（playerType 高位 0x10 标记观战）。
YgoStocMsg _observerStartMsg() => YgoStocMsg.gameMsg(
      const StocGameMessage(
        func: MSG_START,
        innerMsg: MsgStart(
          playerType: 0x10,
          life1: 8000,
          life2: 8000,
          deckSize1: 40,
          extraSize1: 15,
          deckSize2: 40,
          extraSize2: 15,
        ),
      ),
    );

YgoStocMsg _phaseMsg(int phase) => YgoStocMsg.gameMsg(
      StocGameMessage(
        func: MSG_NEW_PHASE,
        innerMsg: MsgNewPhase(phase: phase),
      ),
    );

YgoStocMsg _tossMsg() => YgoStocMsg.gameMsg(
      const StocGameMessage(
        func: MSG_TOSS_COIN,
        innerMsg: MsgToss(player: 0, count: 1, results: [1]),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  YgoSoundService.enabled = false;

  late _FakeDuelService service;
  late ProviderContainer container;

  ProviderContainer makeContainer({
    bool jumpToCurrent = false,
    YgoSoundService? sound,
  }) {
    return ProviderContainer(overrides: [
      duelServiceProvider.overrideWithValue(service),
      dataServiceProvider.overrideWithValue(
        YgoDataService(
          cardService: _StubCardService(),
          deckService: _StubDeckService(),
          banlistService: _StubBanlistService(),
        ),
      ),
      ygoSoundServiceProvider.overrideWithValue(sound ?? YgoSoundService()),
      if (jumpToCurrent)
        ygoSettingsProvider.overrideWith(_JumpSettingsNotifier.new),
    ]);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = _FakeDuelService();
  });

  tearDown(() => container.dispose());

  DuelFieldState field() => container.read(duelFieldProvider);

  group('DuelMessageRouter 节奏泵接线', () {
    test('MSG_NEW_PHASE 由队列驱动：首条直通，后续按节奏应用', () {
      container = makeContainer();
      fakeAsync((async) {
        final router = container.read(duelMessageRouterProvider.notifier);
        router.start();

        service.emit(_phaseMsg(PHASE_DRAW));
        // 假服务的 onDuelPhaseMessage 是空流：相位若仍走独立流则永远不更新。
        expect(field().phase, DuelPhase.dp, reason: '队列空闲时首条直通');

        service.emit(_phaseMsg(PHASE_MAIN1));
        expect(field().phase, DuelPhase.dp, reason: '第二条应排队等待节奏');
        async.elapse(const Duration(milliseconds: 119));
        expect(field().phase, DuelPhase.dp);
        async.elapse(const Duration(milliseconds: 1));
        expect(field().phase, DuelPhase.m1);
      });
    });

    test('MSG_START 清空残留队列：排队中的上局消息被丢弃', () {
      container = makeContainer();
      fakeAsync((async) {
        final router = container.read(duelMessageRouterProvider.notifier);
        router.start();

        service.emit(_startMsg()); // 第一局开始（直通，随后进入 120ms 冷却）
        service.emit(_tossMsg()); // 冷却窗口内 → 入队
        async.elapse(const Duration(milliseconds: 120)); // 消费 → 战报 +1
        service.emit(_tossMsg()); // 冷却窗口内 → 入队（等待 120ms）
        service.emit(_startMsg()); // Match 第二局：清队（丢弃上一条） + 直通
        async.elapse(const Duration(seconds: 10));

        final s = field();
        final tossLogs =
            s.duelLogs.where((l) => l.contains('抛硬币')).length;
        expect(tossLogs, 1, reason: '排队中的上局抛硬币应被 MSG_START 清队丢弃');
        expect(s.startLp, 8000, reason: '第二局 MSG_START 已应用');
        expect(s.phase, DuelPhase.idle, reason: 'handleStart 重置阶段');
      });
    });

    test('观战 + 跳到当前局面：积压爆发静默同步落位，尾部仍按节奏播放', () {
      final sound = _RecordingSoundService();
      container = makeContainer(jumpToCurrent: true, sound: sound);
      fakeAsync((async) {
        final router = container.read(duelMessageRouterProvider.notifier);
        router.start();

        service.emit(_observerStartMsg()); // 观战身份 → jump 生效（直通，带音效）
        expect(sound.duelStartCount, 1);

        // 30 条阶段消息爆发：积压到 21 时触发 jump 清场，静音同步消费。
        for (var i = 0; i < 30; i++) {
          service.emit(_phaseMsg(PHASE_BATTLE));
        }

        expect(field().phase, DuelPhase.bp, reason: 'jump 应同步追平到最新阶段');
        expect(sound.newPhaseSuppressStates.length, 21);
        expect(sound.newPhaseSuppressStates.every((s) => s), isTrue,
            reason: 'jump 清场期间的音效调用应处于 suppress');

        // 尾部不足阈值的 9 条仍按节奏播放（不静音）。
        async.elapse(const Duration(milliseconds: 120));
        expect(sound.newPhaseSuppressStates.last, isFalse);
        async.elapse(const Duration(seconds: 10));
      });
    });

    test('玩家对局不受观战开关影响：jump 设置开启仍按节奏播放', () {
      final sound = _RecordingSoundService();
      container = makeContainer(jumpToCurrent: true, sound: sound);
      fakeAsync((async) {
        final router = container.read(duelMessageRouterProvider.notifier);
        router.start();

        service.emit(_startMsg()); // playerType 0 = 玩家身份
        for (var i = 0; i < 25; i++) {
          service.emit(_phaseMsg(PHASE_BATTLE));
        }

        expect(field().phase, DuelPhase.idle,
            reason: '玩家对局不触发 jump，阶段消息仍排队');

        async.elapse(const Duration(milliseconds: 120));
        expect(field().phase, DuelPhase.bp, reason: '按节奏消费第一条');
        expect(sound.newPhaseSuppressStates, [false],
            reason: '玩家对局音效不 suppress');

        async.elapse(const Duration(seconds: 30));
      });
    });

    test('STOC_TIME_LIMIT 直通：队列积压时计时立即应用（特征测试，改动前后均通过）', () {
      container = makeContainer();
      fakeAsync((async) {
        final router = container.read(duelMessageRouterProvider.notifier);
        router.start();

        service.emit(_startMsg()); // myController=0（直通，随后进入冷却）
        service.emit(_phaseMsg(PHASE_DRAW)); // 冷却窗口内 → 入队
        service.emit(_phaseMsg(PHASE_MAIN1)); // 入队（积压 2）
        service.emit(YgoStocMsg.timeLimit(
            const StocTimeLimit(player: 0, leftTime: 5)));

        // 不流逝时间：计时应立即生效（绕过队列），阶段消息仍排队未应用。
        expect(field().selfTimeLeft, 5, reason: 'TIME_LIMIT 不入队，立即应用');
        expect(field().phase, DuelPhase.idle, reason: '排队消息不受影响');

        // 队列按节奏消费：120ms 后 dp 应用，m1 仍在排队。
        async.elapse(const Duration(milliseconds: 120));
        expect(field().phase, DuelPhase.dp);

        // 排空队列并耗尽倒计时（每秒 -1，5 秒后自停），避免 fakeAsync
        // 结束时仍有 pending Timer。
        async.elapse(const Duration(seconds: 30));
      });
    });
  });
}
