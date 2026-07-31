import 'dart:typed_data';
import '../../constants.dart';

/// MSG_FLIP_SUMMONED (0x41) — 反转召唤完成通知
///
/// 通知客户端怪兽反转召唤已完成。
/// 此消息没有附加负载数据。
///
/// 有线格式 (0 字节): 空负载，仅通过消息号传递事件。
///
/// 参考 neos-ts 的 flipSummoned.ts 定义。
class MsgFlipSummoned {
  const MsgFlipSummoned();

  int get funcId => MSG_FLIP_SUMMONED;

  Uint8List encode() => Uint8List(0);

  static MsgFlipSummoned decode(Uint8List data) => const MsgFlipSummoned();

  @override
  String toString() => 'MsgFlipSummoned()';
}
