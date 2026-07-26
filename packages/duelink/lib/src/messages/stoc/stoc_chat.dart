import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class StocChat {
  final int player;
  final String message;
  const StocChat({required this.player, required this.message});
  int get protoId => STOC_CHAT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint16(player);
    w.writeUtf16Var(message);
    return w.toBytes();
  }

  static StocChat decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint16();
    final message = r.readUtf16Var();
    return StocChat(player: player, message: message);
  }

  @override
  String toString() => 'StocChat(player:$player "$message")';
}
