import 'dart:typed_data';
import '../../constants.dart';

/// CTOS_HS_TO_OBSERVER (33)
///
/// 告知 ygopro 服务端当前玩家进入观战者行列。
///
/// 无负载数据。
///
/// 参考 neos-ts 的 ctosHsToObserver.ts 定义。
class CtosHsToObserver {
  const CtosHsToObserver();
  int get protoId => CTOS_HS_TO_OBSERVER;
  Uint8List encode() => Uint8List(0);
  static CtosHsToObserver decode(Uint8List data) => const CtosHsToObserver();
  @override
  String toString() => 'CtosHsToObserver';
}
