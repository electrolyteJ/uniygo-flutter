# 对局消息节奏泵（Duel Message Pacing Pump）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给对局消息分发加自适应节奏泵，消除竞技观战/开局爆发时 UI 瞬间刷新几百次导致的"过快过乱"。

**Architecture:** 新增泛型 `MessagePump<T>`（FIFO + Timer，与协议/状态无关，可独立单测）；`DuelMessageRouter` 把"收到即分发"改为"入队 → 按积压量降档消费"；MSG_NEW_PHASE 从独立流并入队列同源消费；MSG_START 入队前清残留队列；STOC_TIME_LIMIT 绕过队列直通。

**Tech Stack:** Dart 3 / Flutter / Riverpod 3（riverpod_annotation）/ flutter_test + fake_async。

**Spec:** `docs/superpowers/specs/2026-08-30-duel-message-pacing-pump-design.md`

---

## 前置说明（重要）

- **git 提交纪律**：仓库暂存区当前有 95 个与本任务无关的已暂存文件（用户的工作）。本计划所有提交必须路径限定：`git commit -m "..." -- <path...>`，**禁止**裸 `git add -A && git commit`。
- 测试工作目录：`packages/biz`（monorepo workspace，直接 `flutter test` 即可）。
- 测试模式对齐 `packages/biz/test/field_start_lp_test.dart`：ProviderContainer + 桩服务（`_StubCardService` 等）+ `YgoSoundService.enabled = false` 禁音效。

## 文件结构

- **Create** `packages/biz/lib/duel/field/message_pump.dart` — 泛型消息泵：FIFO 队列 + 自适应节奏 Timer + clear/dispose。
- **Modify** `packages/biz/lib/duel/field/duel_message_router.dart` — 接入泵（ingress 分叉、相位并队、MSG_START 清队）。
- **Create** `packages/biz/test/message_pump_test.dart` — 泵的纯单元测试（fake_async）。
- **Create** `packages/biz/test/duel_message_router_test.dart` — router 级接线测试（ProviderContainer + 假 IDuelService）。

---

### Task 1: MessagePump —— 直通与自适应节奏

**Files:**
- Create: `packages/biz/lib/duel/field/message_pump.dart`
- Test: `packages/biz/test/message_pump_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `packages/biz/test/message_pump_test.dart`：

```dart
/// 对局消息节奏泵（MessagePump）单元测试。
///
/// 背景：竞技观战中途加入时，服务器把开局以来的整段对局消息一次性推来
/// （数百条），收到即分发让 UI 瞬间刷新几百次。泵把消息入队后按积压量
/// 自适应降档消费：积压越深节奏越快，追平后恢复 0ms 直通。
library;

import 'package:biz/duel/field/message_pump.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessagePump 节奏', () {
    test('空闲时首条消息同步直通（0ms）', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: consumed.add);

        pump.enqueue(1);

        expect(consumed, [1], reason: '队列空时入队应立即同步消费');
        expect(pump.pendingCount, 0);
        pump.dispose();
      });
    });

    test('小爆发（≤20 积压）：每 120ms 消费一条', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: consumed.add);

        for (var i = 0; i < 5; i++) {
          pump.enqueue(i);
        }
        expect(consumed, [0], reason: '首条直通，其余排队');

        async.elapse(const Duration(milliseconds: 119));
        expect(consumed, [0], reason: '120ms 未到不应消费第二条');
        async.elapse(const Duration(milliseconds: 1));
        expect(consumed, [0, 1]);

        async.elapse(const Duration(seconds: 1));
        expect(consumed, [0, 1, 2, 3, 4]);
        pump.dispose();
      });
    });

    test('中爆发（21~100 积压）：每 40ms 消费一条', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: consumed.add);

        for (var i = 0; i < 30; i++) {
          pump.enqueue(i);
        }
        expect(consumed, [0]);

        async.elapse(const Duration(milliseconds: 39));
        expect(consumed, [0]);
        async.elapse(const Duration(milliseconds: 1));
        expect(consumed, [0, 1]);

        async.elapse(const Duration(seconds: 5));
        expect(consumed.length, 30);
        pump.dispose();
      });
    });

    test('大爆发（>100 积压，观战追赶）：每 12ms 消费一条，追平后恢复直通', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: consumed.add);

        for (var i = 0; i < 300; i++) {
          pump.enqueue(i);
        }
        expect(consumed, [0]);

        // 追赶档：120ms 内应消费 10 条（12ms/条）。
        async.elapse(const Duration(milliseconds: 120));
        expect(consumed.length, 11);

        // 积压随消费下降自动降档；给足时间全部消化。
        async.elapse(const Duration(seconds: 30));
        expect(consumed.length, 300);
        expect(pump.pendingCount, 0);

        // 追平后新消息恢复 0ms 直通。
        pump.enqueue(999);
        expect(consumed.last, 999);
        pump.dispose();
      });
    });

    test('intervalForBacklog 档位边界', () {
      expect(MessagePump.intervalForBacklog(1),
          const Duration(milliseconds: 120));
      expect(MessagePump.intervalForBacklog(20),
          const Duration(milliseconds: 120));
      expect(MessagePump.intervalForBacklog(21),
          const Duration(milliseconds: 40));
      expect(MessagePump.intervalForBacklog(100),
          const Duration(milliseconds: 40));
      expect(MessagePump.intervalForBacklog(101),
          const Duration(milliseconds: 12));
      expect(MessagePump.intervalForBacklog(500),
          const Duration(milliseconds: 12));
    });

    test('dispose 停止泵：定时器取消，后续入队被忽略', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: consumed.add);

        for (var i = 0; i < 50; i++) {
          pump.enqueue(i);
        }
        pump.dispose();

        async.elapse(const Duration(seconds: 10));
        expect(consumed, [0], reason: 'dispose 后不得再消费');

        pump.enqueue(1);
        expect(consumed, [0], reason: 'dispose 后入队应被忽略');
      });
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd packages/biz && flutter test test/message_pump_test.dart`
Expected: FAIL — `message_pump.dart` 不存在（编译错误）。

- [ ] **Step 3: 实现 MessagePump**

创建 `packages/biz/lib/duel/field/message_pump.dart`：

```dart
import 'dart:async';
import 'dart:collection';

import 'package:applog/console.dart' as console;

/// 对局消息节奏泵：把瞬时爆发的消息流摊平成自适应节奏的逐条消费。
///
/// 背景：竞技观战中途加入时，服务器会把开局以来的整段对局消息一次性推
/// 过来（数百条），收到即分发会让 UI 在一瞬间刷新几百次，画面过快过乱。
/// 泵把消息先入队，按积压量自适应降档消费：积压越深节奏越快，追平后
/// 恢复 0ms 直通（玩家正常操作零感知延迟）。
///
/// 与协议/状态层无关的纯泛型工具：音效、战报、画面随消费节奏自然错开。
class MessagePump<T> {
  MessagePump({required void Function(T message) consume})
      : _consume = consume;

  final void Function(T) _consume;
  final Queue<T> _queue = Queue<T>();
  Timer? _timer;
  bool _disposed = false;

  /// 节奏档位（按消费后的剩余积压量选择下一条间隔），从松到紧排列。
  static const List<({int maxBacklog, Duration interval})> paceTiers = [
    (maxBacklog: 20, interval: Duration(milliseconds: 120)),
    (maxBacklog: 100, interval: Duration(milliseconds: 40)),
    (maxBacklog: 1 << 30, interval: Duration(milliseconds: 12)),
  ];

  /// 待消费消息数（测试与调试观测用）。
  int get pendingCount => _queue.length;

  /// 积压量 → 消费间隔。暴露为 static 便于单测直接断言档位边界。
  static Duration intervalForBacklog(int backlog) {
    for (final tier in paceTiers) {
      if (backlog <= tier.maxBacklog) return tier.interval;
    }
    return paceTiers.last.interval;
  }

  /// 入队。泵空闲（无待触发定时器）时首条同步直通消费，实现 0ms 直通。
  void enqueue(T message) {
    if (_disposed) return;
    _queue.add(message);
    if (_timer == null) _drainOne();
  }

  /// 停止泵：取消定时器、清空队列，后续入队被忽略。
  void dispose() {
    _disposed = true;
    _queue.clear();
    _timer?.cancel();
    _timer = null;
  }

  void _drainOne() {
    _timer = null;
    if (_queue.isEmpty) return;
    final message = _queue.removeFirst();
    try {
      _consume(message);
    } catch (e, s) {
      // 单条消息的消费异常不应让整条泵停摆（否则对局静默卡死）。
      console.log('MessagePump consume error: $e\n$s');
    }
    if (_disposed) {
      _queue.clear();
      return;
    }
    if (_queue.isNotEmpty) {
      _timer = Timer(intervalForBacklog(_queue.length), _drainOne);
    }
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd packages/biz && flutter test test/message_pump_test.dart`
Expected: PASS（6 个测试全绿）。

- [ ] **Step 5: 提交**

```bash
git add packages/biz/lib/duel/field/message_pump.dart packages/biz/test/message_pump_test.dart
git commit -m "feat(biz): 对局消息节奏泵 MessagePump（自适应降档消费）" -- packages/biz/lib/duel/field/message_pump.dart packages/biz/test/message_pump_test.dart
```

---

### Task 2: MessagePump —— clear（MSG_START 清队原语）

**Files:**
- Modify: `packages/biz/lib/duel/field/message_pump.dart`
- Test: `packages/biz/test/message_pump_test.dart`

- [ ] **Step 1: 追加失败测试**

在 `packages/biz/test/message_pump_test.dart` 的 group 内追加：

```dart
    test('clear 丢弃全部待消费消息，之后可重新入队', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(consume: consumed.add);

        for (var i = 0; i < 50; i++) {
          pump.enqueue(i);
        }
        expect(consumed, [0]);

        pump.clear();
        expect(pump.pendingCount, 0);

        async.elapse(const Duration(seconds: 10));
        expect(consumed, [0], reason: 'clear 后队列中的消息不得再被消费');

        pump.enqueue(100);
        expect(consumed, [0, 100], reason: 'clear 后泵应恢复正常工作');
        pump.dispose();
      });
    });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd packages/biz && flutter test test/message_pump_test.dart`
Expected: FAIL — `clear` 方法不存在（编译错误）。

- [ ] **Step 3: 实现 clear，并让 dispose 复用它**

在 `packages/biz/lib/duel/field/message_pump.dart` 中，把 `dispose` 改为复用新的 `clear`：

```dart
  /// 丢弃全部待消费消息并停止调度（MSG_START 局间切换清上局残留）。
  /// 不影响后续入队。
  void clear() {
    _queue.clear();
    _timer?.cancel();
    _timer = null;
  }

  /// 停止泵：取消定时器、清空队列，后续入队被忽略。
  void dispose() {
    _disposed = true;
    clear();
  }
```

（即：删除旧 `dispose` 的内联 `_queue.clear(); _timer?.cancel(); _timer = null;`，替换为上面两个方法。）

- [ ] **Step 4: 跑测试确认通过**

Run: `cd packages/biz && flutter test test/message_pump_test.dart`
Expected: PASS（7 个测试全绿）。

- [ ] **Step 5: 提交**

```bash
git add packages/biz/lib/duel/field/message_pump.dart packages/biz/test/message_pump_test.dart
git commit -m "feat(biz): MessagePump.clear（MSG_START 局间清残留队列）" -- packages/biz/lib/duel/field/message_pump.dart packages/biz/test/message_pump_test.dart
```

---

### Task 3: DuelMessageRouter 接线（入泵 + TIME_LIMIT 直通 + MSG_START 清队 + 相位并队）

**Files:**
- Modify: `packages/biz/lib/duel/field/duel_message_router.dart`
- Test: `packages/biz/test/duel_message_router_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `packages/biz/test/duel_message_router_test.dart`：

```dart
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

  late ProviderContainer container;
  late _FakeDuelService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = _FakeDuelService();
    container = ProviderContainer(overrides: [
      duelServiceProvider.overrideWithValue(service),
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

  DuelFieldState field() => container.read(duelFieldProvider);

  group('DuelMessageRouter 节奏泵接线', () {
    test('MSG_NEW_PHASE 由队列驱动：首条直通，后续按节奏应用', () {
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
      fakeAsync((async) {
        final router = container.read(duelMessageRouterProvider.notifier);
        router.start();

        service.emit(_startMsg()); // 第一局开始（直通）
        service.emit(_tossMsg()); // 直通 → 战报 +1
        service.emit(_tossMsg()); // 入队（等待 120ms）
        service.emit(_startMsg()); // Match 第二局：清队 + 直通
        async.elapse(const Duration(seconds: 10));

        final s = field();
        final tossLogs =
            s.duelLogs.where((l) => l.contains('抛硬币')).length;
        expect(tossLogs, 1, reason: '排队中的上局抛硬币应被 MSG_START 清队丢弃');
        expect(s.startLp, 8000, reason: '第二局 MSG_START 已应用');
        expect(s.phase, DuelPhase.idle, reason: 'handleStart 重置阶段');
      });
    });

    test('STOC_TIME_LIMIT 直通：队列积压时计时立即应用（特征测试，改动前后均通过）', () {
      fakeAsync((async) {
        final router = container.read(duelMessageRouterProvider.notifier);
        router.start();

        service.emit(_startMsg()); // myController=0
        service.emit(_phaseMsg(PHASE_DRAW)); // 直通
        service.emit(_phaseMsg(PHASE_MAIN1)); // 入队（积压 1）
        service.emit(YgoStocMsg.timeLimit(
            const StocTimeLimit(player: 0, leftTime: 5)));

        // 不流逝时间：计时应立即生效（绕过队列），阶段仍停在 dp（排队中）。
        expect(field().selfTimeLeft, 5, reason: 'TIME_LIMIT 不入队，立即应用');
        expect(field().phase, DuelPhase.dp, reason: '排队消息不受影响');

        // 排空队列并耗尽倒计时（每秒 -1，5 秒后自停），避免 fakeAsync
        // 结束时仍有 pending Timer。
        async.elapse(const Duration(seconds: 30));
      });
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd packages/biz && flutter test test/duel_message_router_test.dart`
Expected:
- 「MSG_NEW_PHASE 由队列驱动」FAIL — 现状相位走 `onDuelPhaseMessage` 独立流（假服务为空流），`phase` 停在 `idle`，第一个 expect 即失败；
- 「MSG_START 清空残留队列」FAIL — 现状无队列、全部同步消费，`tossLogs` 为 2；
- 「STOC_TIME_LIMIT 直通」PASS（特征测试，锁定既有直通行为）。

- [ ] **Step 3: 修改 router**

对 `packages/biz/lib/duel/field/duel_message_router.dart` 做四处修改：

**3a. 导入**（加在文件头部 import 区）：

```dart
import 'message_pump.dart';
```

**3b. 字段**：把

```dart
  StreamSubscription<YgoStocMsg>? _msgSub;
  StreamSubscription<DuelPhase>? _phaseSub;
  String? Function(DuelPhase phase)? _phaseLabel;
```

改为：

```dart
  StreamSubscription<YgoStocMsg>? _msgSub;
  String? Function(DuelPhase phase)? _phaseLabel;

  /// 消息节奏泵：观战追赶/开局爆发时把消息摊平成自适应节奏逐条消费；
  /// 空闲时 0ms 直通。start() 重建，随订阅一起回收。
  MessagePump<YgoStocMsg>? _pump;
```

**3c. `_cancelSubscriptions` 与 `start`**：把

```dart
  void _cancelSubscriptions() {
    _msgSub?.cancel();
    _phaseSub?.cancel();
    _msgSub = null;
    _phaseSub = null;
  }
```

改为：

```dart
  void _cancelSubscriptions() {
    _msgSub?.cancel();
    _msgSub = null;
    _pump?.dispose();
    _pump = null;
  }
```

把 `start` 整段：

```dart
  void start({String? Function(DuelPhase phase)? phaseLabel}) {
    _phaseLabel = phaseLabel;
    _cancelSubscriptions();
    final service = ref.read(duelServiceProvider);
    _phaseSub = service.onDuelPhaseMessage.listen((phase) {
      // 阶段合法性（enableBp/enableM2/enableEp）只由服务端下发的
      // MSG_SELECT_IDLE_CMD / MSG_SELECT_BATTLE_CMD 驱动，这里不做本地推断。
      _boardN.setPhaseFromStream(phase, _phaseLabel?.call(phase));
    });
    _msgSub = service.onServerMessage.listen(_handleServerMessage);
  }
```

改为：

```dart
  void start({String? Function(DuelPhase phase)? phaseLabel}) {
    _phaseLabel = phaseLabel;
    _cancelSubscriptions();
    final service = ref.read(duelServiceProvider);
    _pump = MessagePump(consume: _handleServerMessage);
    _msgSub = service.onServerMessage.listen(_onServerMessage);
  }

  /// 服务器消息入口（入队前的唯一分叉）：
  /// - STOC_TIME_LIMIT 直通：计时必须实时，不进节奏泵；
  /// - MSG_START 先清残留队列：Match 局间重开时丢弃上一局排队中的消息，
  ///   防止串台（与 MSG_START 分支的清状态逻辑对齐）；
  /// - 其余一律入泵，按自适应节奏消费。
  void _onServerMessage(YgoStocMsg msg) {
    final timeLimit = msg.timeLimit;
    if (timeLimit != null) {
      _boardN.handleTimeLimit(timeLimit);
      return;
    }
    final pump = _pump;
    if (pump == null) return;
    if (msg.gameMsg?.func == MSG_START) {
      pump.clear();
    }
    pump.enqueue(msg);
  }
```

**3d. MSG_NEW_PHASE 分支并队**：把

```dart
      case MSG_NEW_PHASE: // 新阶段
        console.log(
          'handleServerMessage: MSG_NEW_PHASE（新阶段） innerMsg=${gameMsg.innerMsg}',
        );
        // 已通过 onDuelPhaseMessage 单独派发，避免这里重复记日志。
        _sound.playNewPhase();
        break;
```

改为：

```dart
      case MSG_NEW_PHASE: // 新阶段
        console.log(
          'handleServerMessage: MSG_NEW_PHASE（新阶段） innerMsg=${gameMsg.innerMsg}',
        );
        // 相位不再走 onDuelPhaseMessage 独立流（会超前于节奏泵中的画面），
        // 在消费到本条时同步更新：音效、阶段、战报、画面同源同节奏。
        // 阶段合法性（enableBp/enableM2/enableEp）只由服务端下发的
        // MSG_SELECT_IDLE_CMD / MSG_SELECT_BATTLE_CMD 驱动，这里不做本地推断。
        final phaseMsg = innerMsg as MsgNewPhase;
        final phase = DuelPhase.of(phaseMsg.rawPhase);
        _boardN.setPhaseFromStream(phase, _phaseLabel?.call(phase));
        _sound.playNewPhase();
        break;
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd packages/biz && flutter test test/duel_message_router_test.dart`
Expected: PASS（3 个测试全绿）。

- [ ] **Step 5: 提交**

```bash
git add packages/biz/lib/duel/field/duel_message_router.dart packages/biz/test/duel_message_router_test.dart
git commit -m "feat(biz): DuelMessageRouter 接入节奏泵（观战爆发带节奏回放）" -- packages/biz/lib/duel/field/duel_message_router.dart packages/biz/test/duel_message_router_test.dart
```

---

### Task 4: 全量回归

**Files:** 无新增改动（仅验证）。

- [ ] **Step 1: 跑 biz 全量测试**

Run: `cd packages/biz && flutter test`
Expected: 全部 PASS（含既有 17 个测试文件与新增 2 个）。特别关注 `field_start_lp_test`、`room_connection_lifetime_test` 等走 router/服务桩的用例不受接线改动影响。

- [ ] **Step 2: 静态检查**

Run: `cd packages/biz && flutter analyze`
Expected: `No issues found!`（`_phaseSub` 移除后无未用引用；`onDuelPhaseMessage` 在 duelink 侧的流保留，供 duelink_ai 等其他消费者使用，不删）。

- [ ] **Step 3: 若 analyze/test 有残留问题，修复后按路径限定提交；无问题则无需提交。**

---

## 实施偏差记录（2026-08-30 执行时补记）

1. **冷却窗口语义**：计划中的泵实现只在队列非空时排定时器，导致爆发循环里
   每条消息都看到空闲泵而被同步直通（测试暴露）。实际实现改为**每次消费后
   都排冷却窗口**（队列空按积压 1 档 = 120ms），窗口内到达的消息入队等待。
   因此爆发的第二条消息间隔固定为 120ms（首跳），之后按积压档位加速——
   Task 1「中爆发/大爆发」与 Task 3「MSG_START 清队 / TIME_LIMIT」测试的
   时序断言已按此修正。
2. **依赖声明**：`fake_async` 补入 `packages/biz` 的 dev_dependencies
   （`^1.3.3`），消除 depend_on_referenced_packages（含既有
   `card_confirm_queue_test.dart` 的同类 info）。
3. **遗留 info**：`message_pump.dart` 构造函数有一条
   `prefer_initializing_formals` info，无法在不暴露私有字段的前提下消除，
   与仓库既有 28 条 info 同级保留。
4. **已知无关失败**：`test/zone_browser_activatable_test.dart`（用户未跟踪
   的 WIP 文件）因缺少 `dataServiceProvider` override 失败，与本次改动无关，
   回归时排除。

## Self-Review 记录

- Spec 覆盖：节奏档位表 ✓（Task 1）、入队接入 ✓（Task 3c）、TIME_LIMIT 直通 ✓（Task 3c + 特征测试）、相位并队 ✓（Task 3d）、MSG_START 清队 ✓（Task 2 + 3c）、dispose 随 scope 回收 ✓（Task 3c 经 `_cancelSubscriptions` ← `ref.onDispose`）。
- 类型一致性：`MessagePump<T>({required void Function(T) consume})`、`pendingCount`、`intervalForBacklog`、`clear()`、`dispose()` 在测试与实现中签名一致；router 用 `MessagePump(consume: _handleServerMessage)` 匹配 `void Function(YgoStocMsg)`。
- 无占位符：所有步骤含完整代码与确切命令。
