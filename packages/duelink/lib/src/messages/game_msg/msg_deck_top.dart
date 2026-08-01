import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_DECK_TOP (0x26) — 更新卡组顶部卡片信息。
class MsgDeckTop {
  final int player;
  final int sequence;
  final int code;
  final bool isReversed;

  const MsgDeckTop({
    required this.player,
    required this.sequence,
    required this.code,
    required this.isReversed,
  });

  int get funcId => MSG_DECK_TOP;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(sequence);
    final value = isReversed ? (code | 0x80000000) : code;
    w.writeUint32(value);
    return w.toBytes();
  }

  static MsgDeckTop decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final sequence = r.readUint8();
    final rawCode = r.readUint32();
    return MsgDeckTop(
      player: player,
      sequence: sequence,
      code: rawCode & 0x7fffffff,
      isReversed: (rawCode & 0x80000000) != 0,
    );
  }

  @override
  String toString() =>
      'MsgDeckTop(player:$player sequence:$sequence code:$code isReversed:$isReversed)';
}
