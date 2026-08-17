/// 引擎选择类消息 → ygo-agent [ActionMsgData] 解码器。
///
/// 以 ygo-agent env（ygopro.h）各 MSG 处理器为基准移植：动作列表顺序、
/// response 约定、以及 env 的若干怪癖（to_ep 在 to_bp/to_m2 可用时省略、
/// announce_attrib 线上没有 min 字节、select_chain forced = 任一链强制等）
/// 全部按训练分布复刻。
///
/// 与 duelink 的 `Msg*.decode` 的差异（故意不复用）：
///  - select_chain 的 code 不做 `% 1000000000`（那是显示层 hack，会破坏
///    0x80000000 之类的 field-only 标志）；
///  - announce_attrib 按本 fork 线格式解析（无 min 字节）。
library;

import 'dart:typed_data';

import 'package:duelink/duelink.dart' show BufferReader;
import 'package:ocgcore/ocgcore.dart';
import '../enums.dart';
import '../legal_actions.dart';
import '../models.dart';

import 'raw_maps.dart';

/// 解码结果：应答玩家 + 动作消息数据。
class AgentActionMsg {
  const AgentActionMsg({required this.player, required this.data});

  /// 待应答玩家 id（引擎绝对坐标）。
  final int player;
  final ActionMsgData data;
}

/// 把引擎绝对玩家 id 转为模型视角的 [Controller]（[player] 为"我方"）。
Controller _relController(int c, int player) =>
    c == player ? Controller.me : Controller.opponent;

/// 原始 location 字节 → [Location]，未知区域抛 [NotSupportedException]。
Location _locationOrThrow(int raw) {
  final loc = locationFromRaw(raw);
  if (loc == null) {
    throw NotSupportedException('unsupported location byte 0x'
        '${raw.toRadixString(16)}');
  }
  return loc;
}

/// 4 字节 info location（c,l,s,pos/ss）→ 模型 [CardLocation]。
///
/// l 含 LOCATION_OVERLAY 位时，ss 字节为素材序号；否则 ss 是 position
/// 字节，模型侧不需要（spec 不含 position）。
CardLocation _agentCardLocation(
        int c, int l, int s, int ss, int player) =>
    CardLocation(
      controller: _relController(c, player),
      location: _locationOrThrow(l & ~LOCATION_OVERLAY),
      sequence: s,
      overlaySequence: (l & LOCATION_OVERLAY) != 0 ? ss : -1,
    );

/// 解码一条待应答消息（[payload] 不含 func 头字节）。
///
/// 对 env 不支持的形状（select_counter、sort_card、count!=1 的
/// place/disfield/announce_attrib、1..12 之外的 announce_number 等）抛
/// [NotSupportedException] —— 集成层据此回退规则 AI。
AgentActionMsg decodeAgentActionMsg(int func, Uint8List payload) {
  final r = BufferReader(payload);
  final ActionMsgData data;
  // MSG_SELECT_SUM 首字节是 mode，player 在第二字节；其余选择类消息
  // 首字节即 player。
  final player = func == MSG_SELECT_SUM ? payload[1] : r.readUint8();
  data = switch (func) {
    MSG_SELECT_IDLECMD => _decodeIdleCmd(r, player),
    MSG_SELECT_BATTLECMD => _decodeBattleCmd(r, player),
    MSG_SELECT_CHAIN => _decodeChain(r, player),
    MSG_SELECT_CARD => _decodeSelectCard(r, player),
    MSG_SELECT_TRIBUTE => _decodeTribute(r, player),
    MSG_SELECT_UNSELECT_CARD => _decodeUnselectCard(r, player),
    MSG_SELECT_SUM => _decodeSum(r),
    MSG_SELECT_POSITION => _decodePosition(r),
    MSG_SELECT_EFFECTYN => _decodeEffectYn(r, player),
    MSG_SELECT_YESNO => _decodeYesNo(r),
    MSG_SELECT_OPTION => _decodeOption(r),
    MSG_SELECT_PLACE => _decodePlace(r, player, disfield: false),
    MSG_SELECT_DISFIELD => _decodePlace(r, player, disfield: true),
    MSG_ANNOUNCE_ATTRIB => _decodeAnnounceAttrib(r),
    MSG_ANNOUNCE_NUMBER => _decodeAnnounceNumber(r),
    _ =>
      throw NotSupportedException('func $func not supported by ygo-agent'),
  };
  return AgentActionMsg(player: player, data: data);
}

// ── 各消息解码 ────────────────────────────────────────────────────────

/// 读一组 idle/battle 动作条目：count u8 + count × (code u32 + c,l,s)。
/// 返回 (code 忽略与否由调用方决定, c, l, s) —— code 原样带回。
List<(int, int, int, int)> _readCmdEntries(BufferReader r) {
  final count = r.readUint8();
  return [
    for (var i = 0; i < count; i++)
      (r.readUint32(), r.readUint8(), r.readUint8(), r.readUint8()),
  ];
}

/// activate 组变体：desc u32 与每个条目交错写入（playerop.cpp 线序：
/// code, c, l, s, desc；不是全部条目之后再跟 desc）。
List<(int, int, int, int, int)> _readCmdEntriesWithDesc(BufferReader r) {
  final count = r.readUint8();
  return [
    for (var i = 0; i < count; i++)
      (r.readUint32(), r.readUint8(), r.readUint8(), r.readUint8(),
          r.readUint32()),
  ];
}

MsgSelectIdleCmd _decodeIdleCmd(BufferReader r, int player) {
  final cmds = <IdleCmd>[];
  void group(IdleCmdType type, int cmdIndex) {
    final entries = _readCmdEntries(r);
    for (var i = 0; i < entries.length; i++) {
      final (code, c, l, s) = entries[i];
      cmds.add(IdleCmd(
        cmdType: type,
        data: IdleCmdData(
          cardInfo: CardInfo(
            code: code,
            controller: _relController(c, player),
            location: _locationOrThrow(l),
            sequence: s,
          ),
          effectDescription: 0,
          response: (i << 16) | cmdIndex,
        ),
      ));
    }
  }

  // 线序即动作序：summon, sp_summon, reposition, mset, set, activate。
  group(IdleCmdType.summon, 0);
  group(IdleCmdType.spSummon, 1);
  group(IdleCmdType.reposition, 2);
  group(IdleCmdType.mset, 3);
  group(IdleCmdType.set, 4);
  final activateEntries = _readCmdEntriesWithDesc(r);
  for (var i = 0; i < activateEntries.length; i++) {
    final (code, c, l, s, desc) = activateEntries[i];
    cmds.add(IdleCmd(
      cmdType: IdleCmdType.activate,
      data: IdleCmdData(
        cardInfo: CardInfo(
          code: code,
          controller: _relController(c, player),
          location: _locationOrThrow(l),
          sequence: s,
        ),
        effectDescription: desc,
        response: (i << 16) | 5,
      ),
    ));
  }

  final toBp = r.readUint8() != 0;
  final toEp = r.readUint8() != 0;
  // can_shuffle：env 读取但忽略。
  if (r.hasRemaining) r.skip(1);

  if (toBp) cmds.add(IdleCmd(cmdType: IdleCmdType.toBp));
  // env 怪癖：to_bp 可用时 to_ep 不进动作表。
  if (toEp && !toBp) cmds.add(IdleCmd(cmdType: IdleCmdType.toEp));
  return MsgSelectIdleCmd(idleCmds: cmds);
}

MsgSelectBattleCmd _decodeBattleCmd(BufferReader r, int player) {
  final cmds = <BattleCmd>[];

  // 线序：activate 组在前、attack 组在后（与 env 动作表一致）。
  // activate 的 desc 与条目交错（playerop.cpp）。
  final activateEntries = _readCmdEntriesWithDesc(r);
  for (var i = 0; i < activateEntries.length; i++) {
    final (code, c, l, s, desc) = activateEntries[i];
    cmds.add(BattleCmd(
      cmdType: BattleCmdType.activate,
      data: BattleCmdData(
        cardInfo: CardInfo(
          code: code,
          controller: _relController(c, player),
          location: _locationOrThrow(l),
          sequence: s,
        ),
        effectDescription: desc,
        directAttackable: false,
        response: (i << 16) | 0,
      ),
    ));
  }
  final attackEntries = _readCmdEntries(r);
  for (var i = 0; i < attackEntries.length; i++) {
    final (code, c, l, s) = attackEntries[i];
    cmds.add(BattleCmd(
      cmdType: BattleCmdType.attack,
      data: BattleCmdData(
        cardInfo: CardInfo(
          code: code,
          controller: _relController(c, player),
          location: _locationOrThrow(l),
          sequence: s,
        ),
        effectDescription: 0,
        directAttackable: r.readUint8() != 0,
        response: (i << 16) | 1,
      ),
    ));
  }

  final toM2 = r.readUint8() != 0;
  final toEp = r.readUint8() != 0;
  if (toM2) cmds.add(BattleCmd(cmdType: BattleCmdType.toM2));
  // env 怪癖：to_m2 可用时 to_ep 不进动作表。
  if (toEp && !toM2) cmds.add(BattleCmd(cmdType: BattleCmdType.toEp));
  return MsgSelectBattleCmd(battleCmds: cmds);
}

MsgSelectChain _decodeChain(BufferReader r, int player) {
  final size = r.readUint8();
  r.skip(1); // spe_count：env 不使用
  r.skip(8); // hint_timing[player] u32 + hint_timing[1-player] u32

  final chains = <Chain>[];
  var forced = false;
  for (var i = 0; i < size; i++) {
    r.skip(1); // flag（EDESC_OPERATION / EDESC_RESET / 0）
    if (r.readUint8() != 0) forced = true;
    // 注意：不做 duelink 的 `% 1000000000` 显示 hack。
    final code = r.readUint32();
    final c = r.readUint8();
    final l = r.readUint8();
    final s = r.readUint8();
    final pos = r.readUint8();
    final desc = r.readUint32();
    chains.add(Chain(
      code: code,
      location: _agentCardLocation(c, l, s, pos, player),
      effectDescription: desc,
      response: i,
    ));
  }
  // 任一链强制时 core 拒绝 -1 应答 → 无 cancel 动作。
  return MsgSelectChain(forced: forced, chains: chains);
}

MsgSelectCard _decodeSelectCard(BufferReader r, int player) {
  final cancelable = r.readUint8() != 0;
  final min = r.readUint8();
  final max = r.readUint8();
  final count = r.readUint8();
  final cards = <SelectAbleCard>[];
  for (var i = 0; i < count; i++) {
    r.skip(4); // code：env 只记 spec（dp_ += 4）
    final c = r.readUint8();
    final l = r.readUint8();
    final s = r.readUint8();
    final pos = r.readUint8();
    cards.add(SelectAbleCard(
      location: _agentCardLocation(c, l, s, pos, player),
      response: i,
    ));
  }
  // env 恒从空选择开始（init_multi_select(min, max, 0, specs)）。
  return MsgSelectCard(
    cancelable: cancelable,
    min: min,
    max: max,
    cards: cards,
    selected: const [],
  );
}

MsgSelectTribute _decodeTribute(BufferReader r, int player) {
  final cancelable = r.readUint8() != 0;
  final min = r.readUint8();
  final max = r.readUint8();
  final count = r.readUint8();
  final cards = <SelectTributeCard>[];
  for (var i = 0; i < count; i++) {
    r.skip(4); // code：env 只记 spec
    final c = r.readUint8();
    final l = r.readUint8();
    final s = r.readUint8();
    final releaseParam = r.readUint8();
    cards.add(SelectTributeCard(
      location: _agentCardLocation(c, l, s, 0, player),
      level: releaseParam,
      response: i,
    ));
  }
  return MsgSelectTribute(
    cancelable: cancelable,
    min: min,
    max: max,
    cards: cards,
    selected: const [],
  );
}

MsgSelectUnselectCard _decodeUnselectCard(BufferReader r, int player) {
  final finishable = r.readUint8() != 0;
  final cancelable = r.readUint8() != 0;
  final min = r.readUint8();
  final max = r.readUint8();

  List<SelectUnselectCard> group(int baseResponse) {
    final count = r.readUint8();
    return [
      for (var i = 0; i < count; i++) ...() {
        r.skip(4); // code：env 只记 spec
        final c = r.readUint8();
        final l = r.readUint8();
        final s = r.readUint8();
        final pos = r.readUint8();
        return [
          SelectUnselectCard(
            location: _agentCardLocation(c, l, s, pos, player),
            response: baseResponse + i,
          )
        ];
      }()
    ];
  }

  // 线序：可选列表在前、已选列表在后；env 只对可选列表建动作，
  // 已选列表跳过（"unselect not allowed"）。
  final selectable = group(0);
  final selected = group(selectable.length);
  return MsgSelectUnselectCard(
    finishable: finishable,
    cancelable: cancelable,
    min: min,
    max: max,
    selectedCards: selected,
    selectableCards: selectable,
  );
}

MsgSelectSum _decodeSum(BufferReader r) {
  // 线格式：[mode u8][player u8][val u32][min u8][max u8]
  //         [mustCount u8] must×(code u32, c,l,s, param u32)
  //         [selCount u8] sel×(code u32, c,l,s, param u32)
  final mode = r.readUint8();
  final player = r.readUint8();
  final levelSum = r.readInt32();
  final min = r.readUint8();
  final max = r.readUint8();

  List<SelectSumCard> readCards() {
    final count = r.readUint8();
    return [
      for (var i = 0; i < count; i++) ...() {
        r.skip(4); // code：env 只记 spec
        final c = r.readUint8();
        final l = r.readUint8();
        final s = r.readUint8();
        final param = r.readUint32();
        return [
          SelectSumCard(
            location: _agentCardLocation(c, l, s, 0, player),
            level1: param & 0xffff,
            level2: param >> 16,
            response: i,
          )
        ];
      }()
    ];
  }

  final mustCards = readCards();
  final cards = readCards();
  return MsgSelectSum(
    overflow: mode != 0,
    levelSum: levelSum,
    min: min,
    max: max,
    cards: cards,
    mustCards: mustCards,
    selected: const [],
  );
}

MsgSelectPosition _decodePosition(BufferReader r) {
  final code = r.readUint32();
  final mask = r.readUint8();
  // env 按位序枚举：0x1 faceup_attack, 0x2 facedown_attack,
  // 0x4 faceup_defense, 0x8 facedown_defense。
  final positions = [
    for (final bit in const [0x1, 0x2, 0x4, 0x8])
      if (mask & bit != 0) positionFromRaw(bit),
  ];
  return MsgSelectPosition(code: code, positions: positions);
}

MsgSelectEffectYn _decodeEffectYn(BufferReader r, int player) {
  final code = r.readUint32();
  final c = r.readUint8();
  final l = r.readUint8();
  final s = r.readUint8();
  final pos = r.readUint8();
  final desc = r.readUint32();
  return MsgSelectEffectYn(
    code: code,
    location: _agentCardLocation(c, l, s, pos, player),
    effectDescription: desc,
  );
}

MsgSelectYesNo _decodeYesNo(BufferReader r) =>
    MsgSelectYesNo(effectDescription: r.readUint32());

MsgSelectOption _decodeOption(BufferReader r) {
  final count = r.readUint8();
  return MsgSelectOption(options: [
    for (var i = 0; i < count; i++)
      Option(code: r.readUint32(), response: i),
  ]);
}

ActionMsgData _decodePlace(BufferReader r, int player,
    {required bool disfield}) {
  var count = r.readUint8();
  if (count == 0) count = 1; // env：count==0 按 1 处理
  final flag = r.readUint32();
  if (count != 1) {
    throw NotSupportedException('select_place/disfield count=$count != 1');
  }
  final places = _flagToUsablePlaces(flag, player);
  return disfield
      ? MsgSelectDisfield(count: count, places: places)
      : MsgSelectPlace(count: count, places: places);
}

/// env `flag_to_usable_places`（reverse=false 语义）：flag 第 j 字节的
/// 第 i 位为 0 表示该格可用。j=0 我方怪兽区、j=1 我方魔陷区、
/// j=2 对方怪兽区、j=3 对方魔陷区（均相对应答玩家）。
List<Place> _flagToUsablePlaces(int flag, int player) {
  final zones = <(Location, int)>[
    (Location.mzone, player),
    (Location.szone, player),
    (Location.mzone, 1 - player),
    (Location.szone, 1 - player),
  ];
  final places = <Place>[];
  for (var j = 0; j < 4; j++) {
    final value = (flag >> (8 * j)) & 0xff;
    final (location, controller) = zones[j];
    for (var i = 0; i < 8; i++) {
      if (value & (1 << i) == 0) {
        places.add(Place(
          controller: _relController(controller, player),
          location: location,
          sequence: i,
        ));
      }
    }
  }
  return places;
}

MsgAnnounceAttrib _decodeAnnounceAttrib(BufferReader r) {
  // 本 fork 线格式：[player][count u8][available u32] —— 没有 min 字节。
  final count = r.readUint8();
  if (count != 1) {
    throw NotSupportedException('announce_attrib count=$count != 1');
  }
  final available = r.readUint32();
  return MsgAnnounceAttrib(
    count: count,
    attributes: [
      for (var bit = 0; bit < 7; bit++)
        if (available & (1 << bit) != 0)
          AnnounceAttrib(
            attribute: attributeFromRaw(1 << bit),
            response: 1 << bit, // 应答 = 原始属性位
          ),
    ],
  );
}

MsgAnnounceNumber _decodeAnnounceNumber(BufferReader r) {
  final count = r.readUint8();
  final numbers = <AnnounceNumber>[];
  for (var i = 0; i < count; i++) {
    final value = r.readUint32();
    if (value < 1 || value > 12) {
      throw NotSupportedException('announce_number value $value outside 1..12');
    }
    numbers.add(AnnounceNumber(number: value, response: i));
  }
  return MsgAnnounceNumber(count: count, numbers: numbers);
}
