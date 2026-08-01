import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SELECT_CHAIN (0x10) — 连锁选择交互。
///
/// 该消息结构包含可连锁项、提示字段和强制连锁标记。
/// `flag` 保留原始数值，同时提供 [chainFlag] 方便直接判断语义。
class MsgSelectChain {
  final int player;
  final int chainCount;
  final int specialCount;
  final int hint0;
  final int hint1;
  final bool forced;
  final List<MsgSelectChainOption> chains;

  const MsgSelectChain({
    required this.player,
    required this.chainCount,
    required this.specialCount,
    required this.hint0,
    required this.hint1,
    required this.forced,
    required this.chains,
  });

  int get funcId => MSG_SELECT_CHAIN;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(chainCount);
    w.writeUint8(specialCount);
    w.writeUint32(hint0);
    w.writeUint32(hint1);
    for (final chain in chains) {
      w.writeUint8(chain.flag);
      w.writeUint8(chain.isForced ? 1 : 0);
      w.writeUint32(chain.code);
      w.writeCardLocation(chain.location);
      w.writeUint32(chain.effectDescription);
    }
    return w.toBytes();
  }

  static MsgSelectChain decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final chainCount = r.readUint8();
    final specialCount = r.readUint8();
    final hint0 = r.readUint32();
    final hint1 = r.readUint32();
    final chains = <MsgSelectChainOption>[];
    var forced = false;
    for (var i = 0; i < chainCount; i++) {
      final flag = r.readUint8();
      final isForced = r.readUint8() > 0;
      if (isForced) {
        forced = true;
      }
      chains.add(MsgSelectChainOption(
        flag: flag,
        isForced: isForced,
        code: r.readUint32() % 1000000000,
        location: r.readCardLocation(),
        effectDescription: r.readUint32(),
        response: i,
      ));
    }
    return MsgSelectChain(
      player: player,
      chainCount: chainCount,
      specialCount: specialCount,
      hint0: hint0,
      hint1: hint1,
      forced: forced,
      chains: chains,
    );
  }

  @override
  String toString() =>
      'MsgSelectChain(player:$player chainCount:$chainCount specialCount:$specialCount forced:$forced)';
}

class MsgSelectChainOption {
  final int flag;
  final bool isForced;
  final int code;
  final CardLocation location;
  final int effectDescription;
  final int response;

  const MsgSelectChainOption({
    required this.flag,
    required this.isForced,
    required this.code,
    required this.location,
    required this.effectDescription,
    required this.response,
  });

  MsgSelectChainFlag get chainFlag {
    switch (flag) {
      case 1:
        return MsgSelectChainFlag.effectDescriptionOperation;
      case 2:
        return MsgSelectChainFlag.effectDescriptionReset;
      default:
        return MsgSelectChainFlag.common;
    }
  }

  bool get hasOperationFlag => (flag & 1) != 0;
  bool get hasResetFlag => (flag & 2) != 0;
}

enum MsgSelectChainFlag {
  common,
  effectDescriptionOperation,
  effectDescriptionReset,
}
