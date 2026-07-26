import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Confirm cards interaction (player + count + [CardInfo(7); count]).
class MsgConfirmCards {
  final int player;
  final int count;
  final List<CardInfo> cards;

  const MsgConfirmCards({
    required this.player,
    required this.count,
    required this.cards,
  });

  int get funcId => MSG_CONFIRM_CARDS;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    for (final c in cards) {
      w.writeCardInfo(c);
    }
    return w.toBytes();
  }

  static MsgConfirmCards decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final count = r.readUint8();
    final cards = <CardInfo>[];
    for (int i = 0; i < count; i++) {
      cards.add(r.readCardInfo());
    }
    return MsgConfirmCards(player: player, count: count, cards: cards);
  }

  @override
  String toString() =>
      'MsgConfirmCards(player:$player count:$count cards:$cards)';
}
