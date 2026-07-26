import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Deck shuffle notification.
class MsgShuffleDeck {
  final int player;

  const MsgShuffleDeck({required this.player});

  int get funcId => MSG_SHUFFLE_DECK;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    return w.toBytes();
  }

  static MsgShuffleDeck decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgShuffleDeck(player: r.readUint8());
  }

  @override
  String toString() => 'MsgShuffleDeck(player:$player)';
}
