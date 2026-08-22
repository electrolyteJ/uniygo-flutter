@Timeout(Duration(minutes: 5))
library;

/// 真机服务器（koishi.momobako.com:7211）双客户端核心决斗流程集成测试。
///
/// 流程：
///   建房/加入 → 提交卡组 → 准备 → 开始 → 猜拳(A 石头胜 B 剪刀) → A 选先攻
///   → 决斗开始(MSG_START)
///   → A 回合：通召神圣精灵(800) → 发动强欲之壶(抽2) → 盖放落穴 → 结束回合
///   → B 回合：通召精灵剑士(1400)（A 的落穴连锁询问被自动放过）
///     → 进战阶 → 攻击神圣精灵 → LP 计算(8000 - 600 = 7400) → 结束
///
/// 关键约定（与 srvpro / ocgcore 源码对齐）：
/// - koishi 是 srvpro 系服务器，建房用房间串 DSL：`<选项>#<房间名>`，
///   选项逗号分隔（M/T=模式, MR5=大师规则2020, NC=不检查卡组, NS=不洗牌）。
///   双方用**完全相同的房间串**才能匹配到同一房间。整条 ≤ 20 字符。
///   （neos-ts 的 base64 RoomPassword.encodeCreate 是 mycard 专用，koishi
///   不识别——会静默创建默认参数的房间，卡组检查开启导致含禁卡的卡组被拒。）
/// - 服务器把提交列表**前部**作为牌库顶（实测：NS 不洗牌时起手 5 张 =
///   列表前 5 张），剧本卡必须放在列表最前面。
///   （与 ocgcore `draw` 取 `list_main.back()` 对应——服务器装载卡组时
///   的顺序使得 back() 是提交列表的首元素。）
/// - idle/battle 指令响应 = `(index << 16) + groupIndex`；idle 组顺序
///   0=summon 1=spSummon 2=posChange 3=mset 4=sset 5=activate，
///   6=进战阶 7=结束回合；battle 组 0=activate 1=attack，2=M2 3=EP。
/// - 连锁放过必须应答 4 字节 -1（writeUint32(-1) → 0xFFFFFFFF）。
/// - MSG_SELECT_PLACE 的 field 位图：bit0-6=己方怪兽区、bit8-14=己方魔陷区，
///   **置位 = 禁用**，应答为 3 字节 (player, location, sequence)。
import 'dart:async';
import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:duelink_websocket/duelink_websocket.dart';
import 'package:service_loader/service_loader.dart';
import 'package:test/test.dart';

const String kServerHost = 'koishi.momobako.com';
const int kServerPort = 7211;
const Duration kNetTimeout = Duration(seconds: 30);

// ── 剧本用卡 ──
const kMysticalElf = 15025844; // 神圣精灵 Lv4 800/2000 — A 通召对象
const kCelticGuardian = 91152256; // 精灵剑士 Lv4 1400/1200 — B 通召/攻击对象
const kPotOfGreed = 55144522; // 强欲之壶 — A 发动（NC 房间不检查禁限）
const kTrapHole = 4206964; // 落穴 — A 盖放

/// 填充用通常怪兽（36 张，双方卡组凑满 40 用；不含剧本卡）。
/// 房间开启 NC（不检查卡组），填充卡出现 4 张同名也无妨。
const _fillers = <int>[
  89631139, 89631139, 89631139, // 青眼白龙 ×3
  46986414, 46986414, 46986414, // 黑魔导 ×3
  13039848, 13039848, 13039848, // 岩石巨兵 ×3
  6368038, 6368038, 6368038, // 暗黑骑士盖亚 ×3
  28279543, 28279543, 28279543, // 诅咒之龙 ×3
  74677422, 74677422, 74677422, // 真红眼黑龙 ×3
  88819587, 88819587, 88819587, // 宝贝龙 ×3
  76184692, 76184692, 76184692, // 独眼巨人 ×3
  41392891, 41392891, 41392891, // 恶魔召唤 ×3
  15303296, 15303296, 15303296, // 龙族封印壶 ×3
  87796900, 87796900, 87796900, // 守城翼龙 ×3
  32452818, 32452818, 32452818, // 恶魔海狸 ×3
];

Uint8List deckBytes(List<int> codes) {
  final w = ByteData(codes.length * 4);
  for (var i = 0; i < codes.length; i++) {
    w.setInt32(i * 4, codes[i], Endian.little);
  }
  return w.buffer.asUint8List();
}

/// A 的卡组（40 张）。牌库顶 = 列表前部（NS 不洗牌）→ 起手 5 张固定为：
/// 神圣精灵 / 强欲之壶 / 落穴 / 宝贝龙 / 恶魔海狸。
Uint8List deckAlice() => deckBytes([
      // ── 起手 5 张（剧本卡，位于牌库顶 = 列表前部）──
      kMysticalElf, // 神圣精灵 → 操作 1 通召（800 攻，给 B 留攻击空间）
      kPotOfGreed, // 强欲之壶 → 操作 2 发动
      kTrapHole, // 落穴 → 操作 3 盖放
      88819587, // 宝贝龙（手牌填充）
      32452818, // 恶魔海狸（手牌填充）
      ..._fillers.sublist(0, 35),
    ]);

/// B 的卡组（40 张）。起手 5 张固定为：
/// 精灵剑士 / 宝贝龙 / 独眼巨人 / 恶魔海狸 / 恶魔召唤。
Uint8List deckBob() => deckBytes([
      // ── 起手 5 张（剧本卡，位于牌库顶 = 列表前部）──
      kCelticGuardian, // 精灵剑士 → B 通召并攻击（1400 攻）
      88819587, // 宝贝龙（手牌填充）
      76184692, // 独眼巨人（手牌填充）
      32452818, // 恶魔海狸（手牌填充）
      41392891, // 恶魔召唤（手牌填充）
      ..._fillers.sublist(0, 35),
    ]);

/// srvpro 房间串 DSL：`MR5,NC,NS#<房间名>`（单局/MR2020/不检查卡组/不洗牌）。
/// 整条 ≤ 20 字符，房间名取时间戳 base36 后 8 位。
String roomString() {
  final id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  return 'MR5,NC,NS#t${id.substring(id.length - 8)}';
}

/// 等待满足条件的消息（先查已收集列表，再听实时流）。
/// 用于阶段等单调事件；游戏消息顺序消费请用 [MsgCursor]。
Future<T> waitUntil<T>(List<T> c, Stream<T> s, bool Function(T) p,
    {Duration timeout = kNetTimeout, String? hint}) async {
  final hit = c.where(p);
  if (hit.isNotEmpty) return hit.last;
  final f = Completer<T>();
  late final StreamSubscription<T> sub;
  sub = s.listen((e) {
    if (!f.isCompleted && p(e)) {
      f.complete(e);
      sub.cancel();
    }
  });
  final re = c.where(p);
  if (re.isNotEmpty && !f.isCompleted) {
    f.complete(re.last);
    sub.cancel();
  }
  return f.future.timeout(timeout,
      onTimeout: () => throw TimeoutException('wait ${hint ?? ""}'));
}

/// 消息游标：顺序消费收集到的消息，匹配后越过该消息。
/// 避免 waitUntil 的 `hit.last` 在连续等待同类消息（如多次 idle cmd）时
/// 返回上一条已应答过的陈旧消息。
class MsgCursor {
  MsgCursor(this.messages);

  final List<YgoStocMsg> messages;
  int index = 0;

  Future<YgoStocMsg> waitFor(bool Function(YgoStocMsg) test,
      {Duration timeout = kNetTimeout, String? hint}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (var i = index; i < messages.length; i++) {
        if (test(messages[i])) {
          index = i + 1;
          return messages[i];
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw TimeoutException('wait ${hint ?? ""}');
  }
}

/// 按 flag 位图选第一个可用的己方格子（置位=禁用）。
CtosSelectPlace firstFreePlace(MsgSelectPlace m) {
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
  return CtosSelectPlace(player: m.player, zone: CARD_ZONE_MZONE, sequence: 5);
}

/// 被动应答器：自动应答剧本之外的中间交互（选位/表示形式/连锁/是否/选卡），
/// **不应答** MSG_SELECT_IDLE_CMD / MSG_SELECT_BATTLE_CMD —— 这两个由剧本显式驱动。
StreamSubscription<YgoStocMsg> autoAnswer(IDuelService svc) {
  return svc.onServerMessage.listen((msg) {
    final gm = msg.gameMsg;
    if (gm == null) return;
    CtosGameMsgResponse? r;
    switch (gm.func) {
      case MSG_SELECT_PLACE:
      case MSG_SELECT_DISFIELD:
        r = CtosGameMsgResponse.selectPlace(
            firstFreePlace(gm.innerMsg as MsgSelectPlace));
        break;
      case MSG_SELECT_POSITION:
        r = CtosGameMsgResponse.selectPosition(POS_FACEUP_ATTACK);
        break;
      case MSG_SELECT_CHAIN:
        // 不连锁：必须应答 4 字节 -1（不能用 selectMulti([])）
        r = CtosGameMsgResponse.selectIdleCmd(-1);
        break;
      case MSG_SELECT_EFFECTYN:
      case MSG_SELECT_YES_NO:
        r = CtosGameMsgResponse.selectEffectYn(0);
        break;
      case MSG_SELECT_OPTION:
        r = CtosGameMsgResponse.selectOption(0);
        break;
      case MSG_SELECT_CARD:
        final sc = gm.innerMsg as MsgSelectCard;
        r = sc.min == 0
            ? CtosGameMsgResponse.selectMulti([])
            : CtosGameMsgResponse.selectMulti(List.generate(sc.min, (i) => i));
        break;
      case MSG_SELECT_TRIBUTE:
        final st = gm.innerMsg as MsgSelectTribute;
        r = CtosGameMsgResponse.selectMulti(List.generate(st.min, (i) => i));
        break;
    }
    if (r != null) svc.playGameResponse(r);
  });
}

/// 在 idle cmd 的指定组里按卡片 code 找选项（找不到返回 null）。
MsgIdleCmdOption? findIdleOption(MsgSelectIdleCmd cmd, int group, int code) {
  for (final o in cmd.commandGroups[group].options) {
    if (o.cardInfo.code == code) return o;
  }
  return null;
}

void main() {
  group('$kServerHost:$kServerPort', () {
    test('核心流程: 建房→猜拳→选先攻→A[召唤→强欲→盖落穴→结束]→B[召唤→攻击→LP计算]',
        () async {
      if (!ServiceFactory.isRegistered<WebSocketDuelService>()) {
        ServiceFactory.register<WebSocketDuelService>(WebSocketDuelService.new);
      }
      final id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      final alice = ServiceFactory.create<WebSocketDuelService>();
      final bob = ServiceFactory.create<WebSocketDuelService>();
      final aM = <YgoStocMsg>[], bM = <YgoStocMsg>[];
      final aS = <RoomStage>[], bS = <RoomStage>[];
      final aCur = MsgCursor(aM), bCur = MsgCursor(bM);
      final subs = <StreamSubscription<dynamic>>[
        alice.onServerMessage.listen(aM.add),
        bob.onServerMessage.listen(bM.add),
        alice.onRoomStageChange.listen(aS.add),
        bob.onRoomStageChange.listen(bS.add),
        autoAnswer(alice),
        autoAnswer(bob),
      ];

      addTearDown(() async {
        for (final s in subs) {
          await s.cancel();
        }
        if (alice.connectionState is ConnectionConnected) {
          alice.surrender();
        }
        if (bob.connectionState is ConnectionConnected) {
          bob.surrender();
        }
        await Future<void>.delayed(const Duration(seconds: 2));
        await alice.disconnect();
        await bob.disconnect();
      });

      Future<void> join(IDuelService s, String name, String pw) async {
        await s.connect(Uri.parse('wss://$kServerHost:$kServerPort'));
        s.setPlayerName(name);
        s.enterRoom(pw);
      }

      // ============================================================
      // 阶段 1: 建房（srvpro 房间串 DSL：单局/MR2020/不检查卡组/不洗牌）
      // 双方用同一房间串进入同一房间。
      // ============================================================
      final pw = roomString();
      await join(alice, 'A_$id', pw);
      await waitUntil(
          aS,
          alice.onRoomStageChange,
          (s) => s is RoomInLobby && s.selfType == PlayerType.player1,
          hint: 'A 进大厅');
      // 校验房间参数确实被服务器采纳（回声里的 noCheck/noShuffle 必须为 true，
      // 否则含禁卡/同名4张的测试卡组会在 ready 时被拒）
      final lobby = aS.lastWhere((s) => s is RoomInLobby) as RoomInLobby;
      expect(lobby.options.noCheckDeck, isTrue,
          reason: '房间应开启不检查卡组(NC)，实际: ${lobby.options}');
      expect(lobby.options.noShuffleDeck, isTrue,
          reason: '房间应开启不洗牌(NS)，实际: ${lobby.options}');

      await join(bob, 'B_$id', pw);
      await waitUntil(bS, bob.onRoomStageChange, (s) => s.players.length >= 2,
          hint: 'B 看到两人');
      await waitUntil(aS, alice.onRoomStageChange, (s) => s.players.length >= 2,
          hint: 'A 看到两人');

      // ============================================================
      // 阶段 2: 提交卡组 → 双方准备（带重试）
      // ============================================================
      alice.submitDeck(deckAlice(), deckBytes([]));
      bob.submitDeck(deckBob(), deckBytes([]));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      bool bothReady(RoomStage s) =>
          s.players.length == 2 && s.players.every((p) => p.ready);
      var ready = false;
      for (var i = 0; i < 3 && !ready; i++) {
        alice.ready();
        bob.ready();
        try {
          await waitUntil(aS, alice.onRoomStageChange, bothReady,
              timeout: const Duration(seconds: 8), hint: 'A 双方准备');
          await waitUntil(bS, bob.onRoomStageChange, bothReady,
              timeout: const Duration(seconds: 8), hint: 'B 双方准备');
          ready = true;
        } on TimeoutException {
          // 重发 ready
        }
      }
      expect(ready, isTrue, reason: '双方应进入已准备状态');

      // ============================================================
      // 阶段 3: 开始 → 猜拳（A 石头胜 B 剪刀）→ A 选先攻
      // ============================================================
      alice.startDuel();
      await waitUntil(
          aS, alice.onRoomStageChange, (s) => s is RoomSelectingHand,
          timeout: const Duration(seconds: 60), hint: 'A 猜拳阶段');
      await waitUntil(
          bS, bob.onRoomStageChange, (s) => s is RoomSelectingHand,
          timeout: const Duration(seconds: 60), hint: 'B 猜拳阶段');
      alice.chooseHand(HandType.rock);
      bob.chooseHand(HandType.scissors);
      await waitUntil(
          aS, alice.onRoomStageChange, (s) => s is RoomSelectingTurn,
          hint: 'A 选先后攻');
      alice.chooseTurnOrder(true);
      await waitUntil(aS, alice.onRoomStageChange,
          (s) => s is RoomInDuel && s.isFirstTurn == true,
          hint: 'A 进入决斗(先攻)');
      await waitUntil(bS, bob.onRoomStageChange, (s) => s is RoomInDuel,
          hint: 'B 进入决斗');

      // MSG_START：8000 LP / 40 卡组
      final startMsg = await aCur.waitFor((m) => m.gameMsg?.func == MSG_START,
          hint: 'MSG_START');
      final start = startMsg.gameMsg!.innerMsg as MsgStart;
      expect(start.life1, 8000);
      expect(start.life2, 8000);
      expect(start.deckSize1, 40);
      expect(start.deckSize2, 40);

      // ============================================================
      // 阶段 4 (A 回合): 通召神圣精灵 → 发动强欲之壶 → 盖放落穴 → 结束
      // （选位/表示形式/连锁由 autoAnswer 代答）
      // ============================================================
      // ── A 操作 1: 通召神圣精灵 ──
      var idleMsg = await aCur.waitFor(
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          timeout: const Duration(seconds: 60), hint: 'A 首个主阶段');
      var idle = idleMsg.gameMsg!.innerMsg as MsgSelectIdleCmd;
      final summonOpt = findIdleOption(idle, 0, kMysticalElf);
      expect(summonOpt, isNotNull, reason: 'A 起手应有可通召的神圣精灵');
      alice.playGameResponse(
          CtosGameMsgResponse.selectIdleCmd(summonOpt!.response));
      await aCur.waitFor((m) => m.gameMsg?.func == MSG_SUMMONED,
          hint: 'A 召唤完成');
      expect(aM.any((m) => m.gameMsg?.func == MSG_SUMMONING), isTrue,
          reason: '应有召唤宣言 MSG_SUMMONING');

      // ── A 操作 2: 发动强欲之壶 ──
      idleMsg = await aCur.waitFor(
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          hint: 'A 召唤后主阶段');
      idle = idleMsg.gameMsg!.innerMsg as MsgSelectIdleCmd;
      final potOpt = findIdleOption(idle, 5, kPotOfGreed);
      expect(potOpt, isNotNull, reason: 'A 手牌应有可发动的强欲之壶');
      alice.playGameResponse(
          CtosGameMsgResponse.selectIdleCmd(potOpt!.response));
      final potDraw = await aCur.waitFor(
          (m) =>
              m.gameMsg?.func == MSG_DRAW &&
              (m.gameMsg!.innerMsg as MsgDraw).player == 0 &&
              (m.gameMsg!.innerMsg as MsgDraw).count == 2,
          hint: '强欲之壶抽 2');
      expect((potDraw.gameMsg!.innerMsg as MsgDraw).count, 2,
          reason: '强欲之壶应抽 2 张');

      // ── A 操作 3: 盖放落穴 ──
      idleMsg = await aCur.waitFor(
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          hint: 'A 抽卡后主阶段');
      idle = idleMsg.gameMsg!.innerMsg as MsgSelectIdleCmd;
      final trapOpt = findIdleOption(idle, 4, kTrapHole);
      expect(trapOpt, isNotNull, reason: 'A 手牌应有可盖放的落穴');
      alice.playGameResponse(
          CtosGameMsgResponse.selectIdleCmd(trapOpt!.response));
      await aCur.waitFor((m) => m.gameMsg?.func == MSG_SET, hint: '落穴盖放');

      // ── A 操作 4: 结束回合（第一回合无战阶，直接 EP）──
      idleMsg = await aCur.waitFor(
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          hint: 'A 盖放后主阶段');
      idle = idleMsg.gameMsg!.innerMsg as MsgSelectIdleCmd;
      expect(idle.enableEp, isTrue, reason: 'A 回合应能结束回合');
      alice.playGameResponse(CtosGameMsgResponse.selectIdleCmd(7));

      // ============================================================
      // 阶段 5 (B 回合): 通召精灵剑士 → 进战阶 → 攻击神圣精灵 → LP 计算
      // （A 的落穴连锁询问由 autoAnswer 应答 -1 放过）
      // ============================================================
      await bCur.waitFor(
          (m) =>
              m.gameMsg?.func == MSG_NEW_TURN &&
              (m.gameMsg!.innerMsg as MsgNewTurn).player == 1,
          timeout: const Duration(seconds: 60), hint: 'B 的回合开始');

      // ── B 操作 1: 通召精灵剑士 ──
      idleMsg = await bCur.waitFor(
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          timeout: const Duration(seconds: 60), hint: 'B 主阶段');
      idle = idleMsg.gameMsg!.innerMsg as MsgSelectIdleCmd;
      final bSummonOpt = findIdleOption(idle, 0, kCelticGuardian);
      expect(bSummonOpt, isNotNull, reason: 'B 起手应有可通召的精灵剑士');
      bob.playGameResponse(
          CtosGameMsgResponse.selectIdleCmd(bSummonOpt!.response));
      await bCur.waitFor((m) => m.gameMsg?.func == MSG_SUMMONED,
          hint: 'B 召唤完成');

      // ── B 操作 2: 进战斗阶段 ──
      idleMsg = await bCur.waitFor(
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          hint: 'B 召唤后主阶段');
      idle = idleMsg.gameMsg!.innerMsg as MsgSelectIdleCmd;
      expect(idle.enableBp, isTrue, reason: 'B 回合(第 2 回合)应能进战阶');
      bob.playGameResponse(CtosGameMsgResponse.selectIdleCmd(6));

      // ── B 操作 3: 精灵剑士攻击神圣精灵（唯一攻击目标，自动选择）──
      final battleMsg = await bCur.waitFor(
          (m) => m.gameMsg?.func == MSG_SELECT_BATTLE_CMD,
          timeout: const Duration(seconds: 60), hint: 'B 战阶指令');
      final battle = battleMsg.gameMsg!.innerMsg as MsgSelectBattleCmd;
      MsgBattleCmdOption? attackOpt;
      for (final o in battle.commandGroups[1].options) {
        if (o.cardInfo.code == kCelticGuardian) {
          attackOpt = o;
          break;
        }
      }
      expect(attackOpt, isNotNull, reason: '精灵剑士应可攻击');
      bob.playGameResponse(
          CtosGameMsgResponse.selectBattleCmd(attackOpt!.response));

      // ── 攻击与 LP 计算验证：1400 攻 vs 800 攻 → A 受到 600 战斗伤害 ──
      await bCur.waitFor((m) => m.gameMsg?.func == MSG_ATTACK,
          timeout: const Duration(seconds: 60), hint: '攻击宣言');
      await bCur.waitFor((m) => m.gameMsg?.func == MSG_BATTLE,
          hint: '战斗结算 MSG_BATTLE');
      final damageMsg =
          await bCur.waitFor((m) => m.gameMsg?.func == MSG_DAMAGE, hint: '伤害结算');
      final damage = damageMsg.gameMsg!.innerMsg as MsgDamage;
      expect(damage.player, 0, reason: '受伤方应为 A(player 0)');
      expect(damage.value, 600, reason: '1400 - 800 = 600 战斗伤害');
      // A 端应看到同一条伤害消息
      await aCur.waitFor(
          (m) =>
              m.gameMsg?.func == MSG_DAMAGE &&
              (m.gameMsg!.innerMsg as MsgDamage).value == 600,
          hint: 'A 端伤害同步');

      // ── B 操作 4: 结束（战阶 → M2 → 结束回合）──
      final battle2Msg = await bCur.waitFor(
          (m) => m.gameMsg?.func == MSG_SELECT_BATTLE_CMD,
          hint: 'B 战阶后续指令');
      final battle2 = battle2Msg.gameMsg!.innerMsg as MsgSelectBattleCmd;
      bob.playGameResponse(
          CtosGameMsgResponse.selectBattleCmd(battle2.enableM2 ? 2 : 3));
      idleMsg = await bCur.waitFor(
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          hint: 'B M2 主阶段');
      idle = idleMsg.gameMsg!.innerMsg as MsgSelectIdleCmd;
      expect(idle.enableEp, isTrue, reason: 'B 应能结束回合');
      bob.playGameResponse(CtosGameMsgResponse.selectIdleCmd(7));

      // ============================================================
      // 汇总
      // ============================================================
      print('=== 核心流程验证 ===');
      print('  房间串: $pw (NC/NS 已校验)');
      print('  猜拳: A 石头 vs B 剪刀 → A 先攻 ✓');
      print('  MSG_START: LP 8000/8000, 卡组 40/40 ✓');
      print('  A: 通召神圣精灵 ✓ → 强欲之壶抽 2 ✓ → 盖放落穴 ✓ → 结束回合 ✓');
      print('  B: 通召精灵剑士 ✓ → 进战阶 ✓ → 攻击 ✓');
      print(
          '  LP 计算: MSG_DAMAGE player=${damage.player} value=${damage.value} (A: 8000 → ${8000 - damage.value}) ✓');
      print('  A 总消息数: ${aM.length}, B 总消息数: ${bM.length}');
      print('====================');
    });
  });
}
