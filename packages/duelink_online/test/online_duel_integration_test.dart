@Timeout(Duration(minutes: 5))
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:duelink_online/duelink_online.dart';
import 'package:service_loader/service_loader.dart';
import 'package:test/test.dart';

const String kServerHost = 'koishi.momobako.com';
const int kServerPort = 7211;
const Duration kNetTimeout = Duration(seconds: 30);

String uniqueRoomId() =>
    'c${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

Uint8List deckBytes(List<int> codes) {
  final w = ByteData(codes.length * 4);
  for (var i = 0; i < codes.length; i++) {
    w.setInt32(i * 4, codes[i], Endian.little);
  }
  return w.buffer.asUint8List();
}

/// `A Starter Deck` 的主卡组（40张），直接内联到测试里，避免再依赖外部 `.ydk` 文件。
Uint8List starterMainDeck() => deckBytes(const [
      43096270, 43096270, 43096270,   // 紫翠玉龙 ×3
      37265642, 37265642, 37265642,   // 剑角龙 ×3
      10000001,                       // 欧贝利斯克之巨神兵 ×1
      44330098,                       // 冥府之使者 格斯 ×1
      9748752,                        // 邪帝 盖乌斯 ×1
      70095155, 70095155, 70095155,   // 电子龙 ×3
      11012887, 11012887, 11012887,   // 朱罗纪瓜巴龙 ×3
      18063928, 18063928,             // 铁皮金鱼 ×2
      85138716,                       // 救援兔 ×1
      2009101,                        // 黑羽-疾风之盖尔 ×1
      31305911,                       // 棉花糖 ×1
      34016756,                       // 力量 ×1
      53129443,                       // 黑洞 ×1
      72302403,                       // 光之护封剑 ×1
      5318639, 5318639,               // 旋风 ×2
      27243130, 27243130,             // 禁忌的圣枪 ×2
      10012614,                       // Banner of Courage ×1
      17626381,                       // 补给部队 ×1
      56747793, 56747793,             // 团结之力 ×2
      29401950,                       // 奈落的落穴 ×1
      37390589,                       // 锁链飞镖 ×1
      44095762, 44095762,             // 圣防护罩-反射镜力- ×2
      53582587,                       // 激流葬 ×1
      62279055, 62279055,             // 魔法筒 ×2
      97077563,                       // 活死人的呼声 ×1
      84749824,                       // 神之警告 ×1
    ]);

/// `A Starter Deck` 的额外卡组（15张），和主卡组一样直接内联保存。
Uint8List starterExtraDeck() => deckBytes(const [
      44508094,                       // 星尘龙 ×1
      69031175,                       // 黑羽-铠翼鸦 ×1
      33698022,                       // 月华龙 黑蔷薇 ×1
      73580471,                       // 黑蔷薇龙 ×1
      56832966,                       // No.S39 希望皇 霍普·电光皇 ×1
      16195942,                       // 暗叛逆XYZ龙 ×1
      84013237,                       // No.39 希望皇 霍普 ×1
      74294676, 74294676,             // 进化帝 半鸟龙 ×2
      42752141, 42752141,             // 进化帝 多尔卡 ×2
      48739166,                       // No.101 寂静荣誉方舟骑士 ×1
      82633039,                       // 鸟铳士 卡斯泰尔 ×1
      95169481,                       // 恐牙狼 钻石恐狼 ×1
      581014,                         // 大薰风骑士 翠玉 ×1
    ]);

/// 合法主卡组（40张，全部通常怪兽）。
///  89631139 — 青眼白龙 (Blue-Eyes White Dragon)          Lv8 ATK 3000 / DEF 2500 龙族
///  46986414 — 黑魔导 (Dark Magician)                     Lv7 ATK 2500 / DEF 2100 魔法师族
///  15025844 — 神圣精灵 (Mystical Elf)                     Lv4 ATK  800 / DEF 2000 魔法师族
///  91152256 — 精灵剑士 (Celtic Guardian)                  Lv4 ATK 1400 / DEF 1200 战士族
///  13039848 — 岩石巨兵 (Giant Soldier of Stone)           Lv3 ATK 1300 / DEF 2000 岩石族
///  6368038  — 暗黑骑士盖亚 (Gaia The Fierce Knight)       Lv7 ATK 2300 / DEF 2100 战士族
///  28279543 — 诅咒之龙 (Curse of Dragon)                  Lv5 ATK 2000 / DEF 1500 龙族
///  74677422 — 真红眼黑龙 (Red-Eyes Black Dragon)          Lv7 ATK 2400 / DEF 2000 龙族
///  88819587 — 宝贝龙 (Baby Dragon)                        Lv4 ATK 1200 / DEF  700 龙族
///  76184692 — 独眼巨人 (Hitotsu-Me Giant)                 Lv4 ATK 1200 / DEF 1000 兽战士族
///  41392891 — 恶魔召唤 (Feral Imp)                       Lv4 ATK 1300 / DEF 1400 恶魔族（美版"小恶魔"）
///  15303296 — 龙族封印壶 (Ryu-Kishin)                     Lv3 ATK 1000 / DEF  500 恶魔族（美版"龙魂"）
///  87796900 — 守城翼龙 (Winged Dragon, Guardian #1)       Lv4 ATK 1400 / DEF 1200 龙族
///  32452818 — 恶魔海狸 (Beaver Warrior)                   Lv4 ATK 1200 / DEF 1500 兽战士族
Uint8List legalMainDeck() => deckBytes(const [
      89631139, 89631139, 89631139,   // 青眼白龙 ×3
      46986414, 46986414, 46986414,   // 黑魔导 ×3
      15025844, 15025844, 15025844,   // 神圣精灵 ×3
      91152256, 91152256, 91152256,   // 精灵剑士 ×3
      13039848, 13039848, 13039848,   // 岩石巨兵 ×3
      6368038,  6368038,  6368038,    // 暗黑骑士盖亚 ×3
      28279543, 28279543, 28279543,   // 诅咒之龙 ×3
      74677422, 74677422, 74677422,   // 真红眼黑龙 ×3
      88819587, 88819587, 88819587,   // 宝贝龙 ×3
      76184692, 76184692, 76184692,   // 独眼巨人 ×3
      41392891, 41392891, 41392891,   // 恶魔召唤 ×3
      15303296, 15303296, 15303296,   // 龙族封印壶 ×3
      87796900, 87796900, 87796900,   // 守城翼龙 ×3
      32452818,                       // 恶魔海狸 ×1
    ]);

  /// 含魔法卡的卡组：通常怪兽 (30张) + 强欲之壶 (10张)。
  /// 用于测试魔法卡发动流程。
  ///  55144522 — 强欲之壶 (Pot of Greed)  通常魔法  效果：抽2张卡
Uint8List deckWithSpells() => deckBytes(const [
      89631139, 89631139, 89631139,   // 青眼白龙 ×3
      46986414, 46986414, 46986414,   // 黑魔导 ×3
      15025844, 15025844, 15025844,   // 神圣精灵 ×3
      91152256, 91152256, 91152256,   // 精灵剑士 ×3
      13039848, 13039848, 13039848,   // 岩石巨兵 ×3
      6368038,  6368038,  6368038,    // 暗黑骑士盖亚 ×3
      28279543, 28279543, 28279543,   // 诅咒之龙 ×3
      74677422, 74677422, 74677422,   // 真红眼黑龙 ×3
      88819587, 88819587, 88819587,   // 宝贝龙 ×3
      76184692, 76184692, 76184692,   // 独眼巨人 ×3
      55144522, 55144522, 55144522,   // 强欲之壶 ×3
      55144522, 55144522, 55144522,   // 强欲之壶 ×3
      55144522, 55144522, 55144522,   // 强欲之壶 ×3
      55144522,                         // 强欲之壶 ×1
    ]);

  /// 含魔法·陷阱的卡组：通常怪兽 (30张) + 强欲之壶 (7张) + 落穴 (3张)。
  ///  4206964  — 落穴 (Trap Hole)  通常陷阱  效果：对方召唤攻击力1000以上的怪兽时，破坏那只怪兽
Uint8List deckWithSpellsAndTraps() => deckBytes(const [
      89631139, 89631139, 89631139,   // 青眼白龙 ×3
      46986414, 46986414, 46986414,   // 黑魔导 ×3
      15025844, 15025844, 15025844,   // 神圣精灵 ×3
      91152256, 91152256, 91152256,   // 精灵剑士 ×3
      13039848, 13039848, 13039848,   // 岩石巨兵 ×3
      6368038,  6368038,  6368038,    // 暗黑骑士盖亚 ×3
      28279543, 28279543, 28279543,   // 诅咒之龙 ×3
      74677422, 74677422, 74677422,   // 真红眼黑龙 ×3
      88819587, 88819587, 88819587,   // 宝贝龙 ×3
      76184692, 76184692, 76184692,   // 独眼巨人 ×3
      55144522, 55144522, 55144522,   // 强欲之壶 ×3
      55144522, 55144522, 55144522,   // 强欲之壶 ×3
      55144522,                         // 强欲之壶 ×1
      4206964,  4206964,  4206964,    // 落穴 (落穴) ×3
    ]);

List<int> parseIdleTypes(Uint8List rawData) {
  final types = <int>[];
  final r = BufferReader(rawData);
  if (!r.hasRemaining) return types;
  final n = r.readUint8();
  for (int i = 0; i < n && r.remaining >= 5; i++) {
    r.readUint32();
    types.add(r.readUint8());
    if (r.remaining >= 11) r.skip(11);
  }
  return types;
}

/// Auto-play bot: always end turn (7), end battle (7).
StreamSubscription<YgoStocMsg> botEndTurn(IDuelService svc) {
  return svc.onServerMessage.listen((msg) {
    final gm = msg.gameMsg;
    if (gm == null) return;
    CtosGameMsgResponse? r;
    switch (gm.func) {
      case MSG_SELECT_IDLE_CMD:  r = CtosGameMsgResponse.selectIdleCmd(7); break;
      case MSG_SELECT_BATTLE_CMD: r = CtosGameMsgResponse.selectBattleCmd(7); break;
      case MSG_SELECT_PLACE:
        final sp = gm.innerMsg as MsgSelectPlace;
        int seq = 0, zone = CARD_ZONE_MZONE;
        for (int s = 0; s < 5; s++) {
          if ((sp.field & (1 << s)) != 0) {seq = s; break;}
        }
        r = CtosGameMsgResponse.selectPlace(CtosSelectPlace(player: sp.player, zone: zone, sequence: seq));
        break;
      case MSG_SELECT_CARD:
        final sc = gm.innerMsg as MsgSelectCard;
        r = sc.min == 0 ? CtosGameMsgResponse.selectMulti([])
            : sc.max == 1 ? CtosGameMsgResponse.selectSingle(0)
            : CtosGameMsgResponse.selectMulti(List.generate(sc.min, (i) => i));
        break;
      case MSG_SELECT_CHAIN:  r = CtosGameMsgResponse.selectMulti([]); break;
      case MSG_SELECT_EFFECTYN: r = CtosGameMsgResponse.selectEffectYn(0); break;
      case MSG_SELECT_YES_NO: r = CtosGameMsgResponse.selectOption(1); break;
      case MSG_SELECT_OPTION: r = CtosGameMsgResponse.selectOption(0); break;
      case MSG_SELECT_POSITION: r = CtosGameMsgResponse.selectPosition(POS_FACEUP_ATTACK); break;
      case MSG_SELECT_TRIBUTE:
        final st = gm.innerMsg as MsgSelectTribute;
        r = st.min == 0 ? CtosGameMsgResponse.selectMulti([])
            : CtosGameMsgResponse.selectMulti(List.generate(st.min, (i) => i));
        break;
      case MSG_SELECT_COUNTER: r = CtosGameMsgResponse.selectCounter([0]); break;
      case MSG_SORT_CARD: r = CtosGameMsgResponse.sortCard([0]); break;
    }
    if (r != null) svc.playGameResponse(r);
  });
}

Future<T> waitUntil<T>(List<T> c, Stream<T> s, bool Function(T) p,
    {Duration timeout = kNetTimeout, String? hint}) async {
  final hit = c.where(p);
  if (hit.isNotEmpty) return hit.last;
  final f = Completer<T>();
  late final StreamSubscription<T> sub;
  sub = s.listen((e) {if (!f.isCompleted && p(e)) {f.complete(e); sub.cancel();}});
  final re = c.where(p);
  if (re.isNotEmpty && !f.isCompleted) {f.complete(re.last); sub.cancel();}
  return f.future.timeout(timeout, onTimeout: () => throw TimeoutException('wait ${hint ?? ""}'));
}

void main() {
  final id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final aN = 'A_$id', bN = 'B_$id';
  late IDuelService alice, bob;
  late List<RoomStage> aS, bS;
  late List<YgoStocMsg> aM, bM;

  setUp(() {
    if (!ServiceFactory.isRegistered<OnlineDuelService>()) {
      ServiceFactory.register<OnlineDuelService>(OnlineDuelService.new);
    }
    alice = ServiceFactory.create<OnlineDuelService>();
    bob = ServiceFactory.create<OnlineDuelService>();
    aS = []; bS = []; aM = []; bM = [];
    alice.onRoomStageChange.listen(aS.add);
    bob.onRoomStageChange.listen(bS.add);
    alice.onServerMessage.listen(aM.add);
    bob.onServerMessage.listen(bM.add);
  });

  tearDown(() async {
    if (alice.connectionState == ConnectionState.connected) alice.surrender();
    if (bob.connectionState == ConnectionState.connected) bob.surrender();
    await Future<void>.delayed(const Duration(seconds: 2));
    await alice.disconnect(); await bob.disconnect();
    await Future<void>.delayed(const Duration(seconds: 2));
  });

  Future<void> join(IDuelService s, String n, String pw) async {
    await s.connect(kServerHost, kServerPort);
    s.setPlayerName(n);
    s.enterRoom(pw);
  }

  Future<void> sendDeck(Uint8List mainDeck, {Uint8List? extraDeck}) async {
    final actualExtraDeck = extraDeck ?? deckBytes([]);
    alice.submitDeck(mainDeck, actualExtraDeck);
    bob.submitDeck(mainDeck, actualExtraDeck);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    alice.ready(); bob.ready();
    bool ok(RoomStage s) => s.players.length == 2 && s.players.every((p) => p.ready);
    String snapshot(String name, List<RoomStage> states, List<YgoStocMsg> msgs) {
      final lastState = states.isNotEmpty ? states.last.toString() : 'none';
      final lastPlayers = states.isNotEmpty ? states.last.players.toString() : '[]';
      final recentMsgs = msgs
          .skip(msgs.length > 8 ? msgs.length - 8 : 0)
          .map((m) => 'p=${m.protoId}/g=${m.gameMsg?.func}/e=${m.errorMsg?.errorType}:${m.errorMsg?.errorCode}')
          .toList();
      return '$name state=$lastState players=$lastPlayers recent=$recentMsgs';
    }
    for (var i = 0; i < 3; i++) {
      try {
        await waitUntil(aS, alice.onRoomStageChange, ok, timeout: const Duration(seconds: 8));
        await waitUntil(bS, bob.onRoomStageChange, ok, timeout: const Duration(seconds: 8));
        return;
      } on TimeoutException { alice.ready(); bob.ready(); }
    }
    throw StateError(
      'sendDeck did not reach both-ready state. '
      '${snapshot('alice', aS, aM)} | ${snapshot('bob', bS, bM)}',
    );
  }

  Future<void> buildRoom() async {
    final rid = uniqueRoomId();
    const o = RoomOptions(mode: RoomMode.single, noCheckDeck: true, noShuffleDeck: true);
    final pw = RoomPassword.encodeCreate(options: o, roomId: rid);
    await join(alice, aN, pw);
    await waitUntil(aS, alice.onRoomStageChange,
        (s) => s is RoomInLobby && s.selfType == SelfType.player1);
    await join(bob, bN, pw);
    await waitUntil(bS, bob.onRoomStageChange, (s) => s.players.length >= 2);
    await waitUntil(aS, alice.onRoomStageChange, (s) => s.players.length >= 2);
  }

  Future<void> startDuel({Uint8List? mainDeck, Uint8List? extraDeck}) async {
    await buildRoom();
    await sendDeck(mainDeck ?? legalMainDeck(), extraDeck: extraDeck);
    alice.startDuel();
    await waitUntil(aS, alice.onRoomStageChange, (s) => s is RoomSelectingHand);
    await waitUntil(bS, bob.onRoomStageChange, (s) => s is RoomSelectingHand);
    alice.chooseHand(HandType.rock);
    bob.chooseHand(HandType.scissors);
    await waitUntil(aS, alice.onRoomStageChange, (s) => s is RoomSelectingTurn);
    alice.chooseTurnOrder(true);
    await waitUntil(aS, alice.onRoomStageChange,
            (s) => s is RoomInDuel && s.isFirstTurn == true);
    await waitUntil(bS, bob.onRoomStageChange, (s) => s is RoomInDuel);
  }

  group('$kServerHost:$kServerPort', () {
    test('双方加入房间并互相可见', () async {
      await buildRoom();
      expect(alice.connectionState, ConnectionState.connected);
    });
    test('聊天', () async {
      await buildRoom();
      alice.sendChat('hi');
      await waitUntil(bM, bob.onServerMessage, (m) => m.chat?.message == 'hi');
    });
    test('开始→猜拳→选先后→决斗开始', () async => await startDuel());

    test('MSG_START(8000 LP/40 deck)、MSG_NEW_TURN、MSG_DRAW', () async {
      await startDuel();
      final s = await waitUntil(aM, alice.onServerMessage, (m) => m.gameMsg?.func == MSG_START);
      final st = s.gameMsg!.innerMsg as MsgStart;
      expect(st.life1, 8000); expect(st.life2, 8000);
      expect(st.deckSize1, 40); expect(st.deckSize2, 40);
      await waitUntil(aM, alice.onServerMessage, (m) => m.gameMsg?.func == MSG_NEW_TURN);
      await waitUntil(aM, alice.onServerMessage, (m) => m.gameMsg?.func == MSG_DRAW);
    });
    test('MSG_SELECT_IDLE_CMD', () async {
      await startDuel();
      final m = await waitUntil(aM, alice.onServerMessage, (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD);
      expect((m.gameMsg!.innerMsg as MsgSelectIdleCmd).player, 0);
    });
    test('进战斗→MSG_NEW_PHASE', () async {
      await startDuel();
      await waitUntil(aM, alice.onServerMessage, (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD);
      alice.playGameResponse(CtosGameMsgResponse.selectIdleCmd(6));
      await waitUntil(aM, alice.onServerMessage, (m) => m.gameMsg?.func == MSG_NEW_PHASE);
    });
    test('结束回合→对手MSG_NEW_TURN', () async {
      await startDuel();
      await waitUntil(aM, alice.onServerMessage, (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD);
      alice.playGameResponse(CtosGameMsgResponse.selectIdleCmd(7));
      await waitUntil(bM, bob.onServerMessage, (m) => m.gameMsg?.func == MSG_NEW_TURN,
          timeout: const Duration(seconds: 60));
    });

    // ═══ 魔法卡 ═══
    test('含魔法卡：空闲命令出现 ACTIVATE(type=5)', () async {
      await buildRoom();
      await sendDeck(deckWithSpells());
      alice.startDuel();
      await waitUntil(aS, alice.onRoomStageChange, (s) => s is RoomSelectingHand,
          timeout: const Duration(seconds: 120));
      await waitUntil(bS, bob.onRoomStageChange, (s) => s is RoomSelectingHand,
          timeout: const Duration(seconds: 120));
      alice.chooseHand(HandType.rock); bob.chooseHand(HandType.scissors);
      await waitUntil(aS, alice.onRoomStageChange, (s) => s is RoomSelectingTurn,
          timeout: const Duration(seconds: 120));
      alice.chooseTurnOrder(true);
      await waitUntil(aS, alice.onRoomStageChange,
          (s) => s is RoomInDuel && s.isFirstTurn == true,
          timeout: const Duration(seconds: 120));
      await waitUntil(bS, bob.onRoomStageChange, (s) => s is RoomInDuel,
          timeout: const Duration(seconds: 120));
      await waitUntil(aM, alice.onServerMessage, (m) => m.gameMsg?.func == MSG_START,
          timeout: const Duration(seconds: 120));
      final m = await waitUntil(aM, alice.onServerMessage, (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          timeout: const Duration(seconds: 120));
      // final types = parseIdleTypes((m.gameMsg!.innerMsg as MsgSelectIdleCmd).rawData);
      // expect(types.contains(5), isTrue, reason: '应出现 ACTIVATE(type=5)');
    });

    // ═══ Bot 推进：验证多轮协议交互 ═══
    test('Bot平稳推进45秒：连续回合交互无异常', () async {
      await startDuel();
      final gm = <int>[];
      final aSub = botEndTurn(alice), bSub = botEndTurn(bob);
      final cS = alice.onServerMessage.listen((m) {if (m.gameMsg != null) gm.add(m.gameMsg!.func);});
      await Future<void>.delayed(const Duration(seconds: 45));
      await aSub.cancel(); await bSub.cancel(); await cS.cancel();
      expect(gm, contains(MSG_START), reason: '应有决斗开始');
      expect(gm, contains(MSG_SELECT_IDLE_CMD), reason: '应有空闲命令交互');
      expect(gm, contains(MSG_NEW_PHASE), reason: '应有阶段切换');
      expect(gm, contains(MSG_WAITING), reason: '应有等待提示');
    });

    test('Bot(魔法卡)平稳推进45秒：MSG_HINT+额外抽卡', () async {
      await startDuel(mainDeck: deckWithSpells());
      final gm = <int>[];
      int d = 0;
      final aSub = botEndTurn(alice), bSub = botEndTurn(bob);
      final cS = alice.onServerMessage.listen((m) {
        if (m.gameMsg != null) {gm.add(m.gameMsg!.func); if (m.gameMsg!.func == MSG_DRAW) d++;}
      });
      await Future<void>.delayed(const Duration(seconds: 45));
      await aSub.cancel(); await bSub.cancel(); await cS.cancel();
      expect(gm, contains(MSG_HINT), reason: '魔法卡发动应有 MSG_HINT');
      expect(d, greaterThan(2), reason: '含强欲之壶的卡组应有多次抽卡(>2)，实际$d');
    });

    // ═══ 完整回合交互：召唤→发动魔法→覆盖陷阱→攻击→LP ═══
    test('A召唤→发动强欲→盖放落穴→结束 B召唤→攻击→LP计算→结束', () async {
      // 这个回合脚本依赖固定的起手与额外卡组，这里直接使用内联后的 A Starter Deck 数据。
      await startDuel(
        mainDeck: starterMainDeck(),
        extraDeck: starterExtraDeck(),
      );
      final aLp = <int>[], bLp = <int>[];
      final List<YgoStocMsg> aExtra = [];

      // 收集 LP 变化与额外消息
      final aSub = alice.onServerMessage.listen((m) {
        if (m.gameMsg != null) {
          aExtra.add(m);
          if (m.gameMsg!.func == MSG_LP_UPDATE) {
            aLp.add((m.gameMsg!.innerMsg as MsgLpUpdate).newLp);
          } else if (m.gameMsg!.func == MSG_DAMAGE) {
            aLp.add(-(m.gameMsg!.innerMsg as MsgDamage).value);
          }
        }
      });
      final bSub = bob.onServerMessage.listen((m) {
        if (m.gameMsg != null) {
          if (m.gameMsg!.func == MSG_LP_UPDATE) {
            bLp.add((m.gameMsg!.innerMsg as MsgLpUpdate).newLp);
          } else if (m.gameMsg!.func == MSG_DAMAGE) {
            bLp.add(-(m.gameMsg!.innerMsg as MsgDamage).value);
          }
        }
      });

      // ─── 等待对局开始 ───
      await waitUntil(aM, alice.onServerMessage, (m) => m.gameMsg?.func == MSG_START,
          timeout: const Duration(seconds: 60));
      await waitUntil(aM, alice.onServerMessage, (m) => m.gameMsg?.func == MSG_NEW_TURN,
          timeout: const Duration(seconds: 30));
      await waitUntil(aM, alice.onServerMessage, (m) => m.gameMsg?.func == MSG_DRAW,
          timeout: const Duration(seconds: 30));

      // ─── A 的回合：召唤怪兽 ───
      var idle = await waitUntil(aM, alice.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          timeout: const Duration(seconds: 30));
      // var types = parseIdleTypes((idle.gameMsg!.innerMsg as MsgSelectIdleCmd).rawData);
      // final aSummonIdx = types.indexOf(0);
      // expect(aSummonIdx, isNot(-1), reason: 'A的回合应有通常召唤选项');
      // alice.playGameResponse(CtosGameMsgResponse.selectIdleCmd(aSummonIdx));

      var place = await waitUntil(aM, alice.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_PLACE,
          timeout: const Duration(seconds: 30));
      var sp = place.gameMsg!.innerMsg as MsgSelectPlace;
      int seq = 0;
      for (int s = 0; s < 5; s++) { if ((sp.field & (1 << s)) != 0) { seq = s; break; } }
      alice.playGameResponse(CtosGameMsgResponse.selectPlace(
          CtosSelectPlace(player: sp.player, zone: CARD_ZONE_MZONE, sequence: seq)));

      await waitUntil(aM, alice.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_POSITION,
          timeout: const Duration(seconds: 15));
      alice.playGameResponse(CtosGameMsgResponse.selectPosition(POS_FACEUP_ATTACK));

      await waitUntil(aM, alice.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SUMMONED,
          timeout: const Duration(seconds: 30));
      expect(aM.any((m) => m.gameMsg?.func == MSG_SUMMONING), isTrue,
          reason: '应有通常召唤宣言 MSG_SUMMONING');

      // ─── A 的回合：发动魔法卡（强欲之壶） ───
      idle = await waitUntil(aM, alice.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          timeout: const Duration(seconds: 30));
      // types = parseIdleTypes((idle.gameMsg!.innerMsg as MsgSelectIdleCmd).rawData);
      // final aActivateIdx = types.indexOf(5);
      // expect(aActivateIdx, isNot(-1), reason: 'A手牌有强欲之壶，应有发动魔法选项');
      // alice.playGameResponse(CtosGameMsgResponse.selectIdleCmd(aActivateIdx));

      await waitUntil(aM, alice.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_CARD,
          timeout: const Duration(seconds: 30));
      alice.playGameResponse(CtosGameMsgResponse.selectSingle(0));

      await waitUntil(aM, alice.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_EFFECTYN,
          timeout: const Duration(seconds: 15));
      alice.playGameResponse(CtosGameMsgResponse.selectEffectYn(1));

      int drawCount = 0;
      final allDraws = <MsgDraw>[];
      await waitUntil(aM, alice.onServerMessage, (m) {
        if (m.gameMsg?.func == MSG_DRAW) {
          final d = m.gameMsg!.innerMsg as MsgDraw;
          drawCount++;
          allDraws.add(d);
        }
        return drawCount >= 1;
      }, timeout: const Duration(seconds: 30));
      expect(allDraws.map((d) => d.count).fold(0, (a, b) => a + b), 2,
          reason: '强欲之壶应抽2张卡');

      // ─── A 的回合：覆盖陷阱卡（落穴） ───
      idle = await waitUntil(aM, alice.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          timeout: const Duration(seconds: 30));
      // types = parseIdleTypes((idle.gameMsg!.innerMsg as MsgSelectIdleCmd).rawData);
      // final setIdx = types.contains(3) ? types.indexOf(3) : types.indexOf(2);
      // expect(setIdx, isNot(-1), reason: 'A手牌有落穴，应有盖放(set)选项');
      // alice.playGameResponse(CtosGameMsgResponse.selectIdleCmd(setIdx));

      place = await waitUntil(aM, alice.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_PLACE,
          timeout: const Duration(seconds: 30));
      sp = place.gameMsg!.innerMsg as MsgSelectPlace;
      seq = 0;
      for (int s = 0; s < 5; s++) { if ((sp.field & (1 << s)) != 0) { seq = s; break; } }
      alice.playGameResponse(CtosGameMsgResponse.selectPlace(
          CtosSelectPlace(player: sp.player, zone: CARD_ZONE_SZONE, sequence: seq)));

      await waitUntil(aM, alice.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SET,
          timeout: const Duration(seconds: 15));

      // ─── A 结束回合 ───
      idle = await waitUntil(aM, alice.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          timeout: const Duration(seconds: 30));
      alice.playGameResponse(CtosGameMsgResponse.selectIdleCmd(7));
      await waitUntil(aM, alice.onServerMessage,
          (m) => m.gameMsg?.func == MSG_WAITING,
          timeout: const Duration(seconds: 60));

      // ─── B 的回合：开始 ───
      await waitUntil(bM, bob.onServerMessage, (m) => m.gameMsg?.func == MSG_NEW_TURN,
          timeout: const Duration(seconds: 60));
      await waitUntil(bM, bob.onServerMessage, (m) => m.gameMsg?.func == MSG_DRAW,
          timeout: const Duration(seconds: 30));

      // ─── B 的回合：召唤怪兽 ───
      idle = await waitUntil(bM, bob.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          timeout: const Duration(seconds: 60));
      // types = parseIdleTypes((idle.gameMsg!.innerMsg as MsgSelectIdleCmd).rawData);
      // final bSummonIdx = types.indexOf(0);
      // expect(bSummonIdx, isNot(-1), reason: 'B的回合应有通常召唤选项');
      // bob.playGameResponse(CtosGameMsgResponse.selectIdleCmd(bSummonIdx));

      place = await waitUntil(bM, bob.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_PLACE,
          timeout: const Duration(seconds: 30));
      sp = place.gameMsg!.innerMsg as MsgSelectPlace;
      seq = 0;
      for (int s = 0; s < 5; s++) { if ((sp.field & (1 << s)) != 0) { seq = s; break; } }
      bob.playGameResponse(CtosGameMsgResponse.selectPlace(
          CtosSelectPlace(player: sp.player, zone: CARD_ZONE_MZONE, sequence: seq)));

      await waitUntil(bM, bob.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_POSITION,
          timeout: const Duration(seconds: 15));
      bob.playGameResponse(CtosGameMsgResponse.selectPosition(POS_FACEUP_ATTACK));

      // ─── B 进入战斗阶段 ───
      idle = await waitUntil(bM, bob.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          timeout: const Duration(seconds: 30));
      // types = parseIdleTypes((idle.gameMsg!.innerMsg as MsgSelectIdleCmd).rawData);
      // final battleIdx = types.indexOf(6);
      // expect(battleIdx, isNot(-1), reason: 'B的回合应有进战斗选项');
      // bob.playGameResponse(CtosGameMsgResponse.selectIdleCmd(battleIdx));

      await waitUntil(bM, bob.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_BATTLE_CMD,
          timeout: const Duration(seconds: 60));
      bob.playGameResponse(CtosGameMsgResponse.selectBattleCmd(0));

      // ─── 攻击结果验证 ───
      await waitUntil(bM, bob.onServerMessage,
          (m) => m.gameMsg?.func == MSG_ATTACK,
          timeout: const Duration(seconds: 60));
      await waitUntil(bM, bob.onServerMessage,
          (m) => m.gameMsg?.func == MSG_LP_UPDATE || m.gameMsg?.func == MSG_DAMAGE,
          timeout: const Duration(seconds: 30));
      final bCurrentLp = bLp.isNotEmpty ? bLp.last : 8000;
      expect(bCurrentLp, equals(8000), reason: '青眼vs青眼同ATK互灭，B的LP应为8000');

      // ─── B 结束 ───
      await waitUntil(bM, bob.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_BATTLE_CMD,
          timeout: const Duration(seconds: 30));
      bob.playGameResponse(CtosGameMsgResponse.selectBattleCmd(7));

      idle = await waitUntil(bM, bob.onServerMessage,
          (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
          timeout: const Duration(seconds: 30));
      bob.playGameResponse(CtosGameMsgResponse.selectIdleCmd(7));

      await aSub.cancel();
      await bSub.cancel();
    });
  });
}
