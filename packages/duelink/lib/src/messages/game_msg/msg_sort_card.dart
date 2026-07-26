import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Sort cards interaction (player + count + [code + shortLocation; count]).
class MsgSortCard {
  final int player;
  final int count;
  final List<int> codes;
  final List<CardShortLocation> locations;

  const MsgSortCard({
    required this.player,
    required this.count,
    required this.codes,
    required this.locations,
  });

  int get funcId => MSG_SORT_CARD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    for (int i = 0; i < count; i++) {
      w.writeUint32(codes[i]);
      w.writeCardShortLocation(locations[i]);
    }
    return w.toBytes();
  }

  static MsgSortCard decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final count = r.readUint8();
    final codes = <int>[];
    final locations = <CardShortLocation>[];
    for (int i = 0; i < count; i++) {
      codes.add(r.readUint32());
      locations.add(r.readCardShortLocation());
    }
    return MsgSortCard(
      player: player,
      count: count,
      codes: codes,
      locations: locations,
    );
  }

  @override
  String toString() =>
      'MsgSortCard(player:$player count:$count codes:$codes locations:$locations)';
}
