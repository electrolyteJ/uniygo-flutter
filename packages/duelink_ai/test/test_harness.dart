/// AI 对局测试共享基建：测试卡表 / ocgcore 动态库与脚本加载器 /
/// 消息游标 / 人类提示自动应答。
///
/// 由 ai_duel_test.dart 抽离，供 agent_http_e2e_test.dart 复用。
library;

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:duelink_ai/duelink_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocgcore/ocgcore.dart' show ScriptLoader;
import 'package:ygo_data/card_info.dart';

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
ffi.DynamicLibrary? loadCoreLib() {
  if (Platform.isMacOS) {
    for (final p in [
      // 从 packages/duelink_ai 目录运行
      '../ocgcore/macos/Frameworks/libocgcore.dylib',
      // 从 workspace 根目录运行
      'packages/ocgcore/macos/Frameworks/libocgcore.dylib',
      'macos/Frameworks/libocgcore.dylib',
    ]) {
      try {
        return ffi.DynamicLibrary.open(p);
      } catch (_) {}
    }
  }
  return null; // 其他平台走 createOcgCore 的默认查找
}

/// 文件系统脚本加载器（flutter_test 环境 rootBundle 拿不到依赖包
/// 资产，按 [lib] 同样的注入思路，直接从磁盘读 ocgcore 的 lua 脚本）。
class FileScriptLoader extends ScriptLoader {
  static const _roots = [
    'packages/ocgcore/vendor/scripts/', // workspace 根目录运行
    '../ocgcore/vendor/scripts/', // packages/duelink_ai 目录运行
  ];

  final _fsCache = <String, Uint8List>{};

  @override
  Future<Uint8List?> load(String name) async {
    final cached = _fsCache[name];
    if (cached != null) return cached;
    for (final root in _roots) {
      final file = File('$root$name');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        _fsCache[name] = bytes;
        return bytes;
      }
    }
    return super.load(name);
  }
}

/// 测试卡表（与上方卡组常量对应）—— App 中卡数据由 ICardService 提供
/// （service_singleton.dart 注入），测试环境没有注册服务，需要用
/// [AiDuelService.setCardConverter] 显式注入等价的卡数据源。
final Map<int, CardInfo> testCardInfos = {
  89631139: const CardInfo(
    code: 89631139,
    type: 0x11,
    level: 8,
    attribute: 0x10,
    race: 0x2000,
    attack: 3000,
    defense: 2500,
    name: 'Blue-Eyes White Dragon',
  ),
  46986414: const CardInfo(
    code: 46986414,
    type: 0x11,
    level: 7,
    attribute: 0x20,
    race: 0x2,
    attack: 2500,
    defense: 2100,
    name: 'Dark Magician',
  ),
  15025844: const CardInfo(
    code: 15025844,
    type: 0x11,
    level: 4,
    attribute: 0x10,
    race: 0x2,
    attack: 800,
    defense: 2000,
    name: 'Mystical Elf',
  ),
  91152256: const CardInfo(
    code: 91152256,
    type: 0x11,
    level: 4,
    attribute: 0x01,
    race: 0x1,
    attack: 1400,
    defense: 1200,
    name: 'Celtic Guardian',
  ),
  13039848: const CardInfo(
    code: 13039848,
    type: 0x11,
    level: 3,
    attribute: 0x01,
    race: 0x100,
    attack: 1300,
    defense: 2000,
    name: 'Giant Soldier of Stone',
  ),
  6368038: const CardInfo(
    code: 6368038,
    type: 0x11,
    level: 7,
    attribute: 0x01,
    race: 0x1,
    attack: 2300,
    defense: 2100,
    name: 'Gaia The Fierce Knight',
  ),
  28279543: const CardInfo(
    code: 28279543,
    type: 0x11,
    level: 5,
    attribute: 0x20,
    race: 0x2000,
    attack: 2000,
    defense: 1500,
    name: 'Curse of Dragon',
  ),
  74677422: const CardInfo(
    code: 74677422,
    type: 0x11,
    level: 7,
    attribute: 0x20,
    race: 0x2000,
    attack: 2400,
    defense: 2000,
    name: 'Red-Eyes Black Dragon',
  ),
  88819587: const CardInfo(
    code: 88819587,
    type: 0x11,
    level: 4,
    attribute: 0x04,
    race: 0x2000,
    attack: 1200,
    defense: 700,
    name: 'Baby Dragon',
  ),
  76184692: const CardInfo(
    code: 76184692,
    type: 0x11,
    level: 4,
    attribute: 0x01,
    race: 0x8000,
    attack: 1200,
    defense: 1000,
    name: 'Hitotsu-Me Giant',
  ),
  55144522: const CardInfo(
    code: 55144522,
    type: 0x2,
    name: 'Pot of Greed',
    desc: 'Draw 2 cards.',
  ),
  4206964: const CardInfo(
    code: 4206964,
    type: 0x4,
    name: 'Trap Hole',
    desc:
        'When your opponent Normal Summons a monster with 1000 or '
        'more ATK: Target that monster; destroy it.',
  ),
};

void injectTestCards(AiDuelService service) {
  service.setCardConverter((code) async => testCardInfos[code]);
}

// ============================================================
// 工具函数
// ============================================================

/// 将 card code 列表编码为 Uint8List（4 字节 LE 每个 code），供 submitDeck 使用。
Uint8List encodeDeck(List<int> codes) {
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
List<int> buildTestDeck() {
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
bool hasGameMsg(List<YgoStocMsg> messages, int funcId) {
  return messages.any((m) => m.gameMsg?.func == funcId);
}

/// 共享消息游标 — 测试中对 onServerMessage 的所有等待/应答都通过
/// 单一的 allMsgs 列表 + 游标顺序消费，避免多个 broadcast 监听者
/// 各自 `.first` 造成的应答竞争/重复应答。
class MsgCursor {
  MsgCursor(this.messages);

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
bool isHumanPrompt(StocGameMessage gm) {
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
CtosSelectPlace firstFreePlace(MsgSelectPlace m) {
  for (var s = 0; s <= 4; s++) {
    if (m.field & (1 << s) == 0) {
      return CtosSelectPlace(
        player: m.player,
        zone: CARD_ZONE_MZONE,
        sequence: s,
      );
    }
  }
  for (var s = 0; s <= 4; s++) {
    if (m.field & (1 << (8 + s)) == 0) {
      return CtosSelectPlace(
        player: m.player,
        zone: CARD_ZONE_SZONE,
        sequence: s,
      );
    }
  }
  // 兜底：额外怪兽区
  return CtosSelectPlace(player: m.player, zone: CARD_ZONE_MZONE, sequence: 5);
}

/// 应答单个人类方的选择类消息（被动策略：不连锁、不发动、直接结束）。
/// 返回是否应答了该消息。
bool answerHumanPrompt(
  AiDuelService service,
  StocGameMessage gm, {
  required bool endTurn,
}) {
  if (!isHumanPrompt(gm)) return false;
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
        service.playGameResponse(
          CtosGameMsgResponse.selectBattleCmd(
            cmd.commandGroups[1].options.first.response,
          ),
        );
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
        CtosGameMsgResponse.selectPlace(firstFreePlace(selPlace)),
      );
      return true;

    case MSG_SELECT_POSITION:
      service.playGameResponse(
        CtosGameMsgResponse.selectPosition(POS_FACEUP_ATTACK),
      );
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
Future<MsgSelectIdleCmd?> nextHumanIdleCmd(
  AiDuelService service,
  MsgCursor cursor, {
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
    if (gm.func == MSG_SELECT_IDLE_CMD && isHumanPrompt(gm)) {
      return gm.innerMsg as MsgSelectIdleCmd;
    }
    answerHumanPrompt(service, gm, endTurn: false);
  }
  return null;
}

/// 剧本阶段结束后的自动驾驶：被动应答所有人类提示（直接结束回合），
/// 直到决斗结束（MSG_WIN / STOC_DUEL_END）。返回是否等到决斗结束。
Future<bool> autopilotUntilDuelEnd(
  AiDuelService service,
  MsgCursor cursor, {
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
    answerHumanPrompt(service, gm, endTurn: true);
  }
  return false;
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
        '  STOC_GAME_MSG func=${gm.func} (0x${gm.func.toRadixString(16).padLeft(2, '0')}) inner=${gm.innerMsg.runtimeType} → $gm',
      );
    } else {
      print('  STOC protoId=${m.protoId} → $m');
    }
  }
}
