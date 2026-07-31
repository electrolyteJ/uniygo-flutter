import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';
import '../../model/room_options.dart';

/// STOC_JOIN_GAME (18)
///
/// 服务端告知客户端已成功加入房间，并携带房间配置信息。
///
/// 协议格式:
/// - lflist:       uint32 — 禁限卡表 ID
/// - rule:         uint8  — 规则版本
/// - mode:         uint8  — 房间模式 (0=single, 1=match, 2=tag)
/// - duelRule:     uint8  — 决斗规则 (3=MR3, 4=MR4, 其他=MR2020+)
/// - noCheckDeck:  uint8  — 是否跳过卡组检查
/// - noShuffleDeck:uint8  — 是否跳过洗牌
/// - (padding):    3 bytes
/// - startLp:      int32  — 初始 LP
/// - startHand:    uint8  — 起手手牌数
/// - drawCount:    uint8  — 每回合抽牌数
/// - timeLimit:    uint16 — 时间限制（秒）
///
/// 参考 neos-ts 的 stocJoinGame.ts 定义。

class StocJoinGame {
  final int lflist;
  final int rule;
  final RoomMode mode;
  final DuelRule duelRule;
  final bool noCheckDeck;
  final bool noShuffleDeck;
  final int startLp;
  final int startHand;
  final int drawCount;
  final int timeLimit;

  const StocJoinGame({
    this.lflist = 0,
    this.rule = 0,
    this.mode = RoomMode.match,
    this.duelRule = DuelRule.mr2020,
    this.noCheckDeck = false,
    this.noShuffleDeck = false,
    this.startLp = 8000,
    this.startHand = 5,
    this.drawCount = 1,
    this.timeLimit = 180,
  });

  RoomOptions toRoomOptions() => RoomOptions(
    lflist: lflist,
    rule: rule,
    mode: mode,
    duelRule: duelRule,
    noCheckDeck: noCheckDeck,
    noShuffleDeck: noShuffleDeck,
    startLp: startLp,
    startHand: startHand,
    drawCount: drawCount,
    timeLimit: timeLimit,
  );

  int get protoId => STOC_JOIN_GAME;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint32(lflist);
    w.writeUint8(rule);
    w.writeUint8(mode.value);
    w.writeUint8(duelRule.value);
    w.writeUint8(noCheckDeck ? 1 : 0);
    w.writeUint8(noShuffleDeck ? 1 : 0);
    w.writeUint8(0);
    w.writeUint8(0);
    w.writeUint8(0);
    w.writeInt32(startLp);
    w.writeUint8(startHand);
    w.writeUint8(drawCount);
    w.writeUint16(timeLimit);
    return w.toBytes();
  }

  static StocJoinGame decode(Uint8List data) {
    if (data.isEmpty) return const StocJoinGame();
    final r = BufferReader(data);
    return StocJoinGame(
      lflist: r.readUint32(),
      rule: r.readUint8(),
      mode: _readMode(r.readUint8()),
      duelRule: _readDuelRule(r.readUint8()),
      noCheckDeck: r.readUint8() != 0,
      noShuffleDeck: r.readUint8() != 0,
      startLp: _skipThenReadLp(r),
      startHand: r.readUint8(),
      drawCount: r.readUint8(),
      timeLimit: r.readUint16(),
    );
  }

  static int _skipThenReadLp(BufferReader r) {
    r.skip(3);
    return r.readInt32();
  }

  static RoomMode _readMode(int v) {
    switch (v) {
      case 1: return RoomMode.match;
      case 2: return RoomMode.tag;
      default: return RoomMode.single;
    }
  }

  static DuelRule _readDuelRule(int v) {
    switch (v) {
      case 3: return DuelRule.mr3;
      case 4: return DuelRule.mr4;
      default: return DuelRule.mr2020;
    }
  }

  @override
  String toString() =>
      'StocJoinGame(lp:$startLp hand:$startHand draw:$drawCount rule:$rule mode:${mode.value} duelRule:${duelRule.value})';
}
