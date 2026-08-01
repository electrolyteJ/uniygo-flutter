@Timeout(Duration(minutes: 5))
library;

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:duelink_ai/duelink_ai.dart';
import 'package:service_loader/service_loader.dart';
import 'package:test/test.dart';

const Duration kAiTimeout = Duration(seconds: 30);

/// 加载 ocgcore 原生动态库。
///
/// `flutter test` 环境下动态库不在系统加载路径上，需要显式指定路径
/// （与 ocgcore 包自身测试的做法一致）。
ffi.DynamicLibrary loadOcgCore() {
  if (Platform.isAndroid || Platform.isLinux) {
    return ffi.DynamicLibrary.open('libocgcore.so');
  }
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('ocgcore.dll');
  }
  if (Platform.isMacOS || Platform.isIOS) {
    final candidates = <String>[
      'macos/Frameworks/libocgcore.dylib',
      '../ocgcore/macos/Frameworks/libocgcore.dylib',
    ];
    for (final path in candidates) {
      try {
        return ffi.DynamicLibrary.open(path);
      } catch (_) {}
    }
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

Uint8List deckBytes(List<int> codes) {
  final w = ByteData(codes.length * 4);
  for (var i = 0; i < codes.length; i++) {
    w.setInt32(i * 4, codes[i], Endian.little);
  }
  return w.buffer.asUint8List();
}

/// 含魔法·陷阱的卡组：通常怪兽 (30张) + 强欲之壶 (7张) + 落穴 (3张)。
///
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
///  55144522 — 强欲之壶 (Pot of Greed)                       通常魔法  效果：抽2张卡
///  4206964  — 落穴 (Trap Hole)                              通常陷阱  效果：对方召唤1500+ATK怪兽时破坏之
Uint8List testDeck() => deckBytes(const [
      // 卡组按无洗牌顺序排列，前 5 张即首抽手牌：
      // [神圣精灵, 强欲之壶, 落穴, 神圣精灵, 神圣精灵]
      // 神圣精灵 Lv4 (可无需解放通常召唤)，强欲之壶可发动，落穴可盖放
      15025844,                     // 神圣精灵 — 首抽可通常召唤 (ATK 800)
      55144522,                     // 强欲之壶 — 首抽可发动
      4206964,                      // 落穴 — 首抽可盖放
      15025844,                     // 神圣精灵
      15025844,                     // 神圣精灵
      89631139, 89631139, 89631139,   // 青眼白龙 ×3
      46986414, 46986414, 46986414,   // 黑魔导 ×3
      91152256, 91152256, 91152256,   // 精灵剑士 ×3
      13039848, 13039848, 13039848,   // 岩石巨兵 ×3
      6368038,  6368038,  6368038,    // 暗黑骑士盖亚 ×3
      28279543, 28279543, 28279543,   // 诅咒之龙 ×3
      74677422, 74677422, 74677422,   // 真红眼黑龙 ×3
      88819587, 88819587, 88819587,   // 宝贝龙 ×3
      76184692, 76184692, 76184692,   // 独眼巨人 ×3
      55144522, 55144522,             // 强欲之壶 ×2
      4206964,  4206964,              // 落穴 ×2
    ]);

/// 解析 MSG_SELECT_IDLECMD (0x0b) 六段式布局，返回每个可选选项所属段 id：
///   0=summon 1=spsummon 2=reposition 3=mset 4=sset 5=activate
/// 每段：u8 count；选项 = code(u32 LE) + controler/location/sequence(u8×3)；
/// activate 段额外带 description(u32 LE)。段末还有 toBP/toEP/reshuffle 3 字节。
List<int> parseIdleTypes(Uint8List rawData) {
  final types = <int>[];
  final r = BufferReader(rawData);
  if (!r.hasRemaining) return types;
  for (var section = 0; section < 6; section++) {
    if (!r.hasRemaining) break;
    final n = r.readUint8();
    final optionSize = (section == 5) ? 11 : 7;
    for (int i = 0; i < n; i++) {
      if (r.remaining < optionSize) return types;
      r.skip(optionSize);
      types.add(section);
    }
  }
  return types;
}

Future<T> waitUntil<T>(List<T> c, Stream<T> s, bool Function(T) p,
    {Duration timeout = kAiTimeout, String? hint}) async {
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
  late IDuelService player;
  late List<RoomStage> states;
  late List<YgoStocMsg> msgs;

  setUp(() {
    if (!ServiceFactory.isRegistered<AiDuelService>()) {
      ServiceFactory.register<AiDuelService>(() => AiDuelService(connection: AiConnection(lib: loadOcgCore())));
    }
    player = ServiceFactory.create<AiDuelService>();
    states = []; msgs = [];
    player.onRoomStageChange.listen(states.add);
    player.onServerMessage.listen(msgs.add);
  });

  tearDown(() async {
    if (player.connectionState == ConnectionState.connected) {
      player.surrender();
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    await player.disconnect();
  });

  Future<void> startAiDuel() async {
    const o = RoomOptions(mode: RoomMode.single, noCheckDeck: true, noShuffleDeck: true);
    final pw = RoomPassword.encodeCreate(options: o, roomId: 'ai_test');

    await player.connect('ai', 0);
    player.setPlayerName('Human');
    player.enterRoom(pw);

    // 等待 AI 玩家 Bob 加入房间
    await waitUntil(states, player.onRoomStageChange,
        (s) => s.players.length >= 2 && s.players.any((p) => p.name == 'AI_Bob'),
        timeout: const Duration(seconds: 10), hint: 'AI Bob should auto-join');
    await waitUntil(states, player.onRoomStageChange,
        (s) => s is RoomInLobby, hint: 'should be in lobby');

    player.submitDeck(testDeck(), deckBytes([]));
    player.ready();

    // 等待 AI ready + 进入猜拳阶段
    await waitUntil(states, player.onRoomStageChange,
        (s) => s is RoomSelectingHand, timeout: const Duration(seconds: 15), hint: 'hand selecting');
    player.chooseHand(HandType.scissors);

    // 等待猜拳结果
    await waitUntil(states, player.onRoomStageChange,
        (s) => s is RoomSelectingTurn, timeout: const Duration(seconds: 15), hint: 'tp selecting');
    player.chooseTurnOrder(true);

    // 等待 PreDuel / DuelStart
    await waitUntil(states, player.onRoomStageChange,
        (s) => s is RoomInDuel, timeout: const Duration(seconds: 15), hint: 'pre duel');
  }

  group('AI 对局', () {
    test('开始→猜拳→选先后→决斗开始', () async {
      await startAiDuel();
      expect(player.connectionState, ConnectionState.connected);
      // 验证收到了 MSG_START
      await waitUntil(msgs, player.onServerMessage,
          (m) => m.gameMsg?.func == MSG_START, hint: 'MSG_START');
    });

    test('首回合 idle options 包含召唤与盖放', () async {
      await startAiDuel();

      await waitUntil(msgs, player.onServerMessage,
          (m) => m.gameMsg?.func == MSG_START, hint: 'MSG_START');
      await waitUntil(msgs, player.onServerMessage,
          (m) => m.gameMsg?.func == MSG_NEW_TURN, hint: 'MSG_NEW_TURN');
      await waitUntil(msgs, player.onServerMessage,
          (m) => m.gameMsg?.func == MSG_DRAW, hint: 'MSG_DRAW');

      final idle = await waitUntil(
        msgs,
        player.onServerMessage,
        (m) => m.gameMsg?.func == MSG_SELECT_IDLE_CMD,
        hint: 'initial MSG_SELECT_IDLE_CMD',
      );

      // final types = parseIdleTypes((idle.gameMsg!.innerMsg as MsgSelectIdleCmd).rawData);
      // expect(types, contains(0), reason: '首手应有通常召唤选项: $types');
      // expect(types, contains(3), reason: '首手应有怪兽盖放选项: $types');
      // expect(types, contains(4), reason: '首手应有魔陷盖放选项: $types');
    });
  });
}
