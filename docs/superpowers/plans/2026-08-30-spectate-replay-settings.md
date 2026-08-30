# 观战回放模式与回放速度设置 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 设置中提供观战回放模式开关（带节奏回放 / 跳到当前局面）与回放速度倍率，作用于对局消息节奏泵。

**Architecture:** 设置契约在 biz（YgoSettings 加两字段）→ 泵新增 jumpToCurrent/speedFactor 运行时字段 → router 按 MSG_START 的观战身份与设置驱动泵；持久化与弹窗 UI 在 modules/ygo_settings，宿主注入 override（既有模式）。

**Tech Stack:** Dart 3 / Flutter / Riverpod 3 / SharedPreferences / flutter_test + fake_async。

**Spec:** `docs/superpowers/specs/2026-08-30-spectate-replay-settings-design.md`

---

## 前置说明（重要）

- **git 提交纪律**：仓库暂存区有大量无关的已暂存文件（用户的工作）。所有提交必须路径限定：`git commit -m "..." -- <path...>`。
- 测试工作目录：biz → `packages/biz`；设置模块 → `modules/ygo_settings`。

## 文件结构

- **Modify** `packages/biz/lib/duel/field/message_pump.dart` — consume 加 silent 参数；jumpToCurrent / speedFactor / kJumpBacklogThreshold。
- **Modify** `packages/biz/lib/ygo_settings.dart` — YgoSettings 加两字段 + setter。
- **Modify** `packages/biz/lib/ygo_sound_service.dart` — suppress 字段。
- **Modify** `packages/biz/lib/duel/field/duel_message_router.dart` — _dispatchServerMessage 改名 + 静音包装 + 观战身份捕获 + 设置应用。
- **Modify** `modules/ygo_settings/lib/ygo_settings.dart` — 持久化 + 弹窗「观战」区块。
- **Test** `packages/biz/test/message_pump_test.dart`（改）、`packages/biz/test/duel_message_router_test.dart`（改）、`packages/biz/test/ygo_sound_service_test.dart`（新）、`modules/ygo_settings/test/ygo_settings_test.dart`（改）。

---

### Task 1: MessagePump 扩展（silent + jumpToCurrent + speedFactor）

**Files:**
- Modify: `packages/biz/lib/duel/field/message_pump.dart`
- Test: `packages/biz/test/message_pump_test.dart`

- [ ] **Step 1: 适配既有测试到新签名，并追加失败测试**

`packages/biz/test/message_pump_test.dart` 中所有 `consume: consumed.add` 改为：

```dart
consume: (m, {required bool silent}) => consumed.add(m)
```

「intervalForBacklog 档位边界」测试改为实例调用：

```dart
    test('intervalForBacklog 档位边界', () {
      final pump = MessagePump<int>(
          consume: (m, {required bool silent}) {});
      expect(pump.intervalForBacklog(1), const Duration(milliseconds: 120));
      expect(pump.intervalForBacklog(20), const Duration(milliseconds: 120));
      expect(pump.intervalForBacklog(21), const Duration(milliseconds: 40));
      expect(pump.intervalForBacklog(100), const Duration(milliseconds: 40));
      expect(pump.intervalForBacklog(101), const Duration(milliseconds: 12));
      expect(pump.intervalForBacklog(500), const Duration(milliseconds: 12));
      pump.dispose();
    });
```

group 内追加两个新测试（此时应编译失败）：

```dart
    test('jumpToCurrent：积压超阈值同步静音清场，尾部不足阈值仍按节奏', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final silents = <bool>[];
        final pump = MessagePump<int>(consume: (m, {required bool silent}) {
          consumed.add(m);
          silents.add(silent);
        });
        pump.jumpToCurrent = true;

        pump.enqueue(0); // 空闲直通（非静音）
        expect(consumed, [0]);
        expect(silents, [false]);

        // 积压到 21（>20）时触发清场：1..21 同步静音消费。
        for (var i = 1; i <= 30; i++) {
          pump.enqueue(i);
        }
        expect(consumed.length, 22);
        expect(silents.sublist(1).every((s) => s), isTrue,
            reason: '清场期间全部 silent');
        // 剩余 22..30 不足阈值，仍按节奏排队。
        expect(pump.pendingCount, 9);

        async.elapse(const Duration(seconds: 10));
        expect(consumed.length, 31);
        expect(silents.sublist(22).every((s) => !s), isTrue,
            reason: '尾部按节奏消费，不静音');
        pump.dispose();
      });
    });

    test('回放速度倍率：2x 时消费间隔减半', () {
      fakeAsync((async) {
        final consumed = <int>[];
        final pump = MessagePump<int>(
            consume: (m, {required bool silent}) => consumed.add(m));
        pump.speedFactor = 2.0;
        expect(pump.intervalForBacklog(1), const Duration(milliseconds: 60));
        expect(pump.intervalForBacklog(101), const Duration(milliseconds: 6));

        pump.enqueue(0);
        pump.enqueue(1);
        expect(consumed, [0]);
        async.elapse(const Duration(milliseconds: 59));
        expect(consumed, [0]);
        async.elapse(const Duration(milliseconds: 1));
        expect(consumed, [0, 1]);
        pump.dispose();
      });
    });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd packages/biz && flutter test test/message_pump_test.dart`
Expected: FAIL — 编译错误（consume 签名不匹配、intervalForBacklog 不是 static、无 jumpToCurrent/speedFactor）。

- [ ] **Step 3: 实现**

`packages/biz/lib/duel/field/message_pump.dart` 完整替换为：

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
/// 观战可切换两种模式（由 router 按设置与观战身份驱动）：
/// - 带节奏回放（默认）：上述自适应节奏；
/// - 跳到当前局面（[jumpToCurrent]）：积压超 [kJumpBacklogThreshold] 时
///   抛弃节奏，同步静音清空整条队列，直接落位到最新局面。
///
/// 与协议/状态层无关的纯泛型工具：音效、战报、画面随消费节奏自然错开。
class MessagePump<T> {
  MessagePump({required void Function(T message, {required bool silent}) consume})
      : _consume = consume;

  final void Function(T, {required bool silent}) _consume;
  final Queue<T> _queue = Queue<T>();
  Timer? _timer;
  bool _disposed = false;

  /// 观战「跳到当前局面」模式：积压超阈值时同步静音清场。
  /// 仅观战局由 router 开启；运行时可改。
  bool jumpToCurrent = false;

  /// 回放速度倍率：消费间隔 = 档位间隔 ÷ speedFactor（2.0 = 快一倍）。
  double speedFactor = 1.0;

  /// 触发「跳到当前局面」静默清场的积压阈值。
  static const int kJumpBacklogThreshold = 20;

  /// 节奏档位（按消费后的剩余积压量选择下一条间隔），从松到紧排列。
  static const List<({int maxBacklog, Duration interval})> paceTiers = [
    (maxBacklog: 20, interval: Duration(milliseconds: 120)),
    (maxBacklog: 100, interval: Duration(milliseconds: 40)),
    (maxBacklog: 1 << 30, interval: Duration(milliseconds: 12)),
  ];

  /// 待消费消息数（测试与调试观测用）。
  int get pendingCount => _queue.length;

  /// 积压量 → 消费间隔（已按 [speedFactor] 缩放）。
  Duration intervalForBacklog(int backlog) {
    for (final tier in paceTiers) {
      if (backlog <= tier.maxBacklog) {
        return tier.interval * (1.0 / speedFactor);
      }
    }
    return paceTiers.last.interval * (1.0 / speedFactor);
  }

  /// 入队。泵空闲（无待触发定时器）时首条同步直通消费，实现 0ms 直通。
  void enqueue(T message) {
    if (_disposed) return;
    _queue.add(message);
    if (jumpToCurrent && _queue.length > kJumpBacklogThreshold) {
      // 跳到当前局面：取消节奏，同步静音清空积压；随后排一个冷却窗口，
      // 避免爆发中后续消息穿透直通（每条都带音效就乱了）。
      _timer?.cancel();
      while (_queue.isNotEmpty && !_disposed) {
        _consumeOne(_queue.removeFirst(), silent: true);
      }
      if (_disposed) {
        _queue.clear();
        return;
      }
      _timer = Timer(intervalForBacklog(1), _drainOne);
      return;
    }
    if (_timer == null) _drainOne();
  }

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

  void _drainOne() {
    _timer = null;
    if (_queue.isEmpty) return;
    _consumeOne(_queue.removeFirst(), silent: false);
    if (_disposed) {
      _queue.clear();
      return;
    }
    // 每次消费后都排冷却窗口（队列空按最小积压档）：窗口内到达的
    // 消息入队等待，窗口到期后队列为空则泵回到空闲（下一条直通）。
    // 若只在队列非空时排定时器，爆发循环里每条消息都会看到空闲泵而被
    // 同步直通，节奏彻底失效。
    final backlog = _queue.isEmpty ? 1 : _queue.length;
    _timer = Timer(intervalForBacklog(backlog), _drainOne);
  }

  void _consumeOne(T message, {required bool silent}) {
    try {
      _consume(message, silent: silent);
    } catch (e, s) {
      // 单条消息的消费异常不应让整条泵停摆（否则对局静默卡死）。
      console.log('MessagePump consume error: $e\n$s');
    }
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd packages/biz && flutter test test/message_pump_test.dart`
Expected: PASS（9 个测试全绿）。

- [ ] **Step 5: 提交**

```bash
git commit -m "feat(biz): MessagePump 支持观战跳到当前局面（静音清场）与回放速度倍率" -- packages/biz/lib/duel/field/message_pump.dart packages/biz/test/message_pump_test.dart
```

---

### Task 2: YgoSettings 契约扩展（biz）

**Files:**
- Modify: `packages/biz/lib/ygo_settings.dart`
- Test: 无单独测试（经 Task 3/4 的 router 与模块测试覆盖）。

- [ ] **Step 1: 扩展模型与 notifier**

`packages/biz/lib/ygo_settings.dart` 中：

YgoSettings 构造函数与字段：

```dart
class YgoSettings {
  const YgoSettings({
    this.showChain1Animation = false,
    this.autoMonsterPosition = false,
    this.autoSpellTrapPosition = false,
    this.spectateJumpToCurrent = false,
    this.replaySpeedFactor = 1.0,
  });

  /// 连锁 1 也显示连锁叠层动画（默认只显示 2 张及以上）。
  final bool showChain1Animation;

  /// 自动选择怪兽卡放置位置（MSG_SELECT_PLACE 时自动回包）。
  final bool autoMonsterPosition;

  /// 自动选择魔陷卡放置位置（MSG_SELECT_PLACE 时自动回包）。
  final bool autoSpellTrapPosition;

  /// 观战中途进入时直接跳到当前局面（false = 带节奏地快速回放历史消息）。
  /// 仅观战局生效（MSG_START 的 isObserver 判定），玩家对局不受影响。
  final bool spectateJumpToCurrent;

  /// 对局消息回放速度倍率：节奏泵各档间隔 ÷ 倍率（2.0 = 快一倍）。
  /// 「跳到当前局面」模式下无效。
  final double replaySpeedFactor;

  static const defaults = YgoSettings();

  YgoSettings copyWith({
    bool? showChain1Animation,
    bool? autoMonsterPosition,
    bool? autoSpellTrapPosition,
    bool? spectateJumpToCurrent,
    double? replaySpeedFactor,
  }) {
    return YgoSettings(
      showChain1Animation: showChain1Animation ?? this.showChain1Animation,
      autoMonsterPosition: autoMonsterPosition ?? this.autoMonsterPosition,
      autoSpellTrapPosition:
          autoSpellTrapPosition ?? this.autoSpellTrapPosition,
      spectateJumpToCurrent:
          spectateJumpToCurrent ?? this.spectateJumpToCurrent,
      replaySpeedFactor: replaySpeedFactor ?? this.replaySpeedFactor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is YgoSettings &&
      other.showChain1Animation == showChain1Animation &&
      other.autoMonsterPosition == autoMonsterPosition &&
      other.autoSpellTrapPosition == autoSpellTrapPosition &&
      other.spectateJumpToCurrent == spectateJumpToCurrent &&
      other.replaySpeedFactor == replaySpeedFactor;

  @override
  int get hashCode => Object.hash(
        showChain1Animation,
        autoMonsterPosition,
        autoSpellTrapPosition,
        spectateJumpToCurrent,
        replaySpeedFactor,
      );
}
```

YgoSettingsNotifier 追加 setter：

```dart
  void setSpectateJumpToCurrent(bool value) =>
      state = state.copyWith(spectateJumpToCurrent: value);

  void setReplaySpeedFactor(double value) =>
      state = state.copyWith(replaySpeedFactor: value);
```

- [ ] **Step 2: 验证编译**

Run: `cd packages/biz && flutter analyze lib/ygo_settings.dart`
Expected: No issues found（不加字段到 `.g.dart`，生成代码无需变更）。

- [ ] **Step 3: 提交**

```bash
git commit -m "feat(biz): YgoSettings 增加观战回放模式与回放速度倍率" -- packages/biz/lib/ygo_settings.dart
```

---

### Task 3: YgoSoundService.suppress + DuelMessageRouter 接线

**Files:**
- Modify: `packages/biz/lib/ygo_sound_service.dart`
- Modify: `packages/biz/lib/duel/field/duel_message_router.dart`
- Test: `packages/biz/test/ygo_sound_service_test.dart`（新）、`packages/biz/test/duel_message_router_test.dart`（改）

- [ ] **Step 1: 写失败测试**

新增 `packages/biz/test/ygo_sound_service_test.dart`：

```dart
/// YgoSoundService suppress（观战静默追赶）测试。
library;

import 'package:biz/ygo_sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('suppress 期间不创建播放器；恢复后正常创建', () async {
    final sound = YgoSoundService();
    expect(sound.activePlayerCount, 0);

    sound.suppress = true;
    await sound.playDuelStart();
    expect(sound.activePlayerCount, 0, reason: 'suppress 期间应直接返回');

    sound.suppress = false;
    await sound.playDuelStart();
    // 播放器已创建（平台播放本身在测试环境失败由内部 catch 兜住）。
    expect(sound.activePlayerCount, 1);
  });
}
```

`packages/biz/test/duel_message_router_test.dart` 修改：

a) import 区追加：

```dart
import 'package:biz/ygo_settings.dart';
```

b) `_FakeDuelService` 之后追加：

```dart
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
```

c) `_startMsg` 之后追加观战开局构造：

```dart
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
```

d) setUp/tearDown 重构为工厂模式（现有 container 创建逻辑改为函数）：

```dart
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
```

既有 3 个测试开头各加一行 `container = makeContainer();`。

e) group 内追加两个测试（此时应编译/断言失败）：

```dart
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
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd packages/biz && flutter test test/ygo_sound_service_test.dart test/duel_message_router_test.dart`
Expected: FAIL — `YgoSoundService` 无 `suppress`/`activePlayerCount`；router 无观战身份逻辑（观战用例 phase 停在 idle）。

- [ ] **Step 3: 实现**

**3a.** `packages/biz/lib/ygo_sound_service.dart`：字段区（`_pool` 声明附近）加：

```dart
  /// 实例级静音开关：观战「跳到当前局面」的静默清场期间由
  /// DuelMessageRouter 短暂置位（同步代码段，无 await 交错），
  /// 压掉清场过程中密集的过场音效。
  bool suppress = false;

  /// 已创建的播放器数（测试观测用）。
  int get activePlayerCount => _pool.length;
```

`_playAt` 开头改为：

```dart
  Future<void> _playAt(String basePath, String assetName) async {
    if (!enabled || suppress) return;
```

**3b.** `packages/biz/lib/duel/field/duel_message_router.dart`：

import 区追加 `import 'package:biz/ygo_settings.dart';`。

字段区（`_pump` 声明后）加：

```dart
  /// 当前对局是否为观战局（MSG_START 的 isObserver 捕获，start() 复位）。
  /// 「跳到当前局面」仅观战局生效，玩家对局的开局爆发不应被静默吞掉。
  bool _isObserverDuel = false;
```

`build()` 改为：

```dart
  @override
  void build() {
    ref.onDispose(_cancelSubscriptions);
    // 运行时改设置即时生效（下一条入队/清场即按新模式）。
    ref.listen(ygoSettingsProvider, (_, __) => _applyReplaySettings());
  }
```

`start()` 改为：

```dart
  void start({String? Function(DuelPhase phase)? phaseLabel}) {
    _phaseLabel = phaseLabel;
    _cancelSubscriptions();
    _isObserverDuel = false;
    final service = ref.read(duelServiceProvider);
    _pump = MessagePump(consume: _handleServerMessage);
    _applyReplaySettings();
    _msgSub = service.onServerMessage.listen(_onServerMessage);
  }

  /// 把观战回放设置写入节奏泵：jump 仅观战局生效。
  void _applyReplaySettings() {
    final s = ref.read(ygoSettingsProvider);
    _pump
      ?..speedFactor = s.replaySpeedFactor
      ..jumpToCurrent = s.spectateJumpToCurrent && _isObserverDuel;
  }
```

`_onServerMessage` 的 MSG_START 分叉改为同时捕获观战身份：

```dart
  void _onServerMessage(YgoStocMsg msg) {
    final timeLimit = msg.timeLimit;
    if (timeLimit != null) {
      _boardN.handleTimeLimit(timeLimit);
      return;
    }
    final pump = _pump;
    if (pump == null) return;
    final gameMsg = msg.gameMsg;
    if (gameMsg?.func == MSG_START) {
      // Match 局间重开：丢弃上一局排队中的消息，并按新局身份重估 jump。
      _isObserverDuel = switch (gameMsg!.innerMsg) {
        MsgStart m => m.isObserver,
        _ => false,
      };
      pump.clear();
      _applyReplaySettings();
    }
    pump.enqueue(msg);
  }
```

原 `_handleServerMessage` 方法改名为 `_dispatchServerMessage`（方法体零改动），并在其上方新增薄包装：

```dart
  /// 泵消费入口：silent（观战「跳到当前局面」清场）时压掉音效。
  /// suppress 置位/复位在同一同步代码段内完成，无 await 交错，
  /// 不会影响共享实例上的其它音效。
  void _handleServerMessage(YgoStocMsg msg, {bool silent = false}) {
    if (!silent) return _dispatchServerMessage(msg);
    _sound.suppress = true;
    try {
      _dispatchServerMessage(msg);
    } finally {
      _sound.suppress = false;
    }
  }

  /// 服务器原始消息分发：解码为对局事件后分发到对应状态。
  void _dispatchServerMessage(YgoStocMsg msg) {
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd packages/biz && flutter test test/ygo_sound_service_test.dart test/duel_message_router_test.dart`
Expected: PASS（1 + 5 个测试全绿）。

- [ ] **Step 5: 提交**

```bash
git commit -m "feat(biz): 观战跳到当前局面接线——router 观战身份驱动 + 音效 suppress" -- packages/biz/lib/ygo_sound_service.dart packages/biz/lib/duel/field/duel_message_router.dart packages/biz/test/ygo_sound_service_test.dart packages/biz/test/duel_message_router_test.dart
```

---

### Task 4: ygo_settings 持久化 + 设置弹窗「观战」区块

**Files:**
- Modify: `modules/ygo_settings/lib/ygo_settings.dart`
- Test: `modules/ygo_settings/test/ygo_settings_test.dart`

- [ ] **Step 1: 写失败测试**

`modules/ygo_settings/test/ygo_settings_test.dart` 中 buildDialog 改为：

```dart
    Widget buildDialog({
      List<SettingsExtraAction> extraActions = const [],
      ValueChanged<bool>? onAutoMonster,
      ValueChanged<bool>? onSpectateJump,
      ValueChanged<double>? onReplaySpeedFactor,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: YgoSettingsDialog(
            initialSettings: YgoSettings.defaults,
            onShowChain1Changed: (_) {},
            onAutoMonsterChanged: onAutoMonster ?? (_) {},
            onAutoSpellTrapChanged: (_) {},
            onSpectateJumpChanged: onSpectateJump ?? (_) {},
            onReplaySpeedFactorChanged: onReplaySpeedFactor ?? (_) {},
            extraActions: extraActions,
          ),
        ),
      );
    }
```

group 内追加：

```dart
    testWidgets('观战区块渲染；切换模式与速度触发回调', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var jump = false;
      var speed = 1.0;
      await tester.pumpWidget(buildDialog(
        onSpectateJump: (v) => jump = v,
        onReplaySpeedFactor: (v) => speed = v,
      ));
      expect(find.text('观战'), findsOneWidget);
      expect(find.text('带节奏回放'), findsOneWidget);
      expect(find.text('跳到当前局面'), findsOneWidget);

      await tester.tap(find.text('跳到当前局面'));
      expect(jump, isTrue);

      await tester.tap(find.text('2x'));
      expect(speed, 2.0);
    });

    test('观战回放设置持久化', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(overrides: [
        ygoSettingsProvider.overrideWith(PersistentYgoSettingsNotifier.new),
      ]);
      addTearDown(container.dispose);
      // 等异步读盘落定。
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final notifier = container.read(ygoSettingsProvider.notifier);
      notifier.setSpectateJumpToCurrent(true);
      notifier.setReplaySpeedFactor(2.0);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // 新容器模拟重启。
      final container2 = ProviderContainer(overrides: [
        ygoSettingsProvider.overrideWith(PersistentYgoSettingsNotifier.new),
      ]);
      addTearDown(container2.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final restored = container2.read(ygoSettingsProvider);
      expect(restored.spectateJumpToCurrent, isTrue);
      expect(restored.replaySpeedFactor, 2.0);
    });
```

并在文件头 import 区追加：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd modules/ygo_settings && flutter test`
Expected: FAIL — `YgoSettingsDialog` 无新回调参数 / `PersistentYgoSettingsNotifier` 无新 setter 持久化。

- [ ] **Step 3: 实现**

`modules/ygo_settings/lib/ygo_settings.dart`：

**3a.** key 与持久化（`PersistentYgoSettingsNotifier`）：

```dart
const _kChain1 = 'duel_settings.show_chain1_animation';
const _kMonster = 'duel_settings.auto_monster_position';
const _kSpellTrap = 'duel_settings.auto_spell_trap_position';
const _kSpectateJump = 'duel_settings.spectate_jump_to_current';
const _kReplaySpeed = 'duel_settings.replay_speed_factor';
```

`_load` 的 copyWith 加两行：

```dart
      spectateJumpToCurrent:
          prefs.getBool(_kSpectateJump) ?? state.spectateJumpToCurrent,
      replaySpeedFactor:
          prefs.getDouble(_kReplaySpeed) ?? state.replaySpeedFactor,
```

notifier 追加：

```dart
  @override
  void setSpectateJumpToCurrent(bool value) {
    super.setSpectateJumpToCurrent(value);
    _persist(_kSpectateJump, value);
  }

  @override
  void setReplaySpeedFactor(double value) {
    super.setReplaySpeedFactor(value);
    _persistDouble(_kReplaySpeed, value);
  }

  Future<void> _persistDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }
```

**3b.** 弹窗：构造函数加两个必传回调，state 加两个字段，build 加「观战」区块。

构造函数：

```dart
  const YgoSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.onShowChain1Changed,
    required this.onAutoMonsterChanged,
    required this.onAutoSpellTrapChanged,
    required this.onSpectateJumpChanged,
    required this.onReplaySpeedFactorChanged,
    this.extraActions = const [],
  });

  final YgoSettings initialSettings;
  final ValueChanged<bool> onShowChain1Changed;
  final ValueChanged<bool> onAutoMonsterChanged;
  final ValueChanged<bool> onAutoSpellTrapChanged;

  /// 观战回放模式切换（true = 跳到当前局面）。
  final ValueChanged<bool> onSpectateJumpChanged;

  /// 回放速度倍率切换（0.5/1/2/4）。
  final ValueChanged<double> onReplaySpeedFactorChanged;
```

state 字段与 initState：

```dart
  late bool _showChain1;
  late bool _autoMonster;
  late bool _autoSpellTrap;
  late bool _spectateJump;
  late double _replaySpeedFactor;

  @override
  void initState() {
    super.initState();
    _showChain1 = widget.initialSettings.showChain1Animation;
    _autoMonster = widget.initialSettings.autoMonsterPosition;
    _autoSpellTrap = widget.initialSettings.autoSpellTrapPosition;
    _spectateJump = widget.initialSettings.spectateJumpToCurrent;
    _replaySpeedFactor = widget.initialSettings.replaySpeedFactor;
  }
```

build 的 Column children 中，在三个 SwitchListTile 之后、附加动作之前插入：

```dart
            // ── 观战 ──
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '观战',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.play_circle_outline),
                      label: Text('带节奏回放'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.fast_forward),
                      label: Text('跳到当前局面'),
                    ),
                  ],
                  selected: {_spectateJump},
                  onSelectionChanged: (selection) {
                    setState(() => _spectateJump = selection.first);
                    widget.onSpectateJumpChanged(selection.first);
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '中途进入观战时，开局以来的历史消息如何呈现',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<double>(
                  segments: const [
                    ButtonSegment(value: 0.5, label: Text('0.5x')),
                    ButtonSegment(value: 1.0, label: Text('1x')),
                    ButtonSegment(value: 2.0, label: Text('2x')),
                    ButtonSegment(value: 4.0, label: Text('4x')),
                  ],
                  selected: {_replaySpeedFactor},
                  onSelectionChanged: (selection) {
                    setState(() => _replaySpeedFactor = selection.first);
                    widget.onReplaySpeedFactorChanged(selection.first);
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '带节奏回放的播放速度；跳到当前局面时无效',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ),
```

**3c.** 两个 show 入口接线（`showGlobalSettingsDialog` 与 `showYgoSettingsDialog` 的 YgoSettingsDialog 构造各加两行）：

```dart
      onSpectateJumpChanged: notifier.setSpectateJumpToCurrent,
      onReplaySpeedFactorChanged: notifier.setReplaySpeedFactor,
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd modules/ygo_settings && flutter test`
Expected: PASS（全部测试，含既有用例适配新必传参数后）。

- [ ] **Step 5: 提交**

```bash
git commit -m "feat(ygo_settings): 观战回放模式与回放速度设置（持久化 + 弹窗）" -- modules/ygo_settings/lib/ygo_settings.dart modules/ygo_settings/test/ygo_settings_test.dart
```

---

### Task 5: 全量回归

**Files:** 无新增改动（仅验证）。

- [ ] **Step 1: biz 全量测试**（排除用户未跟踪的 WIP 文件）

Run: `cd packages/biz && flutter test \$(ls test/*.dart | grep -v zone_browser_activatable | tr '\n' ' ')`
Expected: 全部 PASS。

- [ ] **Step 2: ygo_settings 全量测试**

Run: `cd modules/ygo_settings && flutter test`
Expected: 全部 PASS。

- [ ] **Step 3: 静态检查**

Run: `cd packages/biz && flutter analyze lib/duel/field/message_pump.dart lib/duel/field/duel_message_router.dart lib/ygo_settings.dart lib/ygo_sound_service.dart test/message_pump_test.dart test/duel_message_router_test.dart test/ygo_sound_service_test.dart`
Run: `cd modules/ygo_settings && flutter analyze lib test`
Expected: 无新增 error/warning 级问题。

---

## Self-Review 记录

- Spec 覆盖：设置契约两字段 ✓（Task 2）、持久化 ✓（Task 4-3a）、弹窗区块 ✓（Task 4-3b）、泵 jump/speedFactor ✓（Task 1）、suppress 静音 ✓（Task 3-3a/3b）、观战身份门控 ✓（Task 3-3b）、运行时设置生效 ✓（build 内 ref.listen）。
- 类型一致性：consume 签名 `void Function(T, {required bool silent})` 在泵/测试/router（`_handleServerMessage` 可选命名参数可赋值给 required 位）一致；`intervalForBacklog` 实例化后所有引用点已更新。
- 无占位符：所有步骤含完整代码与确切命令。
