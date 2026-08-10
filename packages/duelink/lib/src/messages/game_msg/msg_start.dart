import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_START (0x04) — 对局开始通知。
///
/// 原始协议会给出当前视角身份、双方 LP、主卡组数量和额外卡组数量。
/// 部分新协议版本会在 `playerType` 后额外带一个 `masterRule` 字节。
///
/// `playerType` 的高位包含观战信息，低 4 位是**当前视角的引擎玩家编号**
/// （0 = 引擎 0 号玩家 = 惯例先攻方，1 = 引擎 1 号玩家 = 惯例后攻方）；
/// 这里既保留原始值，也提供安全 getter，避免上层再写 `playerType & 0x0F`
/// 这类位运算。一般业务判断应优先使用 [isObserver] / [isPlayer0] /
/// [isPlayer1]；只有需要记录或透传完整协议位图时，才读取 [rawPlayerType]。
class MsgStart {
  final int playerType;
  final int? masterRule;
  final int life1;
  final int life2;
  final int deckSize1;
  final int extraSize1;
  final int deckSize2;
  final int extraSize2;

  const MsgStart({
    required this.playerType,
    this.masterRule,
    required this.life1,
    required this.life2,
    required this.deckSize1,
    required this.extraSize1,
    required this.deckSize2,
    required this.extraSize2,
  });

  /// 原始协议中的 playerType 位图，保留完整字节语义。
  int get rawPlayerType => playerType;

  /// 去掉高位扩展标记后的低 4 位引擎玩家编号（0/1，7 表示观战）。
  int get playerTypeBits => playerType & 0x0F;

  /// 当前视角是否为观战者。
  bool get isObserver => (playerType & 0x10) != 0 || playerTypeBits == 0x07;

  /// 当前视角是否为引擎 0 号玩家（惯例为先攻方）。
  bool get isPlayer0 => playerTypeBits == 0x00;

  /// 当前视角是否为引擎 1 号玩家（惯例为后攻方）。
  bool get isPlayer1 => playerTypeBits == 0x01;

  int get funcId => MSG_START;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(playerType);
    if (masterRule != null) {
      w.writeUint8(masterRule!);
    }
    w.writeInt32(life1);
    w.writeInt32(life2);
    w.writeInt16(deckSize1);
    w.writeInt16(extraSize1);
    w.writeInt16(deckSize2);
    w.writeInt16(extraSize2);
    return w.toBytes();
  }

  static MsgStart decode(Uint8List data) {
    final r = BufferReader(data);
    final playerType = r.readUint8();
    final int? masterRule;
    if (data.length >= 18) {
      masterRule = r.readUint8();
    } else {
      masterRule = null;
    }
    return MsgStart(
      playerType: playerType,
      masterRule: masterRule,
      life1: r.readInt32(),
      life2: r.readInt32(),
      deckSize1: r.readInt16(),
      extraSize1: r.readInt16(),
      deckSize2: r.readInt16(),
      extraSize2: r.readInt16(),
    );
  }

  @override
  String toString() =>
      'MsgStart(playerType:$playerType masterRule:$masterRule life1:$life1 life2:$life2 deckSize1:$deckSize1 extraSize1:$extraSize1 deckSize2:$deckSize2 extraSize2:$extraSize2)';
}
