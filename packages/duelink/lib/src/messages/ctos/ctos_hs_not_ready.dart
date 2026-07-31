import 'dart:typed_data';
import '../../constants.dart';

/// CTOS_HS_NOT_READY (35)
///
/// 告知 ygopro 服务端当前玩家取消准备。
///
/// 无负载数据。
///
/// 参考 neos-ts 的 ctosHsNotReady.ts 定义。
class CtosHsNotReady {
  const CtosHsNotReady();
  int get protoId => CTOS_HS_NOT_READY;
  Uint8List encode() => Uint8List(0);
  static CtosHsNotReady decode(Uint8List data) => const CtosHsNotReady();
  @override
  String toString() => 'CtosHsNotReady';
}
