import 'dart:typed_data';
import '../../constants.dart';
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
  final int selfType;
  const StocTypeChange({required this.isHost, required this.selfType});

  StocSelfType get selfTypeValue {
    switch (selfType) {
      case 0:
        return StocSelfType.player1;
      case 1:
        return StocSelfType.player2;
      case 7:
        return StocSelfType.observer;
      default:
        return StocSelfType.unknown;
    }
  }

  bool get isObserver => selfTypeValue == StocSelfType.observer;
  int get protoId => STOC_TYPE_CHANGE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(((isHost ? 1 : 0) << 4) | (selfType & 0xf));
    return w.toBytes();
  }

  static StocTypeChange decode(Uint8List data) {
    final b = data[0];
    return StocTypeChange(isHost: ((b >> 4) & 0xf) != 0, selfType: b & 0xf);
  }

  @override
  String toString() => 'StocTypeChange(isHost:$isHost selfType:$selfType)';
}

enum StocSelfType { unknown, player1, player2, observer }
