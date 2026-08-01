import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';
import '../../types.dart';

/// MSG_FIELD_DISABLED (0x38) — 区域禁用通知
///
/// 通知客户端某些怪兽/魔陷区域被禁用（不可使用）。
/// flag 的低位代表玩家 0 的 MZONE，接着是 SZONE，然后是玩家 1 的对应区域。
///
/// 有线格式 (4 字节):
/// | 偏移 | 大小 | 类型  | 说明                         |
/// |------|------|-------|------------------------------|
/// | 0x00 | 4    | int32 | 区域禁用位掩码 flag           |
///
/// 参考 neos-ts 的 fieldDisabled.ts 定义。
class MsgFieldDisabled {
  final int flag;
  final List<MsgFieldDisabledAction> actions;

  const MsgFieldDisabled({required this.flag, required this.actions});

  int get funcId => MSG_FIELD_DISABLED;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeInt32(flag);
    return w.toBytes();
  }

  static MsgFieldDisabled decode(Uint8List data) {
    final r = BufferReader(data);
    final flag = r.readInt32();
    final actions = <MsgFieldDisabledAction>[];

    int bit = 0x1;
    for (var i = 0; i < 5; i++, bit <<= 1) {
      actions.add(MsgFieldDisabledAction(
        controller: 0,
        zone: CARD_ZONE_MZONE,
        sequence: i,
        disabled: (flag & bit) != 0,
      ));
    }
    bit = 0x100;
    for (var i = 0; i < 8; i++, bit <<= 1) {
      actions.add(MsgFieldDisabledAction(
        controller: 0,
        zone: CARD_ZONE_SZONE,
        sequence: i,
        disabled: (flag & bit) != 0,
      ));
    }
    bit = 0x10000;
    for (var i = 0; i < 5; i++, bit <<= 1) {
      actions.add(MsgFieldDisabledAction(
        controller: 1,
        zone: CARD_ZONE_MZONE,
        sequence: i,
        disabled: (flag & bit) != 0,
      ));
    }
    bit = 0x1000000;
    for (var i = 0; i < 8; i++, bit <<= 1) {
      actions.add(MsgFieldDisabledAction(
        controller: 1,
        zone: CARD_ZONE_SZONE,
        sequence: i,
        disabled: (flag & bit) != 0,
      ));
    }

    return MsgFieldDisabled(flag: flag, actions: actions);
  }

  @override
  String toString() =>
      'MsgFieldDisabled(flag:$flag actions:${actions.length})';
}

class MsgFieldDisabledAction {
  final int controller;
  final int zone;
  final int sequence;
  final bool disabled;

  const MsgFieldDisabledAction({
    required this.controller,
    required this.zone,
    required this.sequence,
    required this.disabled,
  });

  CardZone get zoneEnum => CardZone.fromNumber(zone);
}
