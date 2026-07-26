import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Shuffle set card notification.
class MsgShuffleSetCard {
  final int zone;
  final int count;
  final List<CardLocation> fromLocations;
  final List<CardLocation> overlayLocations;

  const MsgShuffleSetCard({
    required this.zone,
    required this.count,
    required this.fromLocations,
    required this.overlayLocations,
  });

  int get funcId => MSG_SHUFFLE_SET_CARD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(zone);
    w.writeUint8(count);
    for (final loc in fromLocations) {
      w.writeCardLocation(loc);
    }
    for (final loc in overlayLocations) {
      w.writeCardLocation(loc);
    }
    return w.toBytes();
  }

  static MsgShuffleSetCard decode(Uint8List data) {
    final r = BufferReader(data);
    final zone = r.readUint8();
    final count = r.readUint8();
    final fromLocations = <CardLocation>[];
    for (int i = 0; i < count; i++) {
      fromLocations.add(r.readCardLocation());
    }
    final overlayLocations = <CardLocation>[];
    for (int i = 0; i < count; i++) {
      overlayLocations.add(r.readCardLocation());
    }
    return MsgShuffleSetCard(
      zone: zone,
      count: count,
      fromLocations: fromLocations,
      overlayLocations: overlayLocations,
    );
  }

  @override
  String toString() =>
      'MsgShuffleSetCard(zone:$zone count:$count fromLocations:$fromLocations overlayLocations:$overlayLocations)';
}
