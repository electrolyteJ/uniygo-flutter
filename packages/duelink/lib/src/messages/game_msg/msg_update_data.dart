import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Update data notification (flags-driven, store raw data for now).
class MsgUpdateData {
  final int player;
  final int zone;
  final Uint8List rawData;

  const MsgUpdateData({
    required this.player,
    required this.zone,
    required this.rawData,
  });

  int get funcId => MSG_UPDATE_DATA;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(zone);
    w.writeBytes(rawData);
    return w.toBytes();
  }

  static MsgUpdateData decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgUpdateData(
      player: r.readUint8(),
      zone: r.readUint8(),
      rawData: r.readBytes(data.length - 2),
    );
  }

  @override
  String toString() =>
      'MsgUpdateData(player:$player zone:$zone rawDataLen:${rawData.length})';
}
