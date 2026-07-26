import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Position change notification (CardInfo 7 bytes + prePosition + curPosition).
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
