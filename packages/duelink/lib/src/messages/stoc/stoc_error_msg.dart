import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// STOC_ERROR_MSG (2)
///
/// 服务端错误消息。
///
/// 协议格式:
/// - errorType:  uint8   — 错误类型
///   - 0 = JOIN（加入失败）
///   - 1 = DECK（卡组问题）
///   - 2 = SIDE（副卡组问题）
///   - 3 = VERSION（版本不匹配）
/// - (padding):  3 bytes
/// - errorCode:  int32   — 具体错误码
///
/// 参考 neos-ts 的 stocErrorMsg.ts 定义。
class StocErrorMsg {
  final int errorType;
  final int errorCode;
  const StocErrorMsg({required this.errorType, required this.errorCode});

  StocErrorType get errorTypeValue {
    switch (errorType) {
      case 0:
        return StocErrorType.join;
      case 1:
        return StocErrorType.deck;
      case 2:
        return StocErrorType.side;
      case 3:
        return StocErrorType.version;
      default:
        return StocErrorType.unknown;
    }
  }
  int get protoId => STOC_ERROR_MSG;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(errorType);
    w.writeUint8(0); // padding byte 1
    w.writeUint8(0); // padding byte 2
    w.writeUint8(0); // padding byte 3
    w.writeInt32(errorCode);
    return w.toBytes();
  }

  static StocErrorMsg decode(Uint8List data) {
    final r = BufferReader(data);
    final errorType = r.readUint8();
    r.skip(3); // padding
    final errorCode = r.readInt32();
    return StocErrorMsg(errorType: errorType, errorCode: errorCode);
  }

  @override
  String toString() => 'StocErrorMsg(type:$errorType code:$errorCode)';
}

enum StocErrorType { unknown, join, deck, side, version }
