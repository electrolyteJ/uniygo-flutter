import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_POS_CHANGE (0x35) — 表示形式变化通知
///
/// 通知客户端卡牌的表示形式发生了变化。
///
/// 有线格式 (9 字节):
/// | 偏移 | 大小 | 类型     | 说明                 |
/// |------|------|----------|----------------------|
/// | 0x00 | 7    | CardInfo | 卡牌当前信息          |
/// | 0x07 | 1    | uint8    | 变化前的表示形式       |
/// | 0x08 | 1    | uint8    | 变化后的表示形式       |
///
/// 参考 neos-ts 的 posChange.ts 定义。
class MsgPosChange {
  final CardInfo cardInfo;
  final int prePosition;
  final int curPosition;

  const MsgPosChange({
    required this.cardInfo,
    required this.prePosition,
    required this.curPosition,
  });

  int get funcId => MSG_POS_CHANGE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeCardInfo(cardInfo);
    w.writeUint8(prePosition);
    w.writeUint8(curPosition);
    return w.toBytes();
  }

  static MsgPosChange decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgPosChange(
      cardInfo: r.readCardInfo(),
      prePosition: r.readUint8(),
      curPosition: r.readUint8(),
    );
  }

  @override
  String toString() =>
      'MsgPosChange(cardInfo:$cardInfo prePosition:$prePosition curPosition:$curPosition)';
}
