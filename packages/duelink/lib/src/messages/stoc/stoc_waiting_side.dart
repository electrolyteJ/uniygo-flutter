import 'dart:typed_data';
import '../../constants.dart';

/// STOC_WAITING_SIDE (8)
///
/// 等待对手换备完成。
///
/// 无负载数据。
///
/// 参考 neos-ts 的 stocWaitingSide.ts 定义。
class StocWaitingSide {
  const StocWaitingSide();
  int get protoId => STOC_WAITING_SIDE;
  Uint8List encode() => Uint8List(0);
  static StocWaitingSide decode(Uint8List data) => const StocWaitingSide();
  @override
  String toString() => 'StocWaitingSide';
}
