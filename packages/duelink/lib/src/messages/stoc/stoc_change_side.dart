import 'dart:typed_data';
import '../../constants.dart';

/// STOC_CHANGE_SIDE (7)
///
/// 换备（换副卡组）阶段开始。
///
/// 无负载数据。
///
/// 参考 neos-ts 的 stocChangeSide.ts 定义。
class StocChangeSide {
  const StocChangeSide();
  int get protoId => STOC_CHANGE_SIDE;
  Uint8List encode() => Uint8List(0);
  static StocChangeSide decode(Uint8List data) => const StocChangeSide();
  @override
  String toString() => 'StocChangeSide';
}
