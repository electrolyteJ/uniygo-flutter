import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Win notification.
class MsgWin {
  final int winPlayer;
  final int reason;

  const MsgWin({required this.winPlayer, required this.reason});

  int get funcId => MSG_WIN;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(winPlayer);
    w.writeUint8(reason);
    return w.toBytes();
  }

  static MsgWin decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgWin(winPlayer: r.readUint8(), reason: r.readUint8());
  }

  @override
  String toString() => 'MsgWin(winPlayer:$winPlayer reason:$reason)';
}
