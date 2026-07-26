import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Select idle command interaction (store raw data for now).
class MsgSelectIdleCmd {
  final int player;
  final Uint8List rawData;

  const MsgSelectIdleCmd({required this.player, required this.rawData});

  int get funcId => MSG_SELECT_IDLE_CMD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeBytes(rawData);
    return w.toBytes();
  }

  static MsgSelectIdleCmd decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSelectIdleCmd(
      player: r.readUint8(),
      rawData: r.readBytes(data.length - 1),
    );
  }

  @override
  String toString() =>
      'MsgSelectIdleCmd(player:$player rawDataLen:${rawData.length})';
}
