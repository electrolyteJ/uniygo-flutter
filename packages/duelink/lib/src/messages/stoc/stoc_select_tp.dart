import 'dart:typed_data';
import '../../constants.dart';

/// STOC_SELECT_TP (4)
///
/// 猜拳胜者选择先/后攻。
///
/// 客户端应发送 CTOS_TP_RESULT 来回复选择。
///
/// 无负载数据。
///
/// 参考 neos-ts 的 stocSelectTp.ts 定义。
class StocSelectTp {
  const StocSelectTp();
  int get protoId => STOC_SELECT_TP;
  Uint8List encode() => Uint8List(0);
  static StocSelectTp decode(Uint8List data) => const StocSelectTp();
  @override
  String toString() => 'StocSelectTp';
}
