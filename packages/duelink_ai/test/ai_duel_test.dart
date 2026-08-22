import 'dart:async';
import 'dart:typed_data';

import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:duelink_ai/duelink_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_harness.dart';

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
      final service = AiDuelService(
        lib: loadCoreLib(),
        scriptLoader: FileScriptLoader(),
      );
      injectTestCards(service);
      // AI 固定出剪刀(1)，人类石头必胜 → 确定性走 SELECT_TP 分支
      service.fixedAiHandChoice = 1;
      final allMsgs = <YgoStocMsg>[];
      final allStages = <RoomStage>[];
      final allPhases = <DuelPhase>[];
      final cursor = MsgCursor(allMsgs);

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
      expect(
        service.connectionState,
        ConnectionConnected(),
        reason: 'ocgcore 动态库应加载成功并进入 connected',
      );

      service.setPlayerName('TestPlayer');
      service.enterRoom(RoomPassword.encodeJoin());

      // 提交 20 张卡的主卡组
      final deck = buildTestDeck();
      service.submitDeck(encodeDeck(deck), Uint8List(0));
      service.ready();
      // ready 只是就绪标记（对齐线上服务器）：房主显式 HS_START 才开局。
      service.startDuel();

      // ========================================================
      // 阶段 2: 猜拳（AI 固定剪刀，人类石头必胜）→ 选择先后攻
      // ========================================================
      final selectHand = await cursor.waitFor(
        (m) => m.protoId == STOC_SELECT_HAND,
        timeout: const Duration(seconds: 5),
      );
      expect(selectHand, isNotNull, reason: 'startDuel 后应收到 STOC_SELECT_HAND');

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
      final idleCmd1 = await nextHumanIdleCmd(service, cursor);
      if (idleCmd1 == null) {
        printAll(allMsgs, allStages, allPhases);
      }
      expect(idleCmd1, isNotNull, reason: '应该收到 MSG_SELECT_IDLE_CMD（A 的主阶段）');
      if (idleCmd1 == null) {
        return;
      }

      // ── A 操作 1: 召唤怪兽（手牌首个可通召的是精灵剑士 1400）──
      final summonGroup = idleCmd1.commandGroups[0]; // summon
      expect(summonGroup.options.isNotEmpty, isTrue, reason: '初始手牌应有可通常召唤的怪兽');
      service.playGameResponse(
        CtosGameMsgResponse.selectIdleCmd(summonGroup.options.first.response),
      );

      // 召唤流程中的选位/选表示形式由 nextHumanIdleCmd 代答
      final idleCmd2 = await nextHumanIdleCmd(service, cursor);
      if (idleCmd2 == null) printAll(allMsgs, allStages, allPhases);
      expect(idleCmd2, isNotNull, reason: '召唤后应回到主阶段');

      // ── A 操作 2: 发动强欲之壶 ──
      if (idleCmd2 != null) {
        final activateGroup = idleCmd2.commandGroups[5]; // activate
        for (final o in activateGroup.options) {
          if (o.cardInfo.code == kPotOfGreed) {
            service.playGameResponse(
              CtosGameMsgResponse.selectIdleCmd(o.response),
            );
            break;
          }
        }
      }

      final idleCmd3 = await nextHumanIdleCmd(service, cursor);
      if (idleCmd3 == null) printAll(allMsgs, allStages, allPhases);
      expect(idleCmd3, isNotNull, reason: '发动强欲之壶后应回到主阶段');

      // ── A 操作 3: 盖放落穴 ──
      if (idleCmd3 != null) {
        final ssetGroup = idleCmd3.commandGroups[4]; // sset
        for (final o in ssetGroup.options) {
          if (o.cardInfo.code == kTrapHole) {
            service.playGameResponse(
              CtosGameMsgResponse.selectIdleCmd(o.response),
            );
            break;
          }
        }
      }

      final idleCmd4 = await nextHumanIdleCmd(service, cursor);
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
      final duelFinished = await autopilotUntilDuelEnd(service, cursor);

      // ========================================================
      // 验证关键事件
      // ========================================================
      expect(allStages.any((s) => s is RoomInLobby), isTrue, reason: '应该进入大厅');
      expect(
        allStages.any((s) => s is RoomSelectingHand),
        isTrue,
        reason: '应该有猜拳阶段',
      );
      expect(
        allStages.any((s) => s is RoomHandResult),
        isTrue,
        reason: '应该有猜拳结果',
      );
      expect(
        allStages.any((s) => s is RoomSelectingTurn),
        isTrue,
        reason: '应该可以选择先后攻',
      );
      expect(allStages.any((s) => s is RoomInDuel), isTrue, reason: '应该进入决斗状态');
      expect(duelFinished, isTrue, reason: '决斗应该结束（MSG_WIN 或 STOC_DUEL_END）');

      // 检查是否有召唤相关消息
      final hasSummoning = hasGameMsg(allMsgs, MSG_SUMMONING);
      final hasSummoned = hasGameMsg(allMsgs, MSG_SUMMONED);
      print('=== 决斗流程验证 ===');
      print('  RoomStates: ${allStages.map((s) => s.runtimeType).join(' → ')}');
      print('  有召唤中消息: $hasSummoning');
      print('  有召唤完成消息: $hasSummoned');
      print('  有伤害消息: ${hasGameMsg(allMsgs, MSG_DAMAGE)}');
      print('  有LP更新消息: ${hasGameMsg(allMsgs, MSG_LP_UPDATE)}');
      print('  有攻击消息: ${hasGameMsg(allMsgs, MSG_ATTACK)}');
      print('  有战斗消息: ${hasGameMsg(allMsgs, MSG_BATTLE)}');
      print('  有抽卡消息: ${hasGameMsg(allMsgs, MSG_DRAW)}');
      print('  有新回合消息: ${hasGameMsg(allMsgs, MSG_NEW_TURN)}');
      print('  决斗结束: $duelFinished');
      print(
        '  总消息数: ${allMsgs.length} (其中 gameMsg: ${allMsgs.where((m) => m.gameMsg != null).length})',
      );
      print('===================');

      expect(hasSummoning, isTrue, reason: 'A 回合应有召唤消息');
      expect(hasGameMsg(allMsgs, MSG_NEW_TURN), isTrue, reason: '应该历经过多个回合');
    },
  );

  // ----------------------------------------------------------
  // 简化快速测试：仅验证房间流程（不进入决斗细节）
  // ----------------------------------------------------------
  test(
    '房间流程: 连接→猜拳→选先攻→进入决斗',
    timeout: const Timeout(Duration(minutes: 1)),
    () async {
      final service = AiDuelService(
        lib: loadCoreLib(),
        scriptLoader: FileScriptLoader(),
      );
      injectTestCards(service);
      // AI 固定出剪刀(1)，人类石头必胜 → 确定性走 SELECT_TP 分支
      service.fixedAiHandChoice = 1;
      final allMsgs = <YgoStocMsg>[];
      final allStages = <RoomStage>[];
      final cursor = MsgCursor(allMsgs);

      final msgSub = service.onServerMessage.listen(allMsgs.add);
      final stageSub = service.onRoomStageChange.listen(allStages.add);

      addTearDown(() async {
        await msgSub.cancel();
        await stageSub.cancel();
        await service.disconnect();
      });

      await service.connect(Uri());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.connectionState, isA<ConnectionConnected>());

      service.setPlayerName('QuickTest');
      service.enterRoom(RoomPassword.encodeJoin());
      final deck = buildTestDeck();
      service.submitDeck(encodeDeck(deck), Uint8List(0));
      service.ready();
      // ready 只是就绪标记（对齐线上服务器）：房主显式 HS_START 才开局。
      service.startDuel();

      // 等待猜拳阶段
      final selectHand = await cursor.waitFor(
        (m) => m.protoId == STOC_SELECT_HAND,
        timeout: const Duration(seconds: 5),
      );
      expect(selectHand, isNotNull, reason: 'startDuel 后应进入猜拳');

      // 石头（胜 AI 的剪刀）
      service.chooseHand(HandType.rock);

      // 等待 SELECT_TP 后选先攻
      await cursor.waitFor(
        (m) => m.protoId == STOC_SELECT_TP,
        timeout: const Duration(seconds: 5),
      );
      service.chooseTurnOrder(true);

      // 等待决斗开始消息
      await cursor.waitFor(
        (m) => m.protoId == STOC_DUEL_START,
        timeout: const Duration(seconds: 10),
      );

      final stageNames = allStages
          .map((s) => s.runtimeType.toString())
          .toList();
      print('房间流程阶段: ${stageNames.join(" → ")}');

      expect(allStages.any((s) => s is RoomInLobby), isTrue);
      expect(allStages.any((s) => s is RoomSelectingHand), isTrue);
      expect(allStages.any((s) => s is RoomHandResult), isTrue);
      expect(
        allStages.any((s) => s is RoomSelectingTurn) ||
            allStages.any((s) => s is RoomInDuel),
        isTrue,
      );
    },
  );

  // ----------------------------------------------------------
  // 回归测试：ready 不自动开局（需 HS_START）；观战/回座切换生效。
  // 对齐线上服务器：ready 仅是就绪标记；观战切换应产生
  // PLAYER_CHANGE(TO_OBSERVER) + TYPE_CHANGE(selfType=observer)。
  // ----------------------------------------------------------
  test(
    '房间流程: ready 不自动开局 / 观战切换 / startDuel 开局',
    timeout: const Timeout(Duration(minutes: 1)),
    () async {
      final service = AiDuelService(
        lib: loadCoreLib(),
        scriptLoader: FileScriptLoader(),
      );
      injectTestCards(service);
      service.fixedAiHandChoice = 1;
      final allMsgs = <YgoStocMsg>[];
      final allStages = <RoomStage>[];
      final cursor = MsgCursor(allMsgs);

      final msgSub = service.onServerMessage.listen(allMsgs.add);
      final stageSub = service.onRoomStageChange.listen(allStages.add);

      addTearDown(() async {
        await msgSub.cancel();
        await stageSub.cancel();
        await service.disconnect();
      });

      /// 轮询等待满足条件的大厅阶段快照。
      Future<RoomInLobby?> waitLobby(bool Function(RoomInLobby) test) async {
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (DateTime.now().isBefore(deadline)) {
          for (final s in allStages.whereType<RoomInLobby>()) {
            if (test(s)) return s;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        return null;
      }

      await service.connect(Uri());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.connectionState, isA<ConnectionConnected>());

      service.setPlayerName('ObserverTest');
      service.enterRoom(RoomPassword.encodeJoin());
      service.submitDeck(encodeDeck(buildTestDeck()), Uint8List(0));
      service.ready();

      // ready 后不应自动进入猜拳（回归：旧实现 ready 即开局）。
      final premature = await cursor.waitFor(
        (m) => m.protoId == STOC_SELECT_HAND,
        timeout: const Duration(milliseconds: 1500),
      );
      expect(premature, isNull, reason: 'ready 不应自动开始猜拳');

      // ---- 观战切换 ----
      service.becomeObserver();
      final obs = await waitLobby((s) => s.selfType == PlayerType.observer);
      expect(obs, isNotNull, reason: 'becomeObserver 后应进入观战大厅');
      expect(obs!.observerCount, 1, reason: '观战人数应为 1');
      expect(
        obs!.players.any((p) => p.name == 'ObserverTest'),
        isFalse,
        reason: '观战后人类玩家应离席',
      );

      // ---- 回座 ----
      service.becomeDuelist();
      final back = await waitLobby(
        (s) =>
            s.selfType == PlayerType.player1 &&
            s.players.any((p) => p.name == 'ObserverTest'),
      );
      expect(back, isNotNull, reason: 'becomeDuelist 后应回座为 player1');
      expect(back!.observerCount, 0);

      // ---- 回座后显式 startDuel 可正常开局 ----
      service.startDuel();
      final selectHand = await cursor.waitFor(
        (m) => m.protoId == STOC_SELECT_HAND,
        timeout: const Duration(seconds: 5),
      );
      expect(selectHand, isNotNull, reason: 'startDuel 后应进入猜拳');
    },
  );

  // ----------------------------------------------------------
  // 接线回归：agent=0（端侧模型）在模型资产不可用的测试环境下
  // 应安全回退规则 AI，房间/开局流程不受影响。
  // ----------------------------------------------------------
  test(
    'agent=0 端侧模型不可用时回退规则 AI 并可开局',
    timeout: const Timeout(Duration(minutes: 1)),
    () async {
      final service = AiDuelService(
        lib: loadCoreLib(),
        scriptLoader: FileScriptLoader(),
      );
      injectTestCards(service);
      service.fixedAiHandChoice = 1;
      final allMsgs = <YgoStocMsg>[];
      final allStages = <RoomStage>[];
      final cursor = MsgCursor(allMsgs);

      final msgSub = service.onServerMessage.listen(allMsgs.add);
      final stageSub = service.onRoomStageChange.listen(allStages.add);

      addTearDown(() async {
        await msgSub.cancel();
        await stageSub.cancel();
        await service.disconnect();
      });

      // agent=0：flutter test 的 rootBundle 无模型资产 → 回退规则 AI。
      await service.connect(Uri.parse('ai://localhost:8080?agent=0'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.connectionState, isA<ConnectionConnected>());

      service.setPlayerName('AgentFallbackTest');
      service.enterRoom(RoomPassword.encodeJoin());
      service.submitDeck(encodeDeck(buildTestDeck()), Uint8List(0));
      service.ready();
      service.startDuel();

      final selectHand = await cursor.waitFor(
        (m) => m.protoId == STOC_SELECT_HAND,
        timeout: const Duration(seconds: 5),
      );
      expect(selectHand, isNotNull, reason: 'agent=0 回退规则 AI 后应可开局');
    },
  );
}
