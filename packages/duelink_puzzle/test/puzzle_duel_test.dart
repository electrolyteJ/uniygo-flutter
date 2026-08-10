import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:duelink/duelink.dart';
import 'package:duelink_puzzle/duelink_puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

// ============================================================
// 残局卡牌常量（与 src/puzzle_card_data_loader.dart 的 kPuzzleCards 对应）
// ============================================================
const kZure = 79126789; // 暗黑界の骑士 祖尔（己方手牌，4 星通常可通召）

/// 显式加载 ocgcore 动态库（同 duelink_ai 集成测试）。
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
  return null;
}

/// 共享消息游标（同 duelink_ai 集成测试的消费模式）。
class _MsgCursor {
  _MsgCursor(this.messages);

  final List<YgoStocMsg> messages;
  int index = 0;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------
  // 残局冒烟测试：[WCS2006]01 Warriors of Darkness
  //
  // 残局内容：己方 LP600 / 手牌 4 张（暗黑界怪兽×3 + 强欲之棺）/
  // 场上 1 只怪兽 + 1 张盖卡 / 卡组 1 张；对方 LP7000 /
  // 场上 青眼白龙×2 + 白魔导帽。目标：本回合获胜。
  //
  // 注意：该残局的完整解法依赖 c07459013.lua / c05498296.lua 等
  // 卡牌脚本，ygopro-scripts 暂未收录，因此这里只验证摆场与开局，
  // 不做完整通关。
  // ------------------------------------------------------------
  test(
    '残局流程: 连接→进房→ready→摆场(MSG_RELOAD_FIELD)→人类主阶段',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      final service = PuzzleDuelService(lib: _loadCoreLib());
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

      // ========================================================
      // 阶段 1: 连接（URI 指定残局脚本）→ 进房 → ready 直接开局
      // ========================================================
      await service.connect(Uri.parse(
        'puzzle://local/World%20Championship/%5BWCS2006%5D01_Warriors%20of%20Darkness.lua',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.connectionState, ConnectionState.connected,
          reason: 'ocgcore 动态库应加载成功并进入 connected');

      service.setPlayerName('PuzzleTester');
      service.enterRoom(RoomPassword.encodeJoin());
      service.ready();

      // ========================================================
      // 阶段 2: 决斗开始 —— STOC_DUEL_START → MSG_START
      // ========================================================
      final duelStart = await cursor.waitFor(
        (m) => m.protoId == STOC_DUEL_START,
        timeout: const Duration(seconds: 5),
      );
      expect(duelStart, isNotNull, reason: 'ready 后应直接收到 STOC_DUEL_START');

      final msgStart = await cursor.waitFor(
        (m) => m.gameMsg?.func == MSG_START,
        timeout: const Duration(seconds: 15),
      );
      expect(msgStart, isNotNull, reason: '应收到合成的 MSG_START');
      final start = msgStart!.gameMsg!.innerMsg as MsgStart;
      expect(start.life1, 600, reason: '己方 LP 由残局脚本设定为 600');
      expect(start.life2, 7000, reason: '对方 LP 由残局脚本设定为 7000');
      expect(start.deckSize1, 1, reason: '己方卡组 1 张（Goldd）');

      // ========================================================
      // 阶段 3: 摆场消息 —— 脚本执行顺序为
      // SetAIName → ReloadFieldEnd → ShowHint，按此序断言
      // ========================================================
      final aiName = await cursor.waitFor(
        (m) => m.gameMsg?.func == MSG_AI_NAME,
        timeout: const Duration(seconds: 5),
      );
      expect(aiName, isNotNull, reason: '应收到 Debug.SetAIName 消息');

      final reload = await cursor.waitFor(
        (m) => m.gameMsg?.func == MSG_RELOAD_FIELD,
        timeout: const Duration(seconds: 5),
      );
      expect(reload, isNotNull, reason: '应收到 MSG_RELOAD_FIELD 全场刷新');
      final field = reload!.gameMsg!.innerMsg as MsgReloadField;
      expect(field.players.length, 2);
      expect(field.players[0].lp, 600);
      expect(field.players[1].lp, 7000);

      int zoneCount(int player, int zone) => field.players[player]
          .zoneActions
          .where((a) => a.zone == zone)
          .length;
      expect(zoneCount(1, CARD_ZONE_MZONE), 3,
          reason: '对方场上 3 只怪兽（青眼×2 + 白魔导帽）');
      expect(zoneCount(0, CARD_ZONE_MZONE), 1, reason: '己方场上 1 只怪兽');
      expect(zoneCount(0, CARD_ZONE_SZONE), 1, reason: '己方 1 张盖卡');
      expect(zoneCount(0, CARD_ZONE_HAND), 4, reason: '己方手牌 4 张');
      expect(zoneCount(0, CARD_ZONE_DECK), 1, reason: '己方卡组 1 张');

      final showHint = await cursor.waitFor(
        (m) => m.gameMsg?.func == MSG_SHOW_HINT,
        timeout: const Duration(seconds: 5),
      );
      expect(showHint, isNotNull, reason: '应收到 Debug.ShowHint 消息');
      expect((showHint!.gameMsg!.innerMsg as MsgShowHint).message,
          contains('Win this turn'));

      // ========================================================
      // 阶段 4: 人类主阶段 —— 首回合可攻击（DUEL_ATTACK_FIRST_TURN），
      // 手牌含可通召的 4 星怪兽（祖尔）
      // ========================================================
      YgoStocMsg? idle;
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(deadline)) {
        idle = await cursor.waitFor(
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD && _isHumanPrompt(m.gameMsg!),
          timeout: const Duration(milliseconds: 500),
        );
        if (idle != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(idle, isNotNull, reason: '应收到人类主阶段 MSG_SELECT_IDLE_CMD');
      final idleCmd = idle!.gameMsg!.innerMsg as MsgSelectIdleCmd;
      expect(idleCmd.enableBp, isTrue,
          reason: '残局首回合应可进战阶（DUEL_ATTACK_FIRST_TURN）');
      final summonGroup = idleCmd.commandGroups[0];
      expect(
        summonGroup.options.any((o) => o.cardInfo.code == kZure),
        isTrue,
        reason: '手牌应可通常召唤祖尔（4 星通常怪兽）',
      );

      // ========================================================
      // 房间阶段断言：无猜拳/先后攻，直接 RoomStartDuel → RoomInDuel
      // ========================================================
      expect(allStages.any((s) => s is RoomInLobby), isTrue);
      expect(allStages.any((s) => s is RoomSelectingHand), isFalse,
          reason: '残局不应有猜拳阶段');
      expect(allStages.any((s) => s is RoomSelectingTurn), isFalse,
          reason: '残局不应有先后攻选择');
      expect(allStages.any((s) => s is RoomStartDuel), isTrue);
      expect(allStages.any((s) => s is RoomInDuel), isTrue);

      print('=== 残局冒烟测试通过 ===');
      print('  RoomStages: ${allStages.map((s) => s.runtimeType).join(' → ')}');
      print('  总消息数: ${allMsgs.length}');
    },
  );
}
