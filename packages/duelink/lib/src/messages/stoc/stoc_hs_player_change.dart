import 'dart:typed_data';
import '../../constants.dart';
import '../../model/player.dart';
import '../../protocol/buffer_io.dart';

/// STOC_HS_PLAYER_CHANGE (33)
///
/// 等待房间中玩家状态变化通知。
///
/// 协议格式（1 字节位组合）:
/// - bits 7-4: pos（玩家位置 0-3）
/// - bits 3-0: state
///   - 0 = MOVE（换位）
///   - 1 = READY（就绪）
///   - 2 = NO_READY（取消就绪）
///   - 3 = LEAVE（离开）
///   - 4 = TO_OBSERVER（转为观战者）
///
/// 参考 neos-ts 的 stocHsPlayerChange.ts 定义。
class StocHsPlayerChange {
  final int pos;
  int _state = -1;

  PlayerChange get state => PlayerChange.of(_state);

  StocHsPlayerChange({required this.pos, required this._state});

  int get protoId => STOC_HS_PLAYER_CHANGE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(((pos & 0xf) << 4) | (_state & 0xf));
    return w.toBytes();
  }

  static StocHsPlayerChange decode(Uint8List data) {
    final b = data[0];
    return StocHsPlayerChange(pos: (b >> 4) & 0xf, state: b & 0xf);
  }

  @override
  String toString() => 'StocHsPlayerChange(pos:$pos action:${_state})';
}

