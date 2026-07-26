import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Select battle command interaction (store raw data for now).
class MsgSelectBattleCmd {
  final int player;
  final Uint8List rawData;

  const MsgSelectBattleCmd({required this.player, required this.rawData});

  int get funcId => MSG_SELECT_BATTLE_CMD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeBytes(rawData);
    return w.toBytes();
  }

  static MsgSelectBattleCmd decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSelectBattleCmd(
      player: r.readUint8(),
      rawData: r.readBytes(data.length - 1),
    );
  }

  @override
  String toString() =>
      'MsgSelectBattleCmd(player:$player rawDataLen:${rawData.length})';
}
