import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Announce number interaction (player + count + numbers[]).
class MsgAnnounceNumber {
  final int player;
  final int count;
  final List<int> numbers;

  const MsgAnnounceNumber({
    required this.player,
    required this.count,
    required this.numbers,
  });

  int get funcId => MSG_ANNOUNCE_NUMBER;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    for (final n in numbers) {
      w.writeUint32(n);
    }
    return w.toBytes();
  }

  static MsgAnnounceNumber decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final count = r.readUint8();
    final numbers = <int>[];
    for (int i = 0; i < count; i++) {
      numbers.add(r.readUint32());
    }
    return MsgAnnounceNumber(player: player, count: count, numbers: numbers);
  }

  @override
  String toString() =>
      'MsgAnnounceNumber(player:$player count:$count numbers:$numbers)';
}
