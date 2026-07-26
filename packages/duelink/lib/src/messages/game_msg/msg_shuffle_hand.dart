import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Hand shuffle notification with card codes.
class MsgShuffleHand {
  final int player;
  final int count;
  final List<int> cards;

  const MsgShuffleHand({
    required this.player,
    required this.count,
    required this.cards,
  });

  int get funcId => MSG_SHUFFLE_HAND;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    for (final c in cards) {
      w.writeUint32(c);
    }
    return w.toBytes();
  }

  static MsgShuffleHand decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final count = r.readUint8();
    final cards = <int>[];
    for (int i = 0; i < count; i++) {
      cards.add(r.readUint32());
    }
    return MsgShuffleHand(player: player, count: count, cards: cards);
  }

  @override
  String toString() => 'MsgShuffleHand(player:$player count:$count cards:$cards)';
}
