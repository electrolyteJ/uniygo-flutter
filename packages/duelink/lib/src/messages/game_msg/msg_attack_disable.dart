import 'dart:typed_data';
import '../../constants.dart';

/// MSG_ATTACK_DISABLE (0x70) — 攻击无效/无法攻击通知
///
/// 服务端通知客户端某次攻击被无效化或当前无法进行攻击。
/// 此消息没有附加负载数据。
///
/// 有线格式 (0 字节): 空负载，仅通过消息号传递事件。
///
/// 参考 neos-ts 的 attackDisable.ts 定义。
class MsgAttackDisable {
  const MsgAttackDisable();

  int get funcId => MSG_ATTACK_DISABLE;

  Uint8List encode() => Uint8List(0);

  static MsgAttackDisable decode(Uint8List data) => const MsgAttackDisable();

  @override
  String toString() => 'MsgAttackDisable()';
}
