import 'dart:typed_data';

import '../../constants.dart';

/// MSG_RETRY (0x01) — 要求客户端重新响应上一条交互消息。
///
/// 这是 ygopro 原始二进制协议中的控制消息，通常由服务端在响应非法或
/// 不可接受时发送。该消息没有负载，收到后应沿用上一条可交互消息重新作答。
class MsgRetry {
  const MsgRetry();

  int get funcId => MSG_RETRY;

  Uint8List encode() => Uint8List(0);

  static MsgRetry decode(Uint8List data) => const MsgRetry();

  @override
  String toString() => 'MsgRetry()';
}
