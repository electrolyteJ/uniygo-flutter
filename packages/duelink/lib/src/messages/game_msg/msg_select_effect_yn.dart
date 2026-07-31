import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SELECT_EFFECTYN (0x0C) — 选择是否发动效果交互
///
/// 服务端询问玩家是否发动某张卡牌的效果。
///
/// 有线格式 (13 字节):
/// | 偏移 | 大小 | 类型         | 说明                     |
/// |------|------|--------------|--------------------------|
/// | 0x00 | 1    | uint8        | 玩家 (0 或 1)            |
/// | 0x01 | 4    | uint32       | 卡牌 code                |
/// | 0x05 | 4    | CardLocation | 卡牌位置                  |
/// | 0x09 | 4    | uint32       | 效果描述 ID              |
///
/// 参考 neos-ts 的 selectEffectYn.ts 定义。
class MsgSelectEffectYn {
  final int player;
  final int code;
  final CardLocation location;
  final int effectDescription;

  const MsgSelectEffectYn({
    required this.player,
    required this.code,
    required this.location,
    required this.effectDescription,
  });

  int get funcId => MSG_SELECT_EFFECTYN;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint32(code);
    w.writeCardLocation(location);
    w.writeUint32(effectDescription);
    return w.toBytes();
  }

  static MsgSelectEffectYn decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSelectEffectYn(
      player: r.readUint8(),
      code: r.readUint32(),
      location: r.readCardLocation(),
      effectDescription: r.readUint32(),
    );
  }

  @override
  String toString() =>
      'MsgSelectEffectYn(player:$player code:$code location:$location effectDescription:$effectDescription)';
}
