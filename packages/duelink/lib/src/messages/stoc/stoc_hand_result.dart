import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// STOC_HAND_RESULT (5)
///
/// 猜拳结果通知。
///
/// 协议格式:
/// - meResult: uint8 — 我方的猜拳选择 (1=SCISSORS, 2=ROCK, 3=PAPER)
/// - opResult: uint8 — 对方的猜拳选择
///
/// 参考 neos-ts 的 stocHandResult.ts 定义。
class StocHandResult {
  final int meResult;
  final int opResult;
  const StocHandResult({required this.meResult, required this.opResult});
  int get protoId => STOC_HAND_RESULT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(meResult);
    w.writeUint8(opResult);
    return w.toBytes();
  }

  static StocHandResult decode(Uint8List data) {
    final r = BufferReader(data);
    return StocHandResult(
      meResult: r.readUint8(),
      opResult: r.readUint8(),
    );
  }

  @override
  String toString() => 'StocHandResult(me:$meResult op:$opResult)';
}
