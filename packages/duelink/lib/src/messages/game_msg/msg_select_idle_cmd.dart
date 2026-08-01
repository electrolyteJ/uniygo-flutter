import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SELECT_IDLE_CMD (0x0B) — 主阶段可执行操作列表。
///
/// 该消息会列出召唤、盖放、发动效果、进入战斗阶段等可选动作。
class MsgSelectIdleCmd {
  final int player;
  final List<MsgIdleCmdGroup> commandGroups;
  final bool enableBp;
  final bool enableEp;
  final bool enableShuffle;

  const MsgSelectIdleCmd({
    required this.player,
    required this.commandGroups,
    required this.enableBp,
    required this.enableEp,
    required this.enableShuffle,
  });

  int get funcId => MSG_SELECT_IDLE_CMD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    for (final group in commandGroups) {
      w.writeUint8(group.options.length);
      for (final option in group.options) {
        w.writeCardInfo(option.cardInfo);
        if (group.type == MsgIdleCmdType.activate) {
          w.writeUint32(option.effectDescription ?? 0);
        }
      }
    }
    w.writeUint8(enableBp ? 1 : 0);
    w.writeUint8(enableEp ? 1 : 0);
    w.writeUint8(enableShuffle ? 1 : 0);
    return w.toBytes();
  }

  static MsgSelectIdleCmd decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final groups = <MsgIdleCmdGroup>[];
    final types = <MsgIdleCmdType>[
      MsgIdleCmdType.summon,
      MsgIdleCmdType.spSummon,
      MsgIdleCmdType.posChange,
      MsgIdleCmdType.mset,
      MsgIdleCmdType.sset,
      MsgIdleCmdType.activate,
    ];

    for (var groupIndex = 0; groupIndex < types.length; groupIndex++) {
      final count = r.readUint8();
      final options = <MsgIdleCmdOption>[];
      for (var i = 0; i < count; i++) {
        final cardInfo = r.readCardInfo();
        final effectDescription = types[groupIndex] == MsgIdleCmdType.activate
            ? r.readUint32()
            : null;
        options.add(MsgIdleCmdOption(
          cardInfo: cardInfo,
          response: (i << 16) + groupIndex,
          effectDescription: effectDescription,
        ));
      }
      groups.add(MsgIdleCmdGroup(type: types[groupIndex], options: options));
    }

    return MsgSelectIdleCmd(
      player: player,
      commandGroups: groups,
      enableBp: r.readUint8() == 1,
      enableEp: r.readUint8() == 1,
      enableShuffle: r.readUint8() == 1,
    );
  }

  @override
  String toString() =>
      'MsgSelectIdleCmd(player:$player commandGroups:${commandGroups.length} enableBp:$enableBp enableEp:$enableEp enableShuffle:$enableShuffle)';
}

enum MsgIdleCmdType { summon, spSummon, posChange, mset, sset, activate }

class MsgIdleCmdGroup {
  final MsgIdleCmdType type;
  final List<MsgIdleCmdOption> options;

  const MsgIdleCmdGroup({required this.type, required this.options});
}

class MsgIdleCmdOption {
  final CardInfo cardInfo;
  final int response;
  final int? effectDescription;

  const MsgIdleCmdOption({
    required this.cardInfo,
    required this.response,
    this.effectDescription,
  });
}
