import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:duelink_ai/duelink_ai.dart';
import 'package:flutter_test/flutter_test.dart';

// ============================================================
// 测试用卡牌常量（与 src/test_card_data.dart 的 kTestCards 对应）
// ============================================================
const kBlueEyes = 89631139; // 青眼白龙 ATK 3000 / DEF 2500
const kDarkMagician = 46986414; // 黑魔导 ATK 2500 / DEF 2100
const kMysticalElf = 15025844; // 圣精灵 ATK 800 / DEF 2000
const kCelticGuardian = 91152256; // 精灵剑士 ATK 1400 / DEF 1200
const kGiantSoldier = 13039848; // 岩石巨兵 ATK 1300 / DEF 2000
const kGaiaFierceKnight = 6368038; // 暗黑骑士盖亚 ATK 2300 / DEF 2100
const kCurseOfDragon = 28279543; // 诅咒之龙 ATK 2000 / DEF 1500
const kRedEyes = 74677422; // 真红眼黑龙 ATK 2400 / DEF 2000
const kBabyDragon = 88819587; // 宝贝龙 ATK 1200 / DEF 700
const kHitotsuMe = 76184692; // 独眼巨人 ATK 1200 / DEF 1000
const kPotOfGreed = 55144522; // 强欲之壶 (魔法卡)
const kTrapHole = 4206964; // 落穴 (陷阱卡)

/// 显式加载 ocgcore 动态库（flutter_tester 环境默认查找路径找不到，
/// 需要像旧的 ocgcore 测试一样按相对路径打开后注入）。
ffi.DynamicLibrary? _loadCoreLib() {
  if (Platform.isMacOS) {
    for (final p in [
      '../ocgcore/macos/Frameworks/libocgcore.dylib',
      'macos/Frameworks/libocgcore.dylib',
    ]) {
      try {
        return ffi.DynamicLibrary.open(p);
      } catch (_) {}
    }
  }
  return null; // 其他平台走 createOcgCore 的默认查找
}

// ============================================================
// 工具函数
// ============================================================

/// 将 card code 列表编码为 Uint8List（4 字节 LE 每个 code），供 submitDeck 使用。
Uint8List _encodeDeck(List<int> codes) {
  final bytes = Uint8List(codes.length * 4);
  final data = ByteData.view(bytes.buffer);
  for (int i = 0; i < codes.length; i++) {
    data.setInt32(i * 4, codes[i], Endian.little);
  }
  return bytes;
}

/// 构建测试用主卡组。
/// 包含多种怪兽 + 强欲之壶 + 落穴，双方使用相同卡组。
///
/// 注意：房间选项 noShuffle=true，**牌库顶 = 列表前部**，起手 5 张固定为
/// 前 5 张。因此把剧本需要的卡（低星怪兽 / 强欲之壶 / 落穴）放在最前面，
/// 保证剧本步骤确定性可执行。
List<int> _buildTestDeck() {
  return [
    // ── 起手 5 张（剧本依赖）──
    kCelticGuardian, // 通召对象（1400 攻，可触发对方落穴）
    kHitotsuMe,
    kGiantSoldier,
    kPotOfGreed, // 操作 2 发动对象
    kTrapHole, // 操作 3 盖放对象
    // ── 其余 15 张 ──
    kBlueEyes,
    kCelticGuardian,
    kCelticGuardian,
    kHitotsuMe,
    kHitotsuMe,
    kGiantSoldier,
    kGiantSoldier,
    kMysticalElf,
    kBabyDragon,
    kPotOfGreed,
    kPotOfGreed,
    kPotOfGreed,
    kTrapHole,
    kTrapHole,
    kTrapHole,
  ];
}

/// 在 [messages] 列表中查找 func == [funcId] 的消息。不消费（不移除）。
bool _hasGameMsg(List<YgoStocMsg> messages, int funcId) {
  return messages.any((m) => m.gameMsg?.func == funcId);
}

/// 共享消息游标 — 测试中对 onServerMessage 的所有等待/应答都通过
/// 单一的 allMsgs 列表 + 游标顺序消费，避免多个 broadcast 监听者
/// 各自 `.first` 造成的应答竞争/重复应答。
class _MsgCursor {
  _MsgCursor(this.messages);

  final List<YgoStocMsg> messages;
  int index = 0;

  /// 顺序取出下一条消息；没有则返回 null。
  YgoStocMsg? peek() => index < messages.length ? messages[index++] : null;

  /// 等待出现满足 [test] 的消息并消费它（游标越过该消息；
  /// 期间跳过的消息由 [takeUntil] 的调用方负责处理）。
  Future<YgoStocMsg?> waitFor(
    bool Function(YgoStocMsg m) test, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (var i = index; i < messages.length; i++) {
        if (test(messages[i])) {
          index = i + 1;
          return messages[i];
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return null;
  }
}

/// 消息内是否属于人类玩家（player 0）的选择类询问。
bool _isHumanPrompt(StocGameMessage gm) {
  try {
    return ((gm.innerMsg as dynamic).player as int?) == 0;
  } catch (_) {
    return false;
  }
}

/// 按 flag 位图选第一个可用的己方格子。
///
/// ocgcore 线格式：bit0-6 = 己方怪兽区，bit8-14 = 己方魔陷区，
/// bit16+ 为对方区域；置位 = 禁用（见 playerop.cpp select_place）。
CtosSelectPlace _firstFreePlace(MsgSelectPlace m) {
  for (var s = 0; s <= 4; s++) {
    if (m.field & (1 << s) == 0) {
      return CtosSelectPlace(
          player: m.player, zone: CARD_ZONE_MZONE, sequence: s);
    }
  }
  for (var s = 0; s <= 4; s++) {
    if (m.field & (1 << (8 + s)) == 0) {
      return CtosSelectPlace(
          player: m.player, zone: CARD_ZONE_SZONE, sequence: s);
    }
  }
  // 兜底：额外怪兽区
  return CtosSelectPlace(player: m.player, zone: CARD_ZONE_MZONE, sequence: 5);
}

/// 应答单个人类方的选择类消息（被动策略：不连锁、不发动、直接结束）。
/// 返回是否应答了该消息。
bool _answerHumanPrompt(
    AiDuelService service, StocGameMessage gm, {required bool endTurn}) {
  if (!_isHumanPrompt(gm)) return false;
  switch (gm.func) {
    case MSG_SELECT_IDLE_CMD:
      final cmd = gm.innerMsg as MsgSelectIdleCmd;
      if (!endTurn) return false; // 剧本阶段由调用方自己决定
      if (cmd.enableEp) {
        service.playGameResponse(CtosGameMsgResponse.selectIdleCmd(7));
      } else if (cmd.enableBp) {
        service.playGameResponse(CtosGameMsgResponse.selectIdleCmd(6));
      } else {
        return false;
      }
      return true;

    case MSG_SELECT_BATTLE_CMD:
      final cmd = gm.innerMsg as MsgSelectBattleCmd;
      if (cmd.enableEp) {
        service.playGameResponse(CtosGameMsgResponse.selectBattleCmd(3));
      } else if (cmd.enableM2) {
        service.playGameResponse(CtosGameMsgResponse.selectBattleCmd(2));
      } else if (cmd.commandGroups[1].options.isNotEmpty) {
        service.playGameResponse(CtosGameMsgResponse.selectBattleCmd(
            cmd.commandGroups[1].options.first.response));
      } else {
        return false;
      }
      return true;

    case MSG_SELECT_CHAIN:
      // 不连锁 (-1)
      service.playGameResponse(CtosGameMsgResponse.selectIdleCmd(-1));
      return true;

    case MSG_SELECT_EFFECTYN:
      service.playGameResponse(CtosGameMsgResponse.selectEffectYn(0));
      return true;

    case MSG_SELECT_YES_NO:
      service.playGameResponse(CtosGameMsgResponse.selectEffectYn(0));
      return true;

    case MSG_SELECT_OPTION:
      service.playGameResponse(CtosGameMsgResponse.selectOption(0));
      return true;

    case MSG_SELECT_PLACE:
    case MSG_SELECT_DISFIELD:
      final selPlace = gm.innerMsg as MsgSelectPlace;
      service.playGameResponse(
          CtosGameMsgResponse.selectPlace(_firstFreePlace(selPlace)));
      return true;

    case MSG_SELECT_POSITION:
      service.playGameResponse(
          CtosGameMsgResponse.selectPosition(POS_FACEUP_ATTACK));
      return true;

    case MSG_SELECT_CARD:
      final selCard = gm.innerMsg as MsgSelectCard;
      if (selCard.count > 0) {
        service.playGameResponse(CtosGameMsgResponse.selectMulti([0]));
        return true;
      }
      return false;
  }
  return false;
}

/// 顺序消费消息，应答途中的交互提示，直到拿到下一个人类主阶段
/// [MSG_SELECT_IDLE_CMD]（剧本阶段召唤/盖放后的位置选择在这里完成）。
Future<MsgSelectIdleCmd?> _nextHumanIdleCmd(
  AiDuelService service,
  _MsgCursor cursor, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final m = cursor.peek();
    if (m == null) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      continue;
    }
    final gm = m.gameMsg;
    if (gm == null) continue;
    if (gm.func == MSG_SELECT_IDLE_CMD && _isHumanPrompt(gm)) {
      return gm.innerMsg as MsgSelectIdleCmd;
    }
    _answerHumanPrompt(service, gm, endTurn: false);
  }
  return null;
}

/// 剧本阶段结束后的自动驾驶：被动应答所有人类提示（直接结束回合），
/// 直到决斗结束（MSG_WIN / STOC_DUEL_END）。返回是否等到决斗结束。
Future<bool> _autopilotUntilDuelEnd(
  AiDuelService service,
  _MsgCursor cursor, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final m = cursor.peek();
    if (m == null) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      continue;
    }
    if (m.protoId == STOC_DUEL_END) return true;
    final gm = m.gameMsg;
    if (gm == null) continue;
    if (gm.func == MSG_WIN) return true;
    _answerHumanPrompt(service, gm, endTurn: true);
  }
  return false;
}

// ============================================================
// 测试主体
// ============================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ----------------------------------------------------------
  // 完整决斗流程测试
  // 开始 → 猜拳 → 选先后攻 → 决斗开始 →
  // A 回合: 召唤 → 发动强欲 → 盖放落穴 → 结束 →
  // 之后 AI 自动进行，人类被动结束回合，直到分出胜负
  // ----------------------------------------------------------
  test(
    '完整决斗流程: 召唤/魔法发动/陷阱盖放/AI对局/决斗结束',
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      // ---- 初始化 ----
      final service = AiDuelService(lib: _loadCoreLib());
      final allMsgs = <YgoStocMsg>[];
      final allStages = <RoomStage>[];
      final allPhases = <DuelPhase>[];
      final cursor = _MsgCursor(allMsgs);

      // 订阅消息流（只观察，不应答，避免与 cursor 竞争）
      final msgSub = service.onServerMessage.listen(allMsgs.add);
      final stageSub = service.onRoomStageChange.listen(allStages.add);
      final phaseSub = service.onDuelPhaseMessage.listen(allPhases.add);

      addTearDown(() async {
        await msgSub.cancel();
        await stageSub.cancel();
        await phaseSub.cancel();
        await service.disconnect();
      });

      // ========================================================
      // 阶段 1: 连接 → 进入房间 → 提交卡组 → 准备
      // ========================================================
      await service.connect(Uri.parse("ai://localhost:8080"));
      // broadcast 状态流是异步派发的，给一拍再断言
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.connectionState, ConnectionState.connected,
          reason: 'ocgcore 动态库应加载成功并进入 connected');

      service.setPlayerName('TestPlayer');
      service.enterRoom(RoomPassword.encodeJoin());

      // 提交 20 张卡的主卡组
      final deck = _buildTestDeck();
      service.submitDeck(_encodeDeck(deck), Uint8List(0));
      service.ready();

      // ========================================================
      // 阶段 2: 猜拳（AI 固定剪刀，人类石头必胜）→ 选择先后攻
      // ========================================================
      final selectHand = await cursor.waitFor(
        (m) => m.protoId == STOC_SELECT_HAND,
        timeout: const Duration(seconds: 5),
      );
      expect(selectHand, isNotNull, reason: 'ready 后应收到 STOC_SELECT_HAND');

      // 猜拳：石头(2) 胜 AI 的剪刀(1)
      service.chooseHand(HandType.rock);

      // 人类赢 → 应收到 SELECT_TP
      final selectTp = await cursor.waitFor(
        (m) => m.protoId == STOC_SELECT_TP,
        timeout: const Duration(seconds: 5),
      );
      expect(selectTp, isNotNull, reason: '猜拳获胜后应收到 STOC_SELECT_TP');

      service.chooseTurnOrder(true); // 先攻

      // ========================================================
      // 阶段 3: 决斗开始 → A 回合
      // ========================================================
      final idleCmd1 = await _nextHumanIdleCmd(service, cursor);
      if (idleCmd1 == null) {
        printAll(allMsgs, allStages, allPhases);
      }
      expect(idleCmd1, isNotNull,
          reason: '应该收到 MSG_SELECT_IDLE_CMD（A 的主阶段）');
      if (idleCmd1 == null) {
        return;
      }

      // ── A 操作 1: 召唤怪兽（手牌首个可通召的是精灵剑士 1400）──
      final summonGroup = idleCmd1.commandGroups[0]; // summon
      expect(summonGroup.options.isNotEmpty, isTrue,
          reason: '初始手牌应有可通常召唤的怪兽');
      service.playGameResponse(
          CtosGameMsgResponse.selectIdleCmd(summonGroup.options.first.response));

      // 召唤流程中的选位/选表示形式由 _nextHumanIdleCmd 代答
      final idleCmd2 = await _nextHumanIdleCmd(service, cursor);
      if (idleCmd2 == null) printAll(allMsgs, allStages, allPhases);
      expect(idleCmd2, isNotNull, reason: '召唤后应回到主阶段');

      // ── A 操作 2: 发动强欲之壶 ──
      if (idleCmd2 != null) {
        final activateGroup = idleCmd2.commandGroups[5]; // activate
        for (final o in activateGroup.options) {
          if (o.cardInfo.code == kPotOfGreed) {
            service.playGameResponse(
                CtosGameMsgResponse.selectIdleCmd(o.response));
            break;
          }
        }
      }

      final idleCmd3 = await _nextHumanIdleCmd(service, cursor);
      if (idleCmd3 == null) printAll(allMsgs, allStages, allPhases);
      expect(idleCmd3, isNotNull, reason: '发动强欲之壶后应回到主阶段');

      // ── A 操作 3: 盖放落穴 ──
      if (idleCmd3 != null) {
        final ssetGroup = idleCmd3.commandGroups[4]; // sset
        for (final o in ssetGroup.options) {
          if (o.cardInfo.code == kTrapHole) {
            service.playGameResponse(
                CtosGameMsgResponse.selectIdleCmd(o.response));
            break;
          }
        }
      }

      final idleCmd4 = await _nextHumanIdleCmd(service, cursor);
      if (idleCmd4 == null) printAll(allMsgs, allStages, allPhases);
      expect(idleCmd4, isNotNull, reason: '盖放落穴后应回到主阶段');

      // ── A 操作 4: 结束回合（第一回合不能进战阶，直接 EP）──
      if (idleCmd4 != null) {
        if (idleCmd4.enableEp) {
          service.playGameResponse(CtosGameMsgResponse.selectIdleCmd(7));
        } else if (idleCmd4.enableBp) {
          service.playGameResponse(CtosGameMsgResponse.selectIdleCmd(6));
        }
      }

      // ========================================================
      // 阶段 4: 之后交由 AI 与自动驾驶对局，直到分出胜负
      // （双方 20 张卡组、每回合抽 1，最迟卡组抽完结束）
      // ========================================================
      final duelFinished = await _autopilotUntilDuelEnd(service, cursor);

      // ========================================================
      // 验证关键事件
      // ========================================================
      expect(allStages.any((s) => s is RoomInLobby), isTrue,
          reason: '应该进入大厅');
      expect(allStages.any((s) => s is RoomSelectingHand), isTrue,
          reason: '应该有猜拳阶段');
      expect(allStages.any((s) => s is RoomHandResult), isTrue,
          reason: '应该有猜拳结果');
      expect(allStages.any((s) => s is RoomSelectingTurn), isTrue,
          reason: '应该可以选择先后攻');
      expect(allStages.any((s) => s is RoomInDuel), isTrue,
          reason: '应该进入决斗状态');
      expect(duelFinished, isTrue, reason: '决斗应该结束（MSG_WIN 或 STOC_DUEL_END）');

      // 检查是否有召唤相关消息
      final hasSummoning = _hasGameMsg(allMsgs, MSG_SUMMONING);
      final hasSummoned = _hasGameMsg(allMsgs, MSG_SUMMONED);
      print('=== 决斗流程验证 ===');
      print('  RoomStates: ${allStages.map((s) => s.runtimeType).join(' → ')}');
      print('  有召唤中消息: $hasSummoning');
      print('  有召唤完成消息: $hasSummoned');
      print('  有伤害消息: ${_hasGameMsg(allMsgs, MSG_DAMAGE)}');
      print('  有LP更新消息: ${_hasGameMsg(allMsgs, MSG_LP_UPDATE)}');
      print('  有攻击消息: ${_hasGameMsg(allMsgs, MSG_ATTACK)}');
      print('  有战斗消息: ${_hasGameMsg(allMsgs, MSG_BATTLE)}');
      print('  有抽卡消息: ${_hasGameMsg(allMsgs, MSG_DRAW)}');
      print('  有新回合消息: ${_hasGameMsg(allMsgs, MSG_NEW_TURN)}');
      print('  决斗结束: $duelFinished');
      print(
          '  总消息数: ${allMsgs.length} (其中 gameMsg: ${allMsgs.where((m) => m.gameMsg != null).length})');
      print('===================');

      expect(hasSummoning, isTrue, reason: 'A 回合应有召唤消息');
      expect(_hasGameMsg(allMsgs, MSG_NEW_TURN), isTrue,
          reason: '应该历经过多个回合');
    },
  );

  // ----------------------------------------------------------
  // 简化快速测试：仅验证房间流程（不进入决斗细节）
  // ----------------------------------------------------------
  test(
    '房间流程: 连接→猜拳→选先攻→进入决斗',
    timeout: const Timeout(Duration(minutes: 1)),
    () async {
      final service = AiDuelService(lib: _loadCoreLib());
      final allMsgs = <YgoStocMsg>[];
      final allStages = <RoomStage>[];
      final cursor = _MsgCursor(allMsgs);

      final msgSub = service.onServerMessage.listen(allMsgs.add);
      final stageSub = service.onRoomStageChange.listen(allStages.add);

      addTearDown(() async {
        await msgSub.cancel();
        await stageSub.cancel();
        await service.disconnect();
      });

      await service.connect(Uri());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.connectionState, ConnectionState.connected);

      service.setPlayerName('QuickTest');
      service.enterRoom(RoomPassword.encodeJoin());
      final deck = _buildTestDeck();
      service.submitDeck(_encodeDeck(deck), Uint8List(0));
      service.ready();

      // 等待猜拳阶段
      final selectHand = await cursor.waitFor(
        (m) => m.protoId == STOC_SELECT_HAND,
        timeout: const Duration(seconds: 5),
      );
      expect(selectHand, isNotNull, reason: 'ready 后应进入猜拳');

      // 石头（胜 AI 的剪刀）
      service.chooseHand(HandType.rock);

      // 等待 SELECT_TP 后选先攻
      await cursor.waitFor((m) => m.protoId == STOC_SELECT_TP,
          timeout: const Duration(seconds: 5));
      service.chooseTurnOrder(true);

      // 等待决斗开始消息
      await cursor.waitFor(
        (m) => m.protoId == STOC_DUEL_START,
        timeout: const Duration(seconds: 10),
      );

      final stageNames =
          allStages.map((s) => s.runtimeType.toString()).toList();
      print('房间流程阶段: ${stageNames.join(" → ")}');

      expect(allStages.any((s) => s is RoomInLobby), isTrue);
      expect(allStages.any((s) => s is RoomSelectingHand), isTrue);
      expect(allStages.any((s) => s is RoomHandResult), isTrue);
      expect(
          allStages.any((s) => s is RoomSelectingTurn) ||
              allStages.any((s) => s is RoomInDuel),
          isTrue);
    },
  );
}

// ============================================================
// 辅助函数
// ============================================================

/// 调试输出：打印所有收集到的消息和阶段
void printAll(
  List<YgoStocMsg> msgs,
  List<RoomStage> stages,
  List<DuelPhase> phases,
) {
  print('\n=== 收集到的 RoomStages ===');
  for (final s in stages) {
    print('  $s');
  }

  print('\n=== 收集到的 DuelPhases ===');
  for (final p in phases) {
    print('  $p');
  }

  print('\n=== 收集到的 STOC Messages ===');
  for (final m in msgs) {
    final gm = m.gameMsg;
    if (gm != null) {
      print(
          '  STOC_GAME_MSG func=${gm.func} (0x${gm.func.toRadixString(16).padLeft(2, '0')}) inner=${gm.innerMsg.runtimeType} → $gm');
    } else {
      print('  STOC protoId=${m.protoId} → $m');
    }
  }
}
