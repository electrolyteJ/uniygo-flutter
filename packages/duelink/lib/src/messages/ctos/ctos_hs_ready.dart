import 'dart:typed_data';
import '../../constants.dart';

/// CTOS_HS_READY (34)
///
/// 告知 ygopro 服务端当前玩家准备完毕。
///
/// 无负载数据。
///
/// 参考 neos-ts 的 ctosHsReady.ts 定义。
class CtosHsReady {
  const CtosHsReady();
  int get protoId => CTOS_HS_READY;
  Uint8List encode() => Uint8List(0);
  static CtosHsReady decode(Uint8List data) => const CtosHsReady();
  @override
  String toString() => 'CtosHsReady';
}
