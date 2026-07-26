import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Select sum interaction (complex nested format, store raw data for now).
class MsgSelectSum {
  final int player;
  final Uint8List rawData;

  const MsgSelectSum({required this.player, required this.rawData});

  int get funcId => MSG_SELECT_SUM;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeBytes(rawData);
    return w.toBytes();
  }

  static MsgSelectSum decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSelectSum(
      player: r.readUint8(),
      rawData: r.readBytes(data.length - 1),
    );
  }

  @override
  String toString() =>
      'MsgSelectSum(player:$player rawDataLen:${rawData.length})';
}
