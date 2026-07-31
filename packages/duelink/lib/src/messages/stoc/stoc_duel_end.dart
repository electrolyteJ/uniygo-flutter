import 'dart:typed_data';
import '../../constants.dart';

/// STOC_DUEL_END (22)
///
/// 对局结束通知。
///
/// 无负载数据。
///
/// 参考 neos-ts 的 stocDuelEnd.ts 定义。
class StocDuelEnd {
  const StocDuelEnd();
  int get protoId => STOC_DUEL_END;
  Uint8List encode() => Uint8List(0);
  static StocDuelEnd decode(Uint8List data) => const StocDuelEnd();
  @override
  String toString() => 'StocDuelEnd';
}
