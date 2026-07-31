import 'dart:typed_data';
import '../../constants.dart';

/// CTOS_SURRENDER (20 / 0x14)
///
/// 告知服务端当前玩家投降。
///
/// 无负载数据。
///
/// 参考 neos-ts 的 ctosSurrender.ts 定义。
class CtosSurrender {
  const CtosSurrender();
  int get protoId => CTOS_SURRENDER;
  Uint8List encode() => Uint8List(0);
  static CtosSurrender decode(Uint8List data) => const CtosSurrender();
  @override
  String toString() => 'CtosSurrender';
}
