import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_RANDOM_SELECTED (0x51) — 随机选中的卡牌列表。
class MsgRandomSelected {
  final int player;
  final int count;
  final List<CardLocation> cards;

  const MsgRandomSelected({
    required this.player,
    required this.count,
    required this.cards,
  });

  int get funcId => MSG_RANDOM_SELECTED;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    for (final card in cards) {
      w.writeCardLocation(card);
    }
    return w.toBytes();
  }

  static MsgRandomSelected decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final count = r.readUint8();
    final cards = <CardLocation>[];
    for (var i = 0; i < count; i++) {
      cards.add(r.readCardLocation());
    }
    return MsgRandomSelected(player: player, count: count, cards: cards);
  }

  @override
  String toString() =>
      'MsgRandomSelected(player:$player count:$count cards:$cards)';
}
