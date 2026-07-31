import 'dart:typed_data';
import '../../constants.dart';

/// CTOS_TIME_CONFIRM (21)
///
/// 确认计时（时间限制确认）。
///
/// 无负载数据。
///
/// 参考 neos-ts 的 ctosTimeConfirm.ts 定义。
class CtosTimeConfirm {
  const CtosTimeConfirm();
  int get protoId => CTOS_TIME_CONFIRM;
  Uint8List encode() => Uint8List(0);
  static CtosTimeConfirm decode(Uint8List data) => const CtosTimeConfirm();
  @override
  String toString() => 'CtosTimeConfirm';
}
