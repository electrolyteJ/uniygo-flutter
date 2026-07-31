import 'dart:typed_data';
import '../../constants.dart';

/// MSG_SP_SUMMONED (0x3F) — 特殊召唤完成通知
///
/// 通知客户端怪兽特殊召唤已完成。
/// 此消息没有附加负载数据。
///
/// 有线格式 (0 字节): 空负载，仅通过消息号传递事件。
///
/// 参考 neos-ts 的 penetrate.json (key 63) 定义。
class MsgSpSummoned {
  const MsgSpSummoned();

  int get funcId => MSG_SP_SUMMONED;

  Uint8List encode() => Uint8List(0);

  static MsgSpSummoned decode(Uint8List data) => const MsgSpSummoned();

  @override
  String toString() => 'MsgSpSummoned()';
}
