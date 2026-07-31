import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// CTOS_HAND_RESULT (3)
///
/// 告知服务端当前玩家的猜拳选择。
///
/// 协议格式:
/// - hand: unsigned char — 玩家的猜拳选择
///   - 1 = SCISSORS（剪刀）
///   - 2 = ROCK（石头）
///   - 3 = PAPER（布）
///
/// 参考 neos-ts 的 ctosHandResult.ts 定义。
class CtosHandResult {
  /// 1=SCISSORS, 2=ROCK, 3=PAPER
  final int hand;
  const CtosHandResult({required this.hand});
  int get protoId => CTOS_HAND_RESULT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(hand);
    return w.toBytes();
  }

  static CtosHandResult decode(Uint8List data) {
    final r = BufferReader(data);
    return CtosHandResult(hand: r.readUint8());
  }

  @override
  String toString() => 'CtosHandResult($hand)';
}
