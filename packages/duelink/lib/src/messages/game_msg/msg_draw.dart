import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Draw cards notification.
class MsgDraw {
  final int player;
  final int count;
  final List<int> cards;

  const MsgDraw({
    required this.player,
    required this.count,
    required this.cards,
  });

  int get funcId => MSG_DRAW;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    for (final c in cards) {
      w.writeUint32(c);
    }
    return w.toBytes();
  }

  static MsgDraw decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final count = r.readUint8();
    final cards = <int>[];
    for (int i = 0; i < count; i++) {
      cards.add(r.readUint32());
    }
    return MsgDraw(player: player, count: count, cards: cards);
  }

  @override
  String toString() => 'MsgDraw(player:$player count:$count cards:$cards)';
}
