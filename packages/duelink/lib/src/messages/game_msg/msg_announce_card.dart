import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_ANNOUNCE_CARD (0x8E) — 宣言卡名交互。
class MsgAnnounceCard {
  final int player;
  final int count;
  final List<int> codes;

  const MsgAnnounceCard({
    required this.player,
    required this.count,
    required this.codes,
  });

  int get funcId => MSG_ANNOUNCE_CARD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    for (final c in codes) {
      w.writeUint32(c);
    }
    return w.toBytes();
  }

  static MsgAnnounceCard decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final count = r.readUint8();
    final codes = <int>[];
    for (int i = 0; i < count; i++) {
      codes.add(r.readUint32());
    }
    return MsgAnnounceCard(player: player, count: count, codes: codes);
  }

  @override
  String toString() =>
      'MsgAnnounceCard(player:$player count:$count codes:$codes)';
}
