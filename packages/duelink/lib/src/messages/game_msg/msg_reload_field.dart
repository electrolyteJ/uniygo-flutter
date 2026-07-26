import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Reload field notification (complex per-player data). Stores raw bytes.
class MsgReloadField {
  final int duelRule;
  final Uint8List rawData;

  const MsgReloadField({required this.duelRule, required this.rawData});

  int get funcId => MSG_RELOAD_FIELD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(duelRule);
    w.writeBytes(rawData);
    return w.toBytes();
  }

  static MsgReloadField decode(Uint8List data) {
    if (data.isEmpty) return MsgReloadField(duelRule: 0, rawData: Uint8List(0));
    final r = BufferReader(data);
    final duelRule = r.readUint8();
    return MsgReloadField(
      duelRule: duelRule,
      rawData: r.readBytes(data.length - 1),
    );
  }

  @override
  String toString() =>
      'MsgReloadField(duelRule:$duelRule rawDataLen:${rawData.length})';
}
