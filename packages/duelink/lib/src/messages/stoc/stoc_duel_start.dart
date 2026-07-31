import 'dart:typed_data';
import '../../constants.dart';

/// STOC_DUEL_START (21)
///
/// 对局开始通知。
///
/// 无负载数据。对局实际信息在 MSG_START game message 中发送。
///
/// 参考 neos-ts 的 stocDuelStart.ts 定义。
class StocDuelStart {
  const StocDuelStart();
  int get protoId => STOC_DUEL_START;
  Uint8List encode() => Uint8List(0);
  static StocDuelStart decode(Uint8List data) => const StocDuelStart();
  @override
  String toString() => 'StocDuelStart';
}
