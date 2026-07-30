@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:duelink_online/duelink_online.dart';
import 'package:service_loader/service_loader.dart';
import 'package:test/test.dart';

/// 直连的真实对战服务器（srvpro，YGOPro Koishi Server）。
///
/// 这些是网络集成测试：需要能访问该服务器，且服务器行为符合
/// mycard/srvpro 房间协议（密码建房、房内聊天转发、准备同步、猜拳选先后等）。
const String kServerHost = 'koishi.momobako.com';
const int kServerPort = 7211;

/// 网络等待统一用较宽松的超时。
const Duration kNetTimeout = Duration(seconds: 30);

/// 每次运行生成唯一房间 ID，避免与残留房间或其他测试冲突。
String uniqueRoomId() =>
    'c${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

/// 构造一段由 int32 卡组编码组成的字节（小端）。
Uint8List deckBytes(List<int> codes) {
  final w = ByteData(codes.length * 4);
  for (var i = 0; i < codes.length; i++) {
    w.setInt32(i * 4, codes[i], Endian.little);
  }
  return w.buffer.asUint8List();
}

/// 合法测试卡组：13 种古老通常怪兽 ×3 + 1 种 ×1 = 40 张。
/// 通常怪兽不受禁限卡表约束，且任何服务端卡库都包含它们。
Uint8List legalMainDeck() => deckBytes(const [
      89631139, 89631139, 89631139, // 青眼白龙
      46986414, 46986414, 46986414, // 黑魔术师
      15025844, 15025844, 15025844, // 神秘精灵
      91152256, 91152256, 91152256, // 精灵剑士
      13039848, 13039848, 13039848, // 岩石巨兵
      6368038, 6368038, 6368038, // 盖亚骑士
      28279543, 28279543, 28279543, // 诅咒之龙
      74677422, 74677422, 74677422, // 真红眼黑龙
      88819587, 88819587, 88819587, // 宝贝龙
      76184692, 76184692, 76184692, // 独眼巨人
      41392891, 41392891, 41392891, // 小恶魔
      15303296, 15303296, 15303296, // 岩石精灵
      87796900, 87796900, 87796900, // 翼龙守卫
      32452818, // 海狸战士
    ]);

/// 等待 [collected] 中出现满足条件的元素。
///
/// 若历史事件中已有匹配则立即返回，否则监听后续事件，避免错过
/// 在订阅之前就已经到达的广播事件。
Future<T> waitUntil<T>(
  List<T> collected,
  Stream<T> stream,
  bool Function(T) predicate, {
  Duration timeout = kNetTimeout,
  String? hint,
}) async {
  final hit = collected.where(predicate);
  if (hit.isNotEmpty) return hit.last;

  final completer = Completer<T>();
  late final StreamSubscription<T> sub;
  sub = stream.listen((event) {
    if (!completer.isCompleted && predicate(event)) {
      completer.complete(event);
      sub.cancel();
    }
  });

  // 订阅建立后再查一次历史，消除检查与订阅之间的竞态。
  final recheck = collected.where(predicate);
  if (recheck.isNotEmpty && !completer.isCompleted) {
    completer.complete(recheck.last);
    await sub.cancel();
  }

  return completer.future.timeout(
    timeout,
    onTimeout: () => throw TimeoutException(
      '等待条件超时（${timeout.inSeconds}s）${hint == null ? '' : '：$hint'}',
    ),
  );
}

void main() {
  // 每次运行使用独立的玩家名：该服务器会按玩家名保持会话（同名登录被视为
  // “重新连接”），复用名字会导致跨用例干扰。
  final runId = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final aliceName = 'A_$runId';
  final bobName = 'B_$runId';

  late IDuelService alice;
  late IDuelService bob;

  // 从连接开始就收集双方全部事件，避免错过广播。
  late List<RoomState> aliceStates;
  late List<RoomState> bobStates;
  late List<YgoStocMsg> aliceMessages;
  late List<YgoStocMsg> bobMessages;

  setUp(() {
    registerOnlineService();
    alice = createDuelService(ServiceType.duelink_online) as IDuelService;
    bob = createDuelService(ServiceType.duelink_online) as IDuelService;

    aliceStates = [];
    bobStates = [];
    aliceMessages = [];
    bobMessages = [];
    alice.onRoomStateChange.listen(aliceStates.add);
    bob.onRoomStateChange.listen(bobStates.add);
    alice.onMessage.listen(aliceMessages.add);
    bob.onMessage.listen(bobMessages.add);
  });

  tearDown(() async {
    // 若用例使决斗处于进行中，先投降让服务端正常结束决斗并清理房间，
    // 避免残留的“等待重连”房间影响后续用例（服务端会按 IP 限制活跃对局）。
    if (alice.connectionState == ConnectionState.connected) {
      alice.sendSurrender();
    }
    if (bob.connectionState == ConnectionState.connected) {
      bob.sendSurrender();
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    await alice.disconnect();
    await bob.disconnect();
    // 给服务端留出清理会话的时间，避免连续用例被限流。
    await Future<void>.delayed(const Duration(seconds: 1));
  });

  /// 连接服务器，以 [name] 身份、用 [passwd] 加入/创建房间。
  Future<void> joinRoom(IDuelService svc, String name, String passwd) async {
    await svc.connect(kServerHost, kServerPort);
    svc.sendPlayerInfo(name);
    svc.sendJoinGame(0, passwd);
  }

  /// Alice 建房、Bob 进房，等待双方互相可见。
  Future<void> setupDuel() async {
    final roomId = uniqueRoomId();
    const options = RoomOptions(
      mode: RoomMode.single,
      noCheckDeck: true,
      noShuffleDeck: true,
    );
    // 该服务器（srvpro）以完整密码字符串作为房间标识：
    // 第一名玩家用它建房，第二名玩家发送相同密码即可进房
    // （若用 encodeJoin 生成不同密码，服务端会另开一个新房间）。
    final roomPassword =
        RoomPassword.encodeCreate(options: options, roomId: roomId);

    await joinRoom(alice, aliceName, roomPassword);
    await waitUntil(
      aliceStates,
      alice.onRoomStateChange,
      (s) => s.joined && s.selfType == SelfType.player1,
      hint: 'Alice 建房并拿到 player1 身份',
    );

    await joinRoom(bob, bobName, roomPassword);
    await waitUntil(
      bobStates,
      bob.onRoomStateChange,
      (s) => s.players.length >= 2 && s.players.any((p) => p.name == aliceName),
      hint: 'Bob 进房并看到双方玩家',
    );
    await waitUntil(
      aliceStates,
      alice.onRoomStateChange,
      (s) => s.players.length >= 2 && s.players.any((p) => p.name == bobName),
      hint: 'Alice 收到 Bob 的入场通知',
    );
  }

  /// 双方提交卡组并准备，等待双方都收到「全部准备」状态。
  Future<void> readyBoth() async {
    final extra = deckBytes([]);
    alice.sendUpdateDeck(legalMainDeck(), extra);
    bob.sendUpdateDeck(legalMainDeck(), extra);
    // 留出服务端处理卡组的时间，再发送准备。
    await Future<void>.delayed(const Duration(milliseconds: 500));
    alice.sendReady();
    bob.sendReady();

    bool allReady(RoomState s) =>
        s.players.length == 2 && s.players.every((p) => p.ready);

    // 服务端偶尔会忽略一次 READY（网络/限流抖动），未就绪时重发。
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await waitUntil(aliceStates, alice.onRoomStateChange, allReady,
            timeout: const Duration(seconds: 8), hint: 'Alice 侧双方都准备');
        await waitUntil(bobStates, bob.onRoomStateChange, allReady,
            timeout: const Duration(seconds: 8), hint: 'Bob 侧双方都准备');
        return;
      } on TimeoutException {
        alice.sendReady();
        bob.sendReady();
      }
    }
    await waitUntil(aliceStates, alice.onRoomStateChange, allReady,
        hint: 'Alice 侧双方都准备');
    await waitUntil(bobStates, bob.onRoomStateChange, allReady,
        hint: 'Bob 侧双方都准备');
  }

  group('两名玩家在线对战（直连 $kServerHost:$kServerPort）', () {
    test('双方加入同一房间并互相可见', () async {
      await setupDuel();

      expect(alice.connectionState, ConnectionState.connected);
      expect(bob.connectionState, ConnectionState.connected);

      final a = aliceStates.lastWhere(
          (s) => s.selfType == SelfType.player1 && s.players.length >= 2);
      expect(a.joined, isTrue);
      expect(a.isHost, isTrue, reason: '先建房的 Alice 应为房主');
      expect(a.players.map((p) => p.name), containsAll([aliceName, bobName]));

      final b = bobStates.lastWhere(
          (s) => s.selfType == SelfType.player2 && s.players.length >= 2);
      expect(b.joined, isTrue);
      expect(b.isHost, isFalse, reason: '后进房的 Bob 不是房主');
      expect(b.players.map((p) => p.name), containsAll([aliceName, bobName]));
    });

    test('聊天消息双向收发', () async {
      await setupDuel();

      // Alice -> Bob
      alice.sendChat('你好，Bob！');
      final atBob = await waitUntil(
        bobMessages,
        bob.onMessage,
        (m) => m.chat?.message == '你好，Bob！',
        hint: 'Bob 收到 Alice 的聊天',
      );
      expect(atBob.chat, isNotNull);

      // Bob -> Alice
      bob.sendChat('你好，Alice！');
      await waitUntil(
        aliceMessages,
        alice.onMessage,
        (m) => m.chat?.message == '你好，Alice！',
        hint: 'Alice 收到 Bob 的聊天',
      );
    });

    test('连续发送的多条消息按顺序到达对方', () async {
      await setupDuel();

      for (final text in ['消息1', '消息2', '消息3']) {
        alice.sendChat(text);
      }
      await waitUntil(
        bobMessages,
        bob.onMessage,
        (m) => m.chat?.message == '消息3',
        hint: 'Bob 收到第 3 条消息',
      );

      final received = bobMessages
          .where((m) => m.chat != null)
          .map((m) => m.chat!.message)
          .toList();
      expect(received, containsAllInOrder(['消息1', '消息2', '消息3']));
    });

    test('完整决斗流程：开始 -> 猜拳 -> 选先后 -> 决斗开始', () async {
      await setupDuel();
      await readyBoth();
      alice.sendStart();

      // 服务端要求双方猜拳。
      await waitUntil(aliceStates, alice.onRoomStateChange,
          (s) => s.stage == RoomStage.handSelecting,
          hint: 'Alice 收到猜拳请求');
      await waitUntil(bobStates, bob.onRoomStateChange,
          (s) => s.stage == RoomStage.handSelecting,
          hint: 'Bob 收到猜拳请求');

      // Alice 出石头、Bob 出剪刀 -> Alice 胜。
      alice.sendHandResult(HandType.rock);
      bob.sendHandResult(HandType.scissors);

      final handAtAlice = await waitUntil(
        aliceStates,
        alice.onRoomStateChange,
        (s) => s.stage == RoomStage.handSelected,
        hint: 'Alice 收到猜拳结果',
      );
      expect(handAtAlice.myHandResult, HandType.rock.value);
      expect(handAtAlice.opponentHandResult, HandType.scissors.value);

      final handAtBob = await waitUntil(
        bobStates,
        bob.onRoomStateChange,
        (s) => s.stage == RoomStage.handSelected,
        hint: 'Bob 收到猜拳结果',
      );
      expect(handAtBob.myHandResult, HandType.scissors.value);
      expect(handAtBob.opponentHandResult, HandType.rock.value);

      // 胜者 Alice 选择先攻 -> 双方收到 MSG_START，决斗正式开始。
      await waitUntil(aliceStates, alice.onRoomStateChange,
          (s) => s.stage == RoomStage.tpSelecting,
          hint: 'Alice 收到先后手选择');
      alice.sendTpResult(true);

      await waitUntil(
        aliceStates,
        alice.onRoomStateChange,
        (s) => s.stage == RoomStage.tpSelected && s.isFirstTurn == true,
        hint: 'Alice 确认先攻',
      );
      await waitUntil(bobStates, bob.onRoomStateChange,
          (s) => s.stage == RoomStage.tpSelected,
          hint: 'Bob 收到决斗开始');
    });
  });
}
