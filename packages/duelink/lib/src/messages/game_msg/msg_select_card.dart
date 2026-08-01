import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SELECT_CARD (0x0F) — 选卡交互。
///
/// 载荷格式为 `player + cancelable + min + max + count + cards[]`，
/// 当前已完成结构化解码。
class MsgSelectCard {
  final int player;
  final int cancelable;
  final int min;
  final int max;
  final int count;
  final List<int> codes;
  final List<CardLocation> locations;

  const MsgSelectCard({
    required this.player,
    required this.cancelable,
    required this.min,
    required this.max,
    required this.count,
    required this.codes,
    required this.locations,
  });

  int get funcId => MSG_SELECT_CARD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(cancelable);
    w.writeUint8(min);
    w.writeUint8(max);
    w.writeUint8(count);
    for (int i = 0; i < count; i++) {
      w.writeUint32(codes[i]);
      w.writeCardLocation(locations[i]);
    }
    return w.toBytes();
  }

  static MsgSelectCard decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final cancelable = r.readUint8();
    final min = r.readUint8();
    final max = r.readUint8();
    final count = r.readUint8();
    final codes = <int>[];
    final locations = <CardLocation>[];
    for (int i = 0; i < count; i++) {
      codes.add(r.readUint32());
      locations.add(r.readCardLocation());
    }
    return MsgSelectCard(
      player: player,
      cancelable: cancelable,
      min: min,
      max: max,
      count: count,
      codes: codes,
      locations: locations,
    );
  }

  @override
  String toString() =>
      'MsgSelectCard(player:$player cancelable:$cancelable min:$min max:$max count:$count)';
}
