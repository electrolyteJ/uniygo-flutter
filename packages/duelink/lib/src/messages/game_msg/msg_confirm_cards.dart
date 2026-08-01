import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_CONFIRM_CARDS (0x1E) / MSG_CONFIRM_DECKTOP (0x1F) /
/// MSG_CONFIRM_EXTRATOP (0x2A) — 展示并确认卡牌信息。
///
/// 三者都会携带 `CardInfo` 列表，但原始协议格式略有差异：
/// - `MSG_CONFIRM_CARDS` 为 `player + skipPanel + count + cards`
/// - `MSG_CONFIRM_DECKTOP` / `MSG_CONFIRM_EXTRATOP` 为 `player + count + cards`
///
/// `duelink` 统一复用本类型承载，`hasPaddingByte` 用于区分是否带额外占位字节。
///
/// 有线格式 (变长):
/// | 偏移 | 大小  | 类型         | 说明                |
/// |------|-------|--------------|---------------------|
/// | 0x00 | 1     | uint8        | 玩家 (0 或 1)       |
/// | 0x01 | 1     | uint8        | `skipPanel` 或 `count` |
/// | 0x02 | 1?    | uint8        | `count`（仅 MSG_CONFIRM_CARDS） |
/// | ...  | 7 * n | CardInfo[n]  | 每张 card 的完整信息 |
///
/// 参考 neos-ts 的 confirmCards.ts 定义。
class MsgConfirmCards {
  final int player;
  final int count;
  final List<CardInfo> cards;
  final bool hasPaddingByte;

  const MsgConfirmCards({
    required this.player,
    required this.count,
    required this.cards,
    this.hasPaddingByte = true,
  });

  int get funcId => MSG_CONFIRM_CARDS;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    if (hasPaddingByte) {
      w.writeUint8(0);
    }
    w.writeUint8(count);
    for (final c in cards) {
      w.writeCardInfo(c);
    }
    return w.toBytes();
  }

  static MsgConfirmCards decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final hasPaddingByte = data.length >= 2 && (data.length - 3) % 7 == 0;
    if (hasPaddingByte) {
      r.readUint8();
    }
    final count = r.readUint8();
    final cards = <CardInfo>[];
    for (int i = 0; i < count; i++) {
      cards.add(r.readCardInfo());
    }
    return MsgConfirmCards(
      player: player,
      count: count,
      cards: cards,
      hasPaddingByte: hasPaddingByte,
    );
  }

  @override
  String toString() =>
      'MsgConfirmCards(player:$player count:$count cards:$cards)';
}
