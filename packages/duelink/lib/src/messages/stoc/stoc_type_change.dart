import 'dart:typed_data';
import '../../constants.dart';
import '../../model/player.dart';
import '../../protocol/buffer_io.dart';

/// STOC_TYPE_CHANGE (19)
///
/// 玩家自身类型变化通知。
///
/// 协议格式（1 字节位组合）:
/// - bits 7-4: isHost（1=主机，0=非主机）
/// - bits 3-0: selfType（0=PLAYER1, 1=PLAYER2, 7=OBSERVER）
///
/// 参考 neos-ts 的 stocTypeChange.ts 定义。
class StocTypeChange {
  final bool isHost;

  /// 0=PLAYER1, 1=PLAYER2, 7=OBSERVER
  final int _selfType;
  // 命名参数不能以下划线开头：对外暴露 selfType，内部存 _selfType。
  const StocTypeChange({required this.isHost, required int selfType})
    : _selfType = selfType;

  PlayerType get selfType => PlayerType.of(_selfType);
  int get protoId => STOC_TYPE_CHANGE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(((isHost ? 1 : 0) << 4) | (_selfType & 0xf));
    return w.toBytes();
  }

  static StocTypeChange decode(Uint8List data) {
    final b = data[0];
    return StocTypeChange(isHost: ((b >> 4) & 0xf) != 0, selfType: b & 0xf);
  }

  @override
  String toString() => 'StocTypeChange(isHost:$isHost selfType:$_selfType)';
}
