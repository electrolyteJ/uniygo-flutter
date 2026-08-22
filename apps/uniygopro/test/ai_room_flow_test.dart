@Timeout(Duration(minutes: 3))

/// 方案 1 —— AI 对决房间流程的纯协议层测试（无 UI）。
///
/// 流程：连接 → 进房 → 提交卡组 → 准备 → 猜拳（人类石头胜 AI 剪刀）
/// → 选先攻 → MSG_START 进入决斗（RoomInDuel）。
///
/// 跨平台：
/// - `flutter test test/ai_room_flow_test.dart`（VM / macOS flutter_tester，
///   显式加载 libocgcore.dylib）
/// - `flutter test --platform chrome test/ai_room_flow_test.dart`
///   （真实无头 Chrome，ocgcore 走 WASM 适配器）
///
/// 确定性说明：[AiDuelService.fixedAiHandChoice] 固定 AI 出剪刀，否则
/// AI 伪随机出拳，赢的时候服务端不下发 STOC_SELECT_TP，「选先攻」
/// 分支无法稳定复现。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:duelink_ai/duelink_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ygo_data/ygo_data.dart' as ygo_data;

import 'support/ocgcore_lib_loader.dart';
import 'support/ocgcore_web_bootstrap.dart';

// ── 测试用卡（全部为 4 星以下通常怪兽/魔法/陷阱，无额外卡组依赖）──
const kBlueEyes = 89631139; // 青眼白龙
const kDarkMagician = 46986414; // 黑魔导
const kMysticalElf = 15025844; // 神圣精灵
const kCelticGuardian = 91152256; // 精灵剑士
const kGiantSoldier = 13039848; // 岩石巨兵
const kGaiaFierceKnight = 6368038; // 暗黑骑士盖亚
const kCurseOfDragon = 28279543; // 诅咒之龙
const kRedEyes = 74677422; // 真红眼黑龙
const kBabyDragon = 88819587; // 宝贝龙
const kHitotsuMe = 76184692; // 独眼巨人
const kPotOfGreed = 55144522; // 强欲之壶
const kTrapHole = 4206964; // 落穴

const _typeMonsterNormal = 0x11; // TYPE_MONSTER | TYPE_NORMAL
const _typeSpellNormal = 0x2; // TYPE_SPELL
const _typeTrapNormal = 0x4; // TYPE_TRAP

/// 测试卡组（20 张）。房间默认不切洗，牌库顶 = 列表前部。
List<int> _buildTestDeck() => const [
  kCelticGuardian,
  kHitotsuMe,
  kGiantSoldier,
  kPotOfGreed,
  kTrapHole,
  kBlueEyes,
  kDarkMagician,
  kMysticalElf,
  kGaiaFierceKnight,
  kCurseOfDragon,
  kRedEyes,
  kBabyDragon,
  kCelticGuardian,
  kHitotsuMe,
  kGiantSoldier,
  kMysticalElf,
  kBabyDragon,
  kPotOfGreed,
  kTrapHole,
  kBlueEyes,
];

Uint8List _encodeDeck(List<int> codes) {
  final bytes = Uint8List(codes.length * 4);
  final data = ByteData.view(bytes.buffer);
  for (var i = 0; i < codes.length; i++) {
    data.setInt32(i * 4, codes[i], Endian.little);
  }
  return bytes;
}

/// 为引擎提供卡数据（不依赖 App 的卡库服务，保证测试自包含、跨平台）。
Future<ygo_data.CardInfo?> _testCardConverter(int code) async {
  const levels = <int, int>{
    kBlueEyes: 8,
    kDarkMagician: 7,
    kGaiaFierceKnight: 7,
    kCurseOfDragon: 5,
    kRedEyes: 7,
    kCelticGuardian: 4,
    kMysticalElf: 4,
    kGiantSoldier: 4,
    kBabyDragon: 3,
    kHitotsuMe: 2,
  };
  final type = switch (code) {
    kPotOfGreed => _typeSpellNormal,
    kTrapHole => _typeTrapNormal,
    _ => _typeMonsterNormal,
  };
  return ygo_data.CardInfo(
    code: code,
    type: type,
    level: levels[code] ?? 4,
    attribute: 0x1, // 地
    race: 0x1, // 战士
    attack: 1400,
    defense: 1200,
    name: 'test-$code',
  );
}

/// 等待 [items] 中出现满足 [test] 的元素（列表由订阅侧持续追加）。
Future<T?> _waitFor<T>(
  List<T> items,
  bool Function(T) test, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    for (final item in items) {
      if (test(item)) return item;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Web（chrome）下注入 WASM 脚本并架设资产 fetch 通道；VM 为空操作。
  ensureOcgCoreWebScripts();

  test('AI 房间流程: 连接→猜拳→选先攻→进入决斗', () async {
    final service = AiDuelService(lib: loadOcgCoreLib());
    service.setCardConverter(_testCardConverter);
    // 确定性：AI 固定剪刀，人类石头必胜 → 必然走到「选先攻」分支。
    service.fixedAiHandChoice = HandType.scissors.value;

    final stages = <RoomStage>[];
    final msgs = <YgoStocMsg>[];
    final stageSub = service.onRoomStageChange.listen(stages.add);
    final msgSub = service.onServerMessage.listen(msgs.add);

    addTearDown(() async {
      await stageSub.cancel();
      await msgSub.cancel();
      await service.disconnect();
    });

    // ── 1. 连接（本地 ocgcore 引擎初始化）──
    await service.connect(Uri.parse('ai://localhost:0'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      service.connectionState,
      ConnectionConnected,
      reason: 'ocgcore 引擎应初始化成功（Web 走 WASM，VM 走 dylib）',
    );

    // ── 2. 进房 → 提交卡组 → 准备 ──
    service.setPlayerName('FlowTest');
    service.enterRoom(RoomPassword.encodeJoin());
    service.submitDeck(_encodeDeck(_buildTestDeck()), Uint8List(0));
    service.ready();
    // ready 只是就绪标记（对齐线上服务器与 duelink_ai 的房间流程语义），
    // 房主需显式 HS_START 开局。
    service.startDuel();

    // ── 3. 猜拳：收到 STOC_SELECT_HAND → 出石头 ──
    final selectHand = await _waitFor(
      msgs,
      (m) => m.protoId == STOC_SELECT_HAND,
    );
    expect(selectHand, isNotNull, reason: 'ready 后应收到 STOC_SELECT_HAND');
    expect(stages.any((s) => s is RoomInLobby), isTrue, reason: '应先进大厅');

    service.chooseHand(HandType.rock);

    final handResult = await _waitFor(
      msgs,
      (m) => m.protoId == STOC_HAND_RESULT,
    );
    expect(handResult, isNotNull, reason: '出拳后应收到 STOC_HAND_RESULT');

    // ── 4. 人类胜 → 收到 STOC_SELECT_TP → 选先攻 ──
    final selectTp = await _waitFor(msgs, (m) => m.protoId == STOC_SELECT_TP);
    expect(selectTp, isNotNull, reason: '猜拳获胜后应收到 STOC_SELECT_TP');
    expect(
      stages.any((s) => s is RoomSelectingTurn),
      isTrue,
      reason: '应进入选先攻阶段',
    );

    service.chooseTurnOrder(true);

    // ── 5. MSG_START → 进入决斗 ──
    final inDuel = await _waitFor(
      stages,
      (s) => s is RoomInDuel,
      timeout: const Duration(seconds: 60),
    );
    if (inDuel == null) {
      fail(
        '未进入决斗。stage 序列: '
        '${stages.map((s) => s.runtimeType).join(' → ')}',
      );
    }
    expect(
      (inDuel as RoomInDuel).isFirstTurn,
      isTrue,
      reason: '人类选先攻，MSG_START 应标记为先攻方',
    );

    // ── 阶段序列完整性 ──
    final stageNames = stages.map((s) => s.runtimeType.toString()).toList();
    // ignore: avoid_print
    print('AI 房间流程阶段: ${stageNames.join(' → ')}');
    expect(stages.any((s) => s is RoomSelectingHand), isTrue);
    expect(stages.any((s) => s is RoomHandResult), isTrue);
    expect(stages.any((s) => s is RoomSelectingTurn), isTrue);
  });
}
