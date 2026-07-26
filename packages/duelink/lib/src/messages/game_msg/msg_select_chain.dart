import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Select chain interaction (complex format, store raw data for now).
class MsgSelectChain {
  final int player;
  final Uint8List rawData;

  const MsgSelectChain({required this.player, required this.rawData});

  int get funcId => MSG_SELECT_CHAIN;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeBytes(rawData);
    return w.toBytes();
  }

  static MsgSelectChain decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSelectChain(
      player: r.readUint8(),
      rawData: r.readBytes(data.length - 1),
    );
  }

  @override
  String toString() =>
      'MsgSelectChain(player:$player rawDataLen:${rawData.length})';
}
