import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Select unselect card interaction (store raw data for now).
class MsgSelectUnselectCard {
  final int player;
  final Uint8List rawData;

  const MsgSelectUnselectCard({required this.player, required this.rawData});

  int get funcId => MSG_SELECT_UNSELECT_CARD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeBytes(rawData);
    return w.toBytes();
  }

  static MsgSelectUnselectCard decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSelectUnselectCard(
      player: r.readUint8(),
      rawData: r.readBytes(data.length - 1),
    );
  }

  @override
  String toString() =>
      'MsgSelectUnselectCard(player:$player rawDataLen:${rawData.length})';
}
