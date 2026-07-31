import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SHUFFLE_SET_CARD (0x24) — 盖放卡位置随机交换通知
///
/// 通知客户端盖放的多张卡牌位置进行了随机交换（例如魔术礼帽效果）。
///
/// 有线格式 (变长):
/// | 偏移 | 大小    | 类型             | 说明                    |
/// |------|---------|------------------|-------------------------|
/// | 0x00 | 1       | uint8            | 区域 zone               |
/// | 0x01 | 1       | uint8            | 卡牌数量 count          |
/// | 0x02 | 4 * n   | CardLocation[n]  | 交换前的位置列表         |
/// | ...  | 4 * n   | CardLocation[n]  | 叠放素材位置列表         |
///
/// 参考 neos-ts 的 shuffleSetCard.ts 定义。
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
