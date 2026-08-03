import 'dart:typed_data';
import '../protocol/buffer_io.dart';

/// 决斗规则（对应 Master Rule 版本）
enum DuelRule {
  mr3(3),
  mr4(4),
  mr2020(5);

  final int value;
  const DuelRule(this.value);
  static DuelRule of(int v) {
    switch (v) {
      case 3:
        return DuelRule.mr3;
      case 4:
        return DuelRule.mr4;
      default:
        return DuelRule.mr2020;
    }
  }
}

/// 对战模式
enum RoomMode {
  single(0),
  match(1),
  tag(2);

  final int value;
  const RoomMode(this.value);

  static RoomMode of(int v) {
    switch (v) {
      case 1:
        return RoomMode.match;
      case 2:
        return RoomMode.tag;
      default:
        return RoomMode.single;
    }
  }
}

/// 房间创建规则参数。
///
/// 对应 ygopro 协议 HostInfo，对齐 neos-ts Options 接口。
class RoomOptions {
  /// 禁限卡表 ID（0=默认）
  final int lfTableHash;
  /// 卡片允许: 0=OCG, 1=TCG, 2=OT混, 3=自制卡, 4=专有卡禁止, 5=所有卡片
  final int rule;

  /// 对战模式
  final RoomMode mode;

  /// 大师规则版本
  final DuelRule duelRule;

  /// 不检查卡组合法性
  final bool noCheckDeck;

  /// 不切洗卡组
  final bool noShuffleDeck;

  /// 初始生命值
  final int startLp;

  /// 初始手牌数
  final int startHand;

  /// 每回合抽卡数
  final int drawCount;

  /// 每回合时间限制（秒，0=无限制）
  final int timeLimit;

  /// 40分钟自动超时 (neos-ts auto_death)
  final bool autoDeath;

  const RoomOptions({
    this.lfTableHash = 0,
    this.rule = 0,
    this.mode = RoomMode.match,
    this.duelRule = DuelRule.mr2020,
    this.noCheckDeck = false,
    this.noShuffleDeck = false,
    this.startLp = 8000,
    this.startHand = 5,
    this.drawCount = 1,
    this.timeLimit = 180,
    this.autoDeath = false,
  });

  /// 编码为 20 字节 HostInfo 结构体（用于 ygopro LAN 模式）
  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint32(lfTableHash);
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

  factory RoomOptions.decode(Uint8List data) {
    final r = BufferReader(data);
    return RoomOptions(
      lfTableHash: r.readUint32(),
      rule: r.readUint8(),
      mode: RoomMode.of(r.readUint8()),
      duelRule: DuelRule.of(r.readUint8()),
      noCheckDeck: r.readUint8() != 0,
      noShuffleDeck: r.readUint8() != 0,
      startLp: _skipThenRead(r),
      startHand: r.readUint8(),
      drawCount: r.readUint8(),
      timeLimit: r.readUint16(),
    );
  }

  static int _skipThenRead(BufferReader r) {
    r.skip(3);
    return r.readInt32();
  }


  RoomOptions copyWith({
    int? lflist,
    int? rule,
    RoomMode? mode,
    DuelRule? duelRule,
    bool? noCheckDeck,
    bool? noShuffleDeck,
    int? startLp,
    int? startHand,
    int? drawCount,
    int? timeLimit,
    bool? autoDeath,
  }) {
    return RoomOptions(
      lfTableHash: lflist ?? this.lfTableHash,
      rule: rule ?? this.rule,
      mode: mode ?? this.mode,
      duelRule: duelRule ?? this.duelRule,
      noCheckDeck: noCheckDeck ?? this.noCheckDeck,
      noShuffleDeck: noShuffleDeck ?? this.noShuffleDeck,
      startLp: startLp ?? this.startLp,
      startHand: startHand ?? this.startHand,
      drawCount: drawCount ?? this.drawCount,
      timeLimit: timeLimit ?? this.timeLimit,
      autoDeath: autoDeath ?? this.autoDeath,
    );
  }

  @override
  String toString() =>
      'RoomOptions(禁限卡表:$lfTableHash ${autoDeath ? "40分钟自动超时" : ""}  lp:$startLp hand:$startHand draw:$drawCount rule:$rule mode:${mode.value} duelRule:${duelRule.value} noCheck:$noCheckDeck noShuf:$noShuffleDeck time:$timeLimit)';
}
