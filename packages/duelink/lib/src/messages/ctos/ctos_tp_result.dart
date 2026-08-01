import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// CTOS_TP_RESULT (4)
///
/// 告知服务端当前玩家的先后攻选择。
///
/// 协议格式:
/// - first: unsigned char — 是否选择先攻
///   - 1 = 先攻（FIRST）
///   - 0 = 后攻（SECOND）
///
/// 参考 neos-ts 的 ctosTpResult.ts 定义。
class CtosTpResult {
  /// true=先攻, false=后攻
  final bool first;
  const CtosTpResult({required this.first});
  int get protoId => CTOS_TP_RESULT;

  /// 语义化的先后攻选择值，和原始 `first` 字段保持兼容。
  bool get tpValue => first;

  bool get isFirst => first;

  bool get isSecond => !first;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(first ? 1 : 0);
    return w.toBytes();
  }

  static CtosTpResult decode(Uint8List data) {
    final r = BufferReader(data);
    return CtosTpResult(first: r.readUint8() == 1);
  }

  @override
  String toString() => 'CtosTpResult(first: $first)';
}
