import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Hint from the server (hintCommand: uint8 + hintPlayer: uint8 + hintData: int32).
class MsgHint {
  final int hintCommand;
  final int hintPlayer;
  final int hintData;

  const MsgHint({
    required this.hintCommand,
    required this.hintPlayer,
    required this.hintData,
  });

  int get funcId => MSG_HINT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(hintCommand);
    w.writeUint8(hintPlayer);
    w.writeInt32(hintData);
    return w.toBytes();
  }

  static MsgHint decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgHint(
      hintCommand: r.readUint8(),
      hintPlayer: r.readUint8(),
      hintData: r.readInt32(),
    );
  }

  @override
  String toString() =>
      'MsgHint(hintCommand:$hintCommand hintPlayer:$hintPlayer hintData:$hintData)';
}
