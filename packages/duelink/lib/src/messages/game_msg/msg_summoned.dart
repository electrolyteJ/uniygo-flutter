import 'dart:typed_data';
import '../../constants.dart';

/// MSG_SUMMONED (0x3D) — 通常召唤完成通知
///
/// 通知客户端怪兽通常召唤已完成。
/// 此消息没有附加负载数据。
///
/// 有线格式 (0 字节): 空负载，仅通过消息号传递事件。
///
/// 参考 neos-ts 的 penetrate.json (key 61) 定义。
class MsgSummoned {
  const MsgSummoned();

  int get funcId => MSG_SUMMONED;

  Uint8List encode() => Uint8List(0);

  static MsgSummoned decode(Uint8List data) => const MsgSummoned();

  @override
  String toString() => 'MsgSummoned()';
}
