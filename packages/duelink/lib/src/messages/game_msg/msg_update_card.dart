import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Update card notification (player + zone + sequence + rawData).
class MsgUpdateCard {
  final int player;
  final int zone;
  final int sequence;
  final Uint8List rawData;

  const MsgUpdateCard({
    required this.player,
    required this.zone,
    required this.sequence,
    required this.rawData,
  });

  int get funcId => MSG_UPDATE_CARD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(zone);
    w.writeUint8(sequence);
    w.writeBytes(rawData);
    return w.toBytes();
  }

  static MsgUpdateCard decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgUpdateCard(
      player: r.readUint8(),
      zone: r.readUint8(),
      sequence: r.readUint8(),
      rawData: r.readBytes(data.length - 3),
    );
  }

  @override
  String toString() =>
      'MsgUpdateCard(player:$player zone:$zone sequence:$sequence rawDataLen:${rawData.length})';
}
