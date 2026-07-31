import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_CHAIN_SOLVED (0x49) — 连锁逆解处理通知
///
/// 通知客户端连锁中的某一环已被处理（逆序解连锁）。
///
/// 有线格式 (1 字节):
/// | 偏移 | 大小 | 类型  | 说明                   |
/// |------|------|-------|------------------------|
/// | 0x00 | 1    | uint8 | 处理的连锁索引 (0 起始) |
///
/// 参考 neos-ts 的 chainSolved.ts 定义。
class MsgChainSolved {
  final int solvedIndex;

  const MsgChainSolved({required this.solvedIndex});

  int get funcId => MSG_CHAIN_SOLVED;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(solvedIndex);
    return w.toBytes();
  }

  static MsgChainSolved decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgChainSolved(solvedIndex: r.readUint8());
  }

  @override
  String toString() => 'MsgChainSolved(solvedIndex:$solvedIndex)';
}
