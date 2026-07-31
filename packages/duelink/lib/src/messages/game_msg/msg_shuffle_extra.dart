import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SHUFFLE_EXTRA (0x27) — 洗额外卡组通知
///
/// 通知客户端额外卡组被洗牌，携带洗牌后的卡牌 code 列表。
///
/// 有线格式 (变长):
/// | 偏移 | 大小  | 类型     | 说明               |
/// |------|-------|----------|--------------------|
/// | 0x00 | 1     | uint8    | 玩家 (0 或 1)      |
/// | 0x01 | 1     | uint8    | 卡牌数量 count      |
/// | 0x02 | 4 * n | uint32[] | 洗牌后的卡牌 code 列表 |
///
/// 参考 neos-ts 的 shuffleExtra.ts 定义。
class MsgShuffleExtra {
  final int player;
  final int count;
  final List<int> cards;

  const MsgShuffleExtra({
    required this.player,
    required this.count,
    required this.cards,
  });

  int get funcId => MSG_SHUFFLE_EXTRA;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    for (final c in cards) {
      w.writeUint32(c);
    }
    return w.toBytes();
  }

  static MsgShuffleExtra decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final count = r.readUint8();
    final cards = <int>[];
    for (int i = 0; i < count; i++) {
      cards.add(r.readUint32());
    }
    return MsgShuffleExtra(player: player, count: count, cards: cards);
  }

  @override
  String toString() => 'MsgShuffleExtra(player:$player count:$count cards:$cards)';
}
