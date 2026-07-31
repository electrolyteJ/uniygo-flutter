import 'dart:typed_data';
import '../../constants.dart';

/// CTOS_HS_TO_DUELIST (32)
///
/// 告知 ygopro 服务端当前玩家进入决斗者行列。
///
/// 无负载数据。
///
/// 参考 neos-ts 的 ctosHsToDuelList.ts 定义。
class CtosHsToDuelist {
  const CtosHsToDuelist();
  int get protoId => CTOS_HS_TO_DUELIST;
  Uint8List encode() => Uint8List(0);
  static CtosHsToDuelist decode(Uint8List data) => const CtosHsToDuelist();
  @override
  String toString() => 'CtosHsToDuelist';
}
