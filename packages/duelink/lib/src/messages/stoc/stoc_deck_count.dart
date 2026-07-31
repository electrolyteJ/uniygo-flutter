import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// STOC_DECK_COUNT (9)
///
/// 双方卡组数量信息。
///
/// 协议格式:
/// - meMain:  int16 — 我方主卡组数量
/// - meExtra: int16 — 我方额外卡组数量
/// - meSide:  int16 — 我方副卡组数量
/// - opMain:  int16 — 对方主卡组数量
/// - opExtra: int16 — 对方额外卡组数量
/// - opSide:  int16 — 对方副卡组数量
///
/// 参考 neos-ts 的 stocDeckCount.ts 定义。
class StocDeckCount {
  final int meMain;
  final int meExtra;
  final int meSide;
  final int opMain;
  final int opExtra;
  final int opSide;
  const StocDeckCount({
    required this.meMain,
    required this.meExtra,
    required this.meSide,
    required this.opMain,
    required this.opExtra,
    required this.opSide,
  });
  int get protoId => STOC_DECK_COUNT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeInt16(meMain);
    w.writeInt16(meExtra);
    w.writeInt16(meSide);
    w.writeInt16(opMain);
    w.writeInt16(opExtra);
    w.writeInt16(opSide);
    return w.toBytes();
  }

  static StocDeckCount decode(Uint8List data) {
    final r = BufferReader(data);
    return StocDeckCount(
      meMain: r.readInt16(),
      meExtra: r.readInt16(),
      meSide: r.readInt16(),
      opMain: r.readInt16(),
      opExtra: r.readInt16(),
      opSide: r.readInt16(),
    );
  }

  @override
  String toString() =>
      'StocDeckCount(meMain:$meMain meExtra:$meExtra meSide:$meSide opMain:$opMain opExtra:$opExtra opSide:$opSide)';
}
