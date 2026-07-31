import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SORT_CARD (0x19) — 排卡序交互
///
/// 服务端要求玩家对一组卡牌进行排序（例如墓地排序效果）。
///
/// 有线格式 (变长):
/// | 偏移 | 大小    | 类型                    | 说明               |
/// |------|---------|-------------------------|--------------------|
/// | 0x00 | 1       | uint8                   | 玩家 (0 或 1)      |
/// | 0x01 | 1       | uint8                   | 卡牌数量 count      |
/// | 0x02 | 7 * n   | code(u32) + shortLocation(3) | 每张卡: code + 短位置 |
///
/// 参考 neos-ts 的 sortCard.ts 定义。
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
