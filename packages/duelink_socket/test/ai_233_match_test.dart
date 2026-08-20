@Timeout(Duration(minutes: 6))
library;

/// 233 服 AI 对决 match（三局两胜）局间流程复现测试 —— 用户报告的确切场景。
///
/// 场景：s1.ygo233.com:233（srvpro），主机密码 'AI,M,...' 创建服务器端 AI 房。
/// 用户报告：第一局结束无胜败提示直接跳等待室；换备+准备后第二局不重开，
/// 卡在第一局结束画面。
///
/// 本测试在真实 233 服跑完整链路并打印全部阶段/协议时间线：
///   进 AI 房(match) → 准备 → 猜拳/选先攻 → 第一局 MSG_START → 投降
///   → CHANGE_SIDE → 换备(UPDATE_DECK+READY) → 期望第二局 MSG_START。
import 'dart:async';
import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:duelink_socket/duelink_socket.dart';
import 'package:service_loader/service_loader.dart';
import 'package:test/test.dart';

const String kHost = 's1.ygo233.com';
const int kPort = 233;

Uint8List deckBytesOf(List<int> codes) {
  final w = ByteData(codes.length * 4);
  for (var i = 0; i < codes.length; i++) {
    w.setInt32(i * 4, codes[i], Endian.little);
  }
  return w.buffer.asUint8List();
}

/// 40 张填充通常怪兽（NC 不检查卡组）。
List<int> fillDeck() => const [
      89631139, 46986414, 13039848, 6368038, 28279543, 74677422, 88819587,
      76184692, 41392891, 15303296, 87796900, 32452818, 89631139, 46986414,
      13039848, 6368038, 28279543, 74677422, 88819587, 76184692, 41392891,
      15303296, 87796900, 32452818, 89631139, 46986414, 13039848, 6368038,
      28279543, 74677422, 88819587, 76184692, 41392891, 15303296, 87796900,
      32452818, 89631139, 46986414, 13039848,
    ];

/// 被动应答器：放过对局中所有中间交互（投降前引擎不卡等待）。
StreamSubscription<YgoStocMsg> autoAnswer(IDuelService svc) {
  return svc.onServerMessage.listen((msg) {
    final gm = msg.gameMsg;
    if (gm == null) return;
    CtosGameMsgResponse? r;
    switch (gm.func) {
      case MSG_SELECT_PLACE:
      case MSG_SELECT_DISFIELD:
        final m = gm.innerMsg as MsgSelectPlace;
        r = CtosGameMsgResponse.selectPlace(CtosSelectPlace(
            player: m.player, zone: CARD_ZONE_MZONE, sequence: 0));
        break;
      case MSG_SELECT_POSITION:
        r = CtosGameMsgResponse.selectPosition(POS_FACEUP_ATTACK);
        break;
      case MSG_SELECT_CHAIN:
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
      case MSG_SELECT_IDLE_CMD:
        r = CtosGameMsgResponse.selectIdleCmd(7); // 结束回合
        break;
      case MSG_SELECT_BATTLE_CMD:
        r = CtosGameMsgResponse.selectBattleCmd(3); // EP
        break;
    }
    if (r != null) svc.playGameResponse(r);
  });
}

void main() {
  group('233 服 AI match 局间流程', () {
    test('第一局投降 → 换备 → 第二局应重开', () async {
      if (!ServiceFactory.isRegistered<SocketDuelService>()) {
        ServiceFactory.register<SocketDuelService>(SocketDuelService.new);
      }
      final svc = ServiceFactory.create<SocketDuelService>();
      final stages = <RoomStage>[];
      final msgs = <YgoStocMsg>[];
      // 反应式驱动：每次猜拳/选先攻提示都应答（AI 猜拳可能平局重来，
      // match 第二局还会再选先后攻）。
      var handCount = 0;
      var tpCount = 0;
      void drive(RoomStage s) {
        if (s is RoomSelectingHand) {
          handCount++;
          // ignore: avoid_print
          print('[act] 第$handCount次猜拳: 出石头');
          svc.chooseHand(HandType.rock);
        } else if (s is RoomSelectingTurn) {
          tpCount++;
          // ignore: avoid_print
          print('[act] 第$tpCount次选先后攻: 选先攻');
          svc.chooseTurnOrder(true);
        }
      }

      final subs = <StreamSubscription<dynamic>>[
        svc.onRoomStageChange.listen((s) {
          stages.add(s);
          // ignore: avoid_print
          print('[stage] ${s.runtimeType}');
          drive(s);
        }),
        svc.onServerMessage.listen((m) {
          msgs.add(m);
          final gm = m.gameMsg;
          if (gm != null) {
            if (gm.func == MSG_START || gm.func == MSG_WIN) {
              // ignore: avoid_print
              print('[msg] GAME_MSG func=${gm.func}');
            }
          } else {
            // ignore: avoid_print
            print('[msg] protoId=${m.protoId}'
                '${m.chat != null ? " chat=${m.chat!.message}" : ""}'
                '${m.errorMsg != null ? " error=${m.errorMsg}" : ""}');
          }
        }),
        autoAnswer(svc),
      ];
      addTearDown(() async {
        for (final s in subs) {
          await s.cancel();
        }
        if (svc.connectionState == ConnectionState.connected) {
          svc.surrender();
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        await svc.disconnect();
      });

      Future<RoomStage> waitStage(bool Function(RoomStage) p, String hint,
          {Duration timeout = const Duration(seconds: 30)}) async {
        final deadline = DateTime.now().add(timeout);
        while (DateTime.now().isBefore(deadline)) {
          for (final s in stages) {
            if (p(s)) return s;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        throw TimeoutException('wait $hint; stages=${stages.map((s) => s.runtimeType).join("->")}');
      }

      /// 只等「新」阶段（列表已有同类时跳过历史值）。
      Future<RoomStage> waitNewStage(bool Function(RoomStage) p, String hint,
          {Duration timeout = const Duration(seconds: 30)}) async {
        final seen = stages.length;
        final deadline = DateTime.now().add(timeout);
        while (DateTime.now().isBefore(deadline)) {
          for (var i = seen; i < stages.length; i++) {
            if (p(stages[i])) return stages[i];
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        throw TimeoutException('wait new $hint; stages=${stages.map((s) => s.runtimeType).join("->")}');
      }

      // ── 1. 进 AI 房（match 模式）──
      await svc.connect(Uri.parse('tcp://$kHost:$kPort'));
      svc.setPlayerName('MatchProbe');
      svc.enterRoom('AI,M,MR5,NC,NS');
      await waitStage((s) => s is RoomInLobby, 'RoomInLobby');

      // AI 未自动加入时发 /ai 唤醒（兼容两种 233 行为）。
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!stages.any((s) => s.players.length >= 2)) {
        // ignore: avoid_print
        print('[act] AI 未自动加入，发送 /ai 唤醒');
        svc.sendChat('/ai');
      }
      await waitStage((s) => s.players.length >= 2, 'AI 进房',
          timeout: const Duration(seconds: 20));

      // ── 2. 提交卡组 + 准备 + 开局 ──
      svc.submitDeck(deckBytesOf(fillDeck()), deckBytesOf([]), deckBytesOf([]));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      svc.ready();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      svc.startDuel();

      // ── 3. 猜拳 / 选先攻（反应式驱动处理平局重猜与先后攻选择）──
      await waitStage((s) => s is RoomInDuel, '第一局 RoomInDuel',
          timeout: const Duration(seconds: 60));
      final game1Start =
          msgs.where((m) => m.gameMsg?.func == MSG_START).length;
      expect(game1Start, 1, reason: '第一局 MSG_START 应恰好一次');

      // ── 4. 投降结束第一局，观察局间消息 ──
      svc.surrender();
      await waitNewStage((s) => s is RoomSideDecking, 'RoomSideDecking',
          timeout: const Duration(seconds: 20));

      // ── 5. 换备：重新提交卡组 + 准备 ──
      await Future<void>.delayed(const Duration(seconds: 1));
      svc.submitDeck(deckBytesOf(fillDeck()), deckBytesOf([]), deckBytesOf([]));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      svc.ready();

      // ── 6. 期望第二局：DUEL_START → (败者选先后攻，反应式驱动应答) → MSG_START ──
      // 按出现次数判定（第二局链路可能在换备等待间隙内瞬间走完，
      // waitNewStage 的快照起点可能错过它）。
      await waitStage(
        (s) => stages.whereType<RoomInDuel>().length >= 2,
        '第二局 RoomInDuel',
        timeout: const Duration(seconds: 45),
      );
      final game2Start =
          msgs.where((m) => m.gameMsg?.func == MSG_START).length;
      expect(game2Start, 2, reason: '第二局 MSG_START 应到达');
    });
  });
}
