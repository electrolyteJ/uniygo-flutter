import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_BATTLE (0x6F) — 战斗结算数据。
///
/// 当前提取出稳定字段：攻方位置、攻防数值，守方位置、攻防数值，以及双方当前表示形式。
/// 同时保留 [rawData] 以兼容未来扩展和协议比对。
class MsgBattle {
  final CardLocation attacker;
  final int attackerAttack;
  final int attackerDefense;
  final int attackerPosition;
  final CardLocation defender;
  final int defenderAttack;
  final int defenderDefense;
  final int defenderPosition;
  final Uint8List rawData;

  const MsgBattle({
    required this.attacker,
    required this.attackerAttack,
    required this.attackerDefense,
    required this.attackerPosition,
    required this.defender,
    required this.defenderAttack,
    required this.defenderDefense,
    required this.defenderPosition,
    required this.rawData,
  });

  int get funcId => MSG_BATTLE;

  bool get hasDefender => defender.location != 0;

  Uint8List encode() => rawData;

  static MsgBattle decode(Uint8List data) {
    final r = BufferReader(data);
    final attacker = r.readCardLocation();
    final attackerAttack = r.readInt32();
    final attackerDefense = r.readInt32();
    final attackerPosition = r.readUint8();
    final defender = r.readCardLocation();
    final defenderAttack = r.readInt32();
    final defenderDefense = r.readInt32();
    final defenderPosition = r.readUint8();
    return MsgBattle(
      attacker: attacker,
      attackerAttack: attackerAttack,
      attackerDefense: attackerDefense,
      attackerPosition: attackerPosition,
      defender: defender,
      defenderAttack: defenderAttack,
      defenderDefense: defenderDefense,
      defenderPosition: defenderPosition,
      rawData: Uint8List.fromList(data),
    );
  }

  @override
  String toString() =>
      'MsgBattle(attacker:$attacker attackerAttack:$attackerAttack defender:$defender defenderAttack:$defenderAttack rawDataLen:${rawData.length})';
}
