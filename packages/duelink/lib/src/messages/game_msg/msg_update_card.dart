import 'dart:typed_data';

import '../../../duelink.dart';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';
import 'msg_update_data.dart';

/// MSG_UPDATE_CARD (0x07) — 单张卡牌数据更新通知。
///
/// 和 `MSG_UPDATE_DATA` 一样属于 flag 驱动结构，但只针对单张卡牌。
/// 当前同时保留 [rawData]，以兼容未来扩展字段。
///
/// 当 [action] 非空时，调用方通常应直接消费结构化结果；[rawData] 仍然保留原始 payload，
/// 便于做协议透传、未知字段排查、或在未来补充更多解码逻辑时复用原字节。
///
/// 区域字段同样建议优先读取 [zoneValue] / [zoneEnum]；仅在需要协议原值时读取
/// [rawZone] / [zoneCode]。
class MsgUpdateCard {
  final int player;
  final int zone;
  final int sequence;
  final int? chunkLength;
  final MsgUpdateAction? action;
  final Uint8List rawData;

  const MsgUpdateCard({
    required this.player,
    required this.zone,
    required this.sequence,
    required this.chunkLength,
    required this.action,
    required this.rawData,
  });

  /// 原始协议中的区域数字值。
  int get rawZone => zone;

  /// [rawZone] 的别名，便于与其他结构保持一致。
  int get zoneCode => zone;

  /// 语义化的区域枚举，适合大多数业务/UI 场景。
  CardZone get zoneValue => zoneEnum;

  /// 语义化的区域枚举，适合大多数业务/UI 场景。
  CardZone get zoneEnum => CardZone.of(zone);

  int get funcId => MSG_UPDATE_CARD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(zone);
    w.writeUint8(sequence);
    if (chunkLength != null) {
      w.writeInt32(chunkLength!);
    }
    if (action != null) {
      w.writeBytes(action!.encode());
    } else {
      w.writeBytes(rawData);
    }
    return w.toBytes();
  }

  static MsgUpdateCard decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final zone = r.readUint8();
    final sequence = r.readUint8();

    int? chunkLength;
    MsgUpdateAction? action;
    Uint8List rawData = Uint8List(0);

    if (r.remaining >= 4) {
      chunkLength = r.readInt32();
      final payloadLength = chunkLength - 4;
      if (payloadLength > 0 && payloadLength <= r.remaining) {
        rawData = r.readBytes(payloadLength);
        action = MsgUpdateAction.decode(rawData);
      } else {
        rawData = r.readBytes(r.remaining);
      }
    }

    return MsgUpdateCard(
      player: player,
      zone: zone,
      sequence: sequence,
      chunkLength: chunkLength,
      action: action,
      rawData: rawData,
    );
  }

  @override
  String toString() => 'MsgUpdateCard(player:$player zone:$zone sequence:$sequence '
      'action=${action?.toString() ?? 'null'} rawDataLen:${rawData.length})';
}
