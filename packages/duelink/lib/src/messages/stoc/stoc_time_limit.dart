import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class StocTimeLimit {
  final int player;
  final int leftTime;
  const StocTimeLimit({required this.player, required this.leftTime});
  int get protoId => STOC_TIME_LIMIT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeInt8(player);
    w.writeUint8(0); // padding
    w.writeUint16(leftTime);
    return w.toBytes();
  }

  static StocTimeLimit decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readInt8();
    r.skip(1); // padding
    final leftTime = r.readUint16();
    return StocTimeLimit(player: player, leftTime: leftTime);
  }

  @override
  String toString() => 'StocTimeLimit(player:$player leftTime:$leftTime)';
}
