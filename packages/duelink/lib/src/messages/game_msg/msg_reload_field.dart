import 'dart:typed_data';

import '../../../duelink.dart';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_RELOAD_FIELD (0xA2) — 断线重连/全场刷新。
///
/// 当前会结构化解析双方 LP、各区域卡位快照，并保留 [rawData] 作为回退。
/// 连锁区数据暂未继续细化，因为 `neos-ts` 也保留了这部分未启用逻辑。
///
/// 对于已解析出的区域/表示形式，消费方通常应优先使用 enum getter；[rawData]
/// 则用于保留尚未细化的刷新负载，避免重编码或后续补解码时丢失信息。
class MsgReloadField {
  final int duelRule;
  final List<MsgReloadFieldPlayer> players;
  final Uint8List rawData;

  const MsgReloadField({
    required this.duelRule,
    required this.players,
    required this.rawData,
  });

  int get funcId => MSG_RELOAD_FIELD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(duelRule);
    w.writeBytes(rawData);
    return w.toBytes();
  }

  static MsgReloadField decode(Uint8List data) {
    if (data.isEmpty) {
      return MsgReloadField(duelRule: 0, players: const <MsgReloadFieldPlayer>[], rawData: Uint8List(0));
    }
    final r = BufferReader(data);
    final duelRule = r.readUint8();
    final payloadStart = r.offset;

    final players = <MsgReloadFieldPlayer>[];
    for (var player = 0; player < 2 && r.hasRemaining; player++) {
      final lp = r.readUint32();
      final zoneActions = <MsgReloadFieldZoneAction>[];

      for (var sequence = 0; sequence < 7; sequence++) {
        final occupied = r.readUint8();
        if (occupied != 0) {
          zoneActions.add(MsgReloadFieldZoneAction(
            zone: CARD_ZONE_MZONE,
            sequence: sequence,
            position: r.readUint8(),
            overlayCount: r.readUint8(),
          ));
        }
      }

      for (var sequence = 0; sequence < 8; sequence++) {
        final occupied = r.readUint8();
        if (occupied != 0) {
          zoneActions.add(MsgReloadFieldZoneAction(
            zone: CARD_ZONE_SZONE,
            sequence: sequence,
            position: r.readUint8(),
          ));
        }
      }

      void addSizedZone(int zone, int size, {int? position}) {
        for (var sequence = 0; sequence < size; sequence++) {
          zoneActions.add(MsgReloadFieldZoneAction(
            zone: zone,
            sequence: sequence,
            position: position,
          ));
        }
      }

      addSizedZone(CARD_ZONE_DECK, r.readUint8(), position: POS_FACEDOWN_ATTACK);
      addSizedZone(CARD_ZONE_HAND, r.readUint8());
      addSizedZone(CARD_ZONE_GRAVE, r.readUint8());
      addSizedZone(CARD_ZONE_REMOVED, r.readUint8());
      addSizedZone(CARD_ZONE_EXTRA, r.readUint8(), position: POS_FACEDOWN_ATTACK);

      final extraFaceUpPendulumCount = r.readUint8();

      players.add(MsgReloadFieldPlayer(
        player: player,
        lp: lp,
        zoneActions: zoneActions,
        extraFaceUpPendulumCount: extraFaceUpPendulumCount,
      ));
    }

    // 连锁区（C++ reload_field_info 末尾）：条数 + 每条 15 字节
    // （code u32 / info_location u32 / controller u8 / location u8 /
    // sequence u8 / description u32）。结构化解析未细化，但必须消费掉，
    // 否则 rawData 会吞掉缓冲区中紧随其后的其他消息。
    if (r.hasRemaining) {
      final chainCount = r.readUint8();
      r.skip(chainCount * 15);
    }

    // 只保留本消息自身的载荷字节 —— 引擎缓冲区可能首尾相接多条消息，
    // 贪婪读取会让 encode() 重编码长度失真（见 StocGameMessage.decodeAll）。
    final rawData = Uint8List.sublistView(data, payloadStart, r.offset);

    return MsgReloadField(
      duelRule: duelRule,
      players: players,
      rawData: rawData,
    );
  }

  @override
  String toString() =>
      'MsgReloadField(duelRule:$duelRule players:${players.length} rawDataLen:${rawData.length})';
}

class MsgReloadFieldPlayer {
  final int player;
  final int lp;
  final List<MsgReloadFieldZoneAction> zoneActions;
  final int extraFaceUpPendulumCount;

  const MsgReloadFieldPlayer({
    required this.player,
    required this.lp,
    required this.zoneActions,
    required this.extraFaceUpPendulumCount,
  });
}

class MsgReloadFieldZoneAction {
  final int zone;
  final int sequence;
  final int? position;
  final int overlayCount;

  const MsgReloadFieldZoneAction({
    required this.zone,
    required this.sequence,
    this.position,
    this.overlayCount = 0,
  });

  /// 原始协议中的区域数字值。
  int get rawZone => zone;

  /// [rawZone] 的别名，便于与其他结构保持一致。
  int get zoneCode => zone;

  /// 语义化的区域枚举，适合大多数消费场景。
  CardZone get zoneValue => zoneEnum;

  /// 语义化的区域枚举，适合大多数消费场景。
  CardZone get zoneEnum => CardZone.of(zone);

  /// 原始协议中的表示形式数字值；当该区域没有 position 概念时为 null。
  int? get rawPosition => position;

  /// [rawPosition] 的别名，便于与其他结构保持一致。
  int? get positionCode => position;

  /// 语义化的表示形式枚举；仅在 [position] 存在时有值。
  CardPosition? get cardPosition => positionEnum;

  CardPosition? get positionEnum =>
      position == null ? null : CardPosition.of(position!);
  bool get hasOverlay => overlayCount > 0;
}
