import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_NEW_TURN (0x28) — 回合切换通知。
class MsgNewTurn {
  final int player;

  const MsgNewTurn({required this.player});

  int get funcId => MSG_NEW_TURN;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    return w.toBytes();
  }

  static MsgNewTurn decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgNewTurn(player: r.readUint8());
  }

  @override
  String toString() => 'MsgNewTurn(player:$player)';
}
