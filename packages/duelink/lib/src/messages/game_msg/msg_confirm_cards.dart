import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_CONFIRM_CARDS (0x1E) — 确认卡牌交互
///
/// 服务端展示一组卡牌让客户端确认查看（例如手牌确认/卡组检索展示）。
///
/// 有线格式 (变长):
/// | 偏移 | 大小  | 类型         | 说明                |
/// |------|-------|--------------|---------------------|
/// | 0x00 | 1     | uint8        | 玩家 (0 或 1)       |
/// | 0x01 | 1     | uint8        | 卡片数量 count       |
/// | 0x02 | 7 * n | CardInfo[n]  | 每张 card 的完整信息 |
///
/// 参考 neos-ts 的 confirmCards.ts 定义。
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
