import 'dart:typed_data';
import '../../constants.dart';

/// STOC_SELECT_HAND (3)
///
/// 猜拳阶段 — 要求选择剪刀/石头/布。
///
/// 客户端应发送 CTOS_HAND_RESULT 来回复选择。
///
/// 无负载数据。
///
/// 参考 neos-ts 的 stocSelectHand.ts 定义。
class StocSelectHand {
  const StocSelectHand();
  int get protoId => STOC_SELECT_HAND;
  Uint8List encode() => Uint8List(0);
  static StocSelectHand decode(Uint8List data) => const StocSelectHand();
  @override
  String toString() => 'StocSelectHand';
}
