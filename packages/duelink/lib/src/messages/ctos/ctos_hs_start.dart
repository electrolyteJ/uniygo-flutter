import 'dart:typed_data';
import '../../constants.dart';

/// CTOS_HS_START (37)
///
/// 开始游戏对局。
///
/// 无负载数据。
///
/// 参考 neos-ts 的 ctosHsStart.ts 定义。
class CtosHsStart {
  const CtosHsStart();
  int get protoId => CTOS_HS_START;
  Uint8List encode() => Uint8List(0);
  static CtosHsStart decode(Uint8List data) => const CtosHsStart();
  @override
  String toString() => 'CtosHsStart';
}
