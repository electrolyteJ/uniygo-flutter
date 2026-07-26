import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Rock-paper-scissors request.
class MsgRockPaperScissors {
  final int player;

  const MsgRockPaperScissors({required this.player});

  int get funcId => MSG_ROCK_PAPER_SCISSORS;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    return w.toBytes();
  }

  static MsgRockPaperScissors decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgRockPaperScissors(player: r.readUint8());
  }

  @override
  String toString() => 'MsgRockPaperScissors(player:$player)';
}
