import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Swap grave and deck notification.
class MsgSwapGraveDeck {
  final int player;

  const MsgSwapGraveDeck({required this.player});

  int get funcId => MSG_SWAP_GRAVE_DECK;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    return w.toBytes();
  }

  static MsgSwapGraveDeck decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSwapGraveDeck(player: r.readUint8());
  }

  @override
  String toString() => 'MsgSwapGraveDeck(player:$player)';
}
