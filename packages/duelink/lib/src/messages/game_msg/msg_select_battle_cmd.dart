import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SELECT_BATTLE_CMD (0x0A) — 战斗阶段可执行操作列表。
///
/// 该消息会列出攻击、发动效果、进入 M2/EP 等可选动作。
class MsgSelectBattleCmd {
  final int player;
  final List<MsgBattleCmdGroup> commandGroups;
  final bool enableM2;
  final bool enableEp;

  const MsgSelectBattleCmd({
    required this.player,
    required this.commandGroups,
    required this.enableM2,
    required this.enableEp,
  });

  int get funcId => MSG_SELECT_BATTLE_CMD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    for (final group in commandGroups) {
      w.writeUint8(group.options.length);
      for (final option in group.options) {
        w.writeCardInfo(option.cardInfo);
        if (group.type == MsgBattleCmdType.activate) {
          w.writeUint32(option.effectDescription ?? 0);
        } else {
          w.writeUint8(option.directAttackable ? 1 : 0);
        }
      }
    }
    w.writeUint8(enableM2 ? 1 : 0);
    w.writeUint8(enableEp ? 1 : 0);
    return w.toBytes();
  }

  static MsgSelectBattleCmd decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();

    final activateCount = r.readUint8();
    final activateOptions = <MsgBattleCmdOption>[];
    for (var i = 0; i < activateCount; i++) {
      activateOptions.add(MsgBattleCmdOption(
        cardInfo: r.readCardInfo(),
        effectDescription: r.readUint32(),
        response: (i << 16) + 0,
      ));
    }

    final attackCount = r.readUint8();
    final attackOptions = <MsgBattleCmdOption>[];
    for (var i = 0; i < attackCount; i++) {
      attackOptions.add(MsgBattleCmdOption(
        cardInfo: r.readCardInfo(),
        directAttackable: r.readUint8() == 1,
        response: (i << 16) + 1,
      ));
    }

    return MsgSelectBattleCmd(
      player: player,
      commandGroups: <MsgBattleCmdGroup>[
        MsgBattleCmdGroup(
          type: MsgBattleCmdType.activate,
          options: activateOptions,
        ),
        MsgBattleCmdGroup(
          type: MsgBattleCmdType.attack,
          options: attackOptions,
        ),
      ],
      enableM2: r.readUint8() == 1,
      enableEp: r.readUint8() == 1,
    );
  }

  @override
  String toString() =>
      'MsgSelectBattleCmd(player:$player commandGroups:${commandGroups.length} enableM2:$enableM2 enableEp:$enableEp)';
}

enum MsgBattleCmdType { activate, attack }

class MsgBattleCmdGroup {
  final MsgBattleCmdType type;
  final List<MsgBattleCmdOption> options;

  const MsgBattleCmdGroup({required this.type, required this.options});
}

class MsgBattleCmdOption {
  final CardInfo cardInfo;
  final int response;
  final int? effectDescription;
  final bool directAttackable;

  const MsgBattleCmdOption({
    required this.cardInfo,
    required this.response,
    this.effectDescription,
    this.directAttackable = false,
  });
}
