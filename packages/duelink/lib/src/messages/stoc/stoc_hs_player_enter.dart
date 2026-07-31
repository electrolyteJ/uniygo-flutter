import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// STOC_HS_PLAYER_ENTER (32)
///
/// 有新玩家进入等待房间。
///
/// 协议格式:
/// - name: [unsigned short; 20] — 玩家昵称（固定 40 字节 UTF-16 LE）
/// - pos:  uint8 — 玩家位置（0-3）
///
/// 参考 neos-ts 的 stocHsPlayerEnter.ts 定义。
class StocHsPlayerEnter {
  final String name;
  final int pos;
  const StocHsPlayerEnter({required this.name, required this.pos});
  int get protoId => STOC_HS_PLAYER_ENTER;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUtf16Fixed(name);
    w.writeUint8(pos & 0x3);
    return w.toBytes();
  }

  static StocHsPlayerEnter decode(Uint8List data) {
    final r = BufferReader(data);
    final name = r.readUtf16(maxBytes: 40);
    final pos = r.readUint8() & 0x3;
    return StocHsPlayerEnter(name: name, pos: pos);
  }

  @override
  String toString() => 'StocHsPlayerEnter($name pos:$pos)';
}
