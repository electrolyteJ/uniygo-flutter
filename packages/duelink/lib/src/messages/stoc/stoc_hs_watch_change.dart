import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class StocHsWatchChange {
  final int count;
  const StocHsWatchChange({required this.count});
  int get protoId => STOC_HS_WATCH_CHANGE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint16(count);
    return w.toBytes();
  }

  static StocHsWatchChange decode(Uint8List data) {
    final r = BufferReader(data);
    return StocHsWatchChange(count: r.readUint16());
  }

  @override
  String toString() => 'StocHsWatchChange($count)';
}
