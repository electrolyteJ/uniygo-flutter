import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_ATTACK (0x6E) — 攻击宣言通知。
///
/// 载荷包含攻击方和目标方的 `CardLocation`。
/// 若目标位置全 0，则表示直接攻击。
class MsgAttack {
  final CardLocation attacker;
  final CardLocation? target;

  const MsgAttack({required this.attacker, this.target});

  int get funcId => MSG_ATTACK;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeCardLocation(attacker);
    w.writeCardLocation(target ?? const CardLocation(controller: 0, location: 0, sequence: 0, position: 0));
    return w.toBytes();
  }

  static MsgAttack decode(Uint8List data) {
    final r = BufferReader(data);
    final attacker = r.readCardLocation();
    final target = r.readCardLocation();
    final isDirect = target.controller == 0 && target.location == 0 && target.sequence == 0 && target.position == 0 && !target.isOverlay;
    return MsgAttack(
      attacker: attacker,
      target: isDirect ? null : target,
    );
  }

  @override
  String toString() => 'MsgAttack(attacker:$attacker target:$target)';
}
