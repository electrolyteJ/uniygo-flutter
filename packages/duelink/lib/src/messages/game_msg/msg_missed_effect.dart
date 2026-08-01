import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_MISSED_EFFECT (0x78) — 错过时点的效果提示。
class MsgMissedEffect {
  final int player;
  final int code;

  const MsgMissedEffect({required this.player, required this.code});

  int get funcId => MSG_MISSED_EFFECT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint32(code);
    return w.toBytes();
  }

  static MsgMissedEffect decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgMissedEffect(player: r.readUint8(), code: r.readUint32());
  }

  @override
  String toString() => 'MsgMissedEffect(player:$player code:$code)';
}
