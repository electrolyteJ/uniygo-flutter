import 'dart:typed_data';

import '../../../duelink.dart';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_UPDATE_DATA (0x06) — 批量卡牌数据更新。
///
/// 每个 action 都由 `len(int32) + payload` 组成，payload 内部再由 flag 位掩码
/// 决定具体字段。
///
/// 为了兼容 ygopro 的可变查询结果，本类型同时保留 [rawData]，并尽量结构化解析
/// 已知字段；未识别或未来新增字段仍可通过原始字节回退处理。
///
/// 消费方一般优先读取 [zoneValue] 这类语义化 getter；只有在需要把原始区域码继续
/// 透传、做位判断、或排查未知协议值时，才读取 [rawZone] / [zoneCode]。
class MsgUpdateData {
  final int player;
  final int zone;
  final List<MsgUpdateAction> actions;
  final Uint8List rawData;

  const MsgUpdateData({
    required this.player,
    required this.zone,
    required this.actions,
    required this.rawData,
  });

  /// 原始协议中的区域数字值。
  int get rawZone => zone;

  /// [rawZone] 的别名，便于与其他 message 的 helper getter 保持一致。
  int get zoneCode => zone;

  /// 语义化的区域枚举，适合大多数业务/UI 场景。
  CardZone get zoneValue => CardZone.of(zone);
  int get funcId => MSG_UPDATE_DATA;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(zone);
    for (final action in actions) {
      final bytes = action.encode();
      w.writeInt32(bytes.length + 4);
      w.writeBytes(bytes);
    }
    return w.toBytes();
  }

  static MsgUpdateData decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final zone = r.readUint8();
    final rawData = r.readBytes(data.length - 2);

    final actions = <MsgUpdateAction>[];
    final actionReader = BufferReader(rawData);
    while (actionReader.remaining >= 4) {
      final length = actionReader.readInt32();
      if (length < 4) {
        // 非法长度，终止解析。
        break;
      }
      if (length == 4) {
        // MZONE/SZONE 固定快照中的空槽位（len=4 无 payload）：
        // 跳过该槽位，继续解析后续槽位，而不是终止整个解析。
        continue;
      }
      if (length - 4 > actionReader.remaining) {
        break;
      }
      final payload = actionReader.readBytes(length - 4);
      final action = MsgUpdateAction.decode(payload);
      if (action != null) {
        actions.add(action);
      }
    }

    return MsgUpdateData(
      player: player,
      zone: zone,
      actions: actions,
      rawData: rawData,
    );
  }

  @override
  String toString() => 'MsgUpdateData(player:$player zone:$zone '
      'actions:[${actions.map((a) => a.toString()).join(' | ')}] '
      'rawDataLen:${rawData.length})';
}

class MsgUpdateAction {
  final int flag;
  final int? code;
  final CardLocation? location;
  final int? alias;
  final int? type;
  final int? level;
  final int? rank;
  final int? attribute;
  final int? race;
  final int? attack;
  final int? defense;
  final int? baseAttack;
  final int? baseDefense;
  final int? reason;
  final int? reasonCard;
  final CardLocation? equipCard;
  final List<CardLocation> targetCards;
  final List<int> overlayCards;
  final Map<int, int> counters;
  final int? owner;
  final int? status;
  final int? lscale;
  final int? rscale;
  final int? link;

  const MsgUpdateAction({
    required this.flag,
    this.code,
    this.location,
    this.alias,
    this.type,
    this.level,
    this.rank,
    this.attribute,
    this.race,
    this.attack,
    this.defense,
    this.baseAttack,
    this.baseDefense,
    this.reason,
    this.reasonCard,
    this.equipCard,
    this.targetCards = const <CardLocation>[],
    this.overlayCards = const <int>[],
    this.counters = const <int, int>{},
    this.owner,
    this.status,
    this.lscale,
    this.rscale,
    this.link,
  });

  bool get hasCode => (flag & UPDATE_FLAG_CODE) != 0;
  bool get hasPosition => (flag & UPDATE_FLAG_POSITION) != 0;
  bool get hasAlias => (flag & UPDATE_FLAG_ALIAS) != 0;
  bool get hasType => (flag & UPDATE_FLAG_TYPE) != 0;
  bool get hasLevel => (flag & UPDATE_FLAG_LEVEL) != 0;
  bool get hasRank => (flag & UPDATE_FLAG_RANK) != 0;
  bool get hasAttribute => (flag & UPDATE_FLAG_ATTRIBUTE) != 0;
  bool get hasRace => (flag & UPDATE_FLAG_RACE) != 0;
  bool get hasAttack => (flag & UPDATE_FLAG_ATTACK) != 0;
  bool get hasDefense => (flag & UPDATE_FLAG_DEFENSE) != 0;
  bool get hasBaseAttack => (flag & UPDATE_FLAG_BASE_ATTACK) != 0;
  bool get hasBaseDefense => (flag & UPDATE_FLAG_BASE_DEFENSE) != 0;
  bool get hasReason => (flag & UPDATE_FLAG_REASON) != 0;
  bool get hasReasonCard => (flag & UPDATE_FLAG_REASON_CARD) != 0;
  bool get hasEquipCard => (flag & UPDATE_FLAG_EQUIP_CARD) != 0;
  bool get hasTargetCards => (flag & UPDATE_FLAG_TARGET_CARD) != 0;
  bool get hasOverlayCards => (flag & UPDATE_FLAG_OVERLAY_CARD) != 0;
  bool get hasCounters => (flag & UPDATE_FLAG_COUNTERS) != 0;
  bool get hasOwner => (flag & UPDATE_FLAG_OWNER) != 0;
  bool get hasStatus => (flag & UPDATE_FLAG_STATUS) != 0;
  bool get hasLscale => (flag & UPDATE_FLAG_LSCALE) != 0;
  bool get hasRscale => (flag & UPDATE_FLAG_RSCALE) != 0;
  bool get hasLink => (flag & UPDATE_FLAG_LINK) != 0;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeInt32(flag);
    if ((flag & UPDATE_FLAG_CODE) != 0 && code != null) w.writeInt32(code!);
    if ((flag & UPDATE_FLAG_POSITION) != 0 && location != null) {
      w.writeCardLocation(location!);
    }
    if ((flag & UPDATE_FLAG_ALIAS) != 0 && alias != null) w.writeInt32(alias!);
    if ((flag & UPDATE_FLAG_TYPE) != 0 && type != null) w.writeInt32(type!);
    if ((flag & UPDATE_FLAG_LEVEL) != 0 && level != null) w.writeInt32(level!);
    if ((flag & UPDATE_FLAG_RANK) != 0 && rank != null) w.writeInt32(rank!);
    if ((flag & UPDATE_FLAG_ATTRIBUTE) != 0 && attribute != null) {
      w.writeInt32(attribute!);
    }
    if ((flag & UPDATE_FLAG_RACE) != 0 && race != null) w.writeInt32(race!);
    if ((flag & UPDATE_FLAG_ATTACK) != 0 && attack != null)
      w.writeInt32(attack!);
    if ((flag & UPDATE_FLAG_DEFENSE) != 0 && defense != null) {
      w.writeInt32(defense!);
    }
    if ((flag & UPDATE_FLAG_BASE_ATTACK) != 0 && baseAttack != null) {
      w.writeInt32(baseAttack!);
    }
    if ((flag & UPDATE_FLAG_BASE_DEFENSE) != 0 && baseDefense != null) {
      w.writeInt32(baseDefense!);
    }
    if ((flag & UPDATE_FLAG_REASON) != 0 && reason != null)
      w.writeInt32(reason!);
    if ((flag & UPDATE_FLAG_REASON_CARD) != 0 && reasonCard != null) {
      w.writeInt32(reasonCard!);
    }
    if ((flag & UPDATE_FLAG_EQUIP_CARD) != 0 && equipCard != null) {
      w.writeCardLocation(equipCard!);
    }
    if ((flag & UPDATE_FLAG_TARGET_CARD) != 0) {
      w.writeInt32(targetCards.length);
      for (final item in targetCards) {
        w.writeCardLocation(item);
      }
    }
    if ((flag & UPDATE_FLAG_OVERLAY_CARD) != 0) {
      w.writeInt32(overlayCards.length);
      for (final item in overlayCards) {
        w.writeInt32(item);
      }
    }
    if ((flag & UPDATE_FLAG_COUNTERS) != 0) {
      w.writeInt32(counters.length);
      counters.forEach((key, value) {
        w.writeUint16(key);
        w.writeUint16(value);
      });
    }
    if ((flag & UPDATE_FLAG_OWNER) != 0 && owner != null) w.writeInt32(owner!);
    if ((flag & UPDATE_FLAG_STATUS) != 0 && status != null)
      w.writeInt32(status!);
    if ((flag & UPDATE_FLAG_LSCALE) != 0 && lscale != null)
      w.writeInt32(lscale!);
    if ((flag & UPDATE_FLAG_RSCALE) != 0 && rscale != null)
      w.writeInt32(rscale!);
    if ((flag & UPDATE_FLAG_LINK) != 0 && link != null) w.writeInt32(link!);
    return w.toBytes();
  }

  static MsgUpdateAction? decode(Uint8List data) {
    final r = BufferReader(data);
    if (r.remaining < 4) return null;
    final flag = r.readInt32();
    if (flag == 0) return null;

    int? code;
    CardLocation? location;
    int? alias;
    int? type;
    int? level;
    int? rank;
    int? attribute;
    int? race;
    int? attack;
    int? defense;
    int? baseAttack;
    int? baseDefense;
    int? reason;
    int? reasonCard;
    CardLocation? equipCard;
    final targetCards = <CardLocation>[];
    final overlayCards = <int>[];
    final counters = <int, int>{};
    int? owner;
    int? status;
    int? lscale;
    int? rscale;
    int? link;

    if ((flag & UPDATE_FLAG_CODE) != 0) code = r.readInt32();
    if ((flag & UPDATE_FLAG_POSITION) != 0) location = r.readCardLocation();
    if ((flag & UPDATE_FLAG_ALIAS) != 0) alias = r.readInt32();
    if ((flag & UPDATE_FLAG_TYPE) != 0) type = r.readInt32();
    if ((flag & UPDATE_FLAG_LEVEL) != 0) level = r.readInt32();
    if ((flag & UPDATE_FLAG_RANK) != 0) rank = r.readInt32();
    if ((flag & UPDATE_FLAG_ATTRIBUTE) != 0) attribute = r.readInt32();
    if ((flag & UPDATE_FLAG_RACE) != 0) race = r.readInt32();
    if ((flag & UPDATE_FLAG_ATTACK) != 0) attack = r.readInt32();
    if ((flag & UPDATE_FLAG_DEFENSE) != 0) defense = r.readInt32();
    if ((flag & UPDATE_FLAG_BASE_ATTACK) != 0) baseAttack = r.readInt32();
    if ((flag & UPDATE_FLAG_BASE_DEFENSE) != 0) baseDefense = r.readInt32();
    if ((flag & UPDATE_FLAG_REASON) != 0) reason = r.readInt32();
    if ((flag & UPDATE_FLAG_REASON_CARD) != 0) reasonCard = r.readInt32();
    if ((flag & UPDATE_FLAG_EQUIP_CARD) != 0) equipCard = r.readCardLocation();
    if ((flag & UPDATE_FLAG_TARGET_CARD) != 0) {
      final count = r.readInt32();
      for (var i = 0; i < count; i++) {
        targetCards.add(r.readCardLocation());
      }
    }
    if ((flag & UPDATE_FLAG_OVERLAY_CARD) != 0) {
      final count = r.readInt32();
      for (var i = 0; i < count; i++) {
        overlayCards.add(r.readInt32());
      }
    }
    if ((flag & UPDATE_FLAG_COUNTERS) != 0) {
      final count = r.readInt32();
      for (var i = 0; i < count; i++) {
        counters[r.readUint16()] = r.readUint16();
      }
    }
    if ((flag & UPDATE_FLAG_OWNER) != 0) owner = r.readInt32();
    if ((flag & UPDATE_FLAG_STATUS) != 0) status = r.readInt32();
    if ((flag & UPDATE_FLAG_LSCALE) != 0) lscale = r.readInt32();
    if ((flag & UPDATE_FLAG_RSCALE) != 0) rscale = r.readInt32();
    if ((flag & UPDATE_FLAG_LINK) != 0) link = r.readInt32();

    return MsgUpdateAction(
      flag: flag,
      code: code,
      location: location,
      alias: alias,
      type: type,
      level: level,
      rank: rank,
      attribute: attribute,
      race: race,
      attack: attack,
      defense: defense,
      baseAttack: baseAttack,
      baseDefense: baseDefense,
      reason: reason,
      reasonCard: reasonCard,
      equipCard: equipCard,
      targetCards: targetCards,
      overlayCards: overlayCards,
      counters: counters,
      owner: owner,
      status: status,
      lscale: lscale,
      rscale: rscale,
      link: link,
    );
  }

  /// 完整字段打印（flag 用十六进制，便于对照 UPDATE_FLAG_* 常量），
  /// 供 handleServerMessage 的 MSG_UPDATE_DATA / MSG_UPDATE_CARD 日志排查
  /// 里侧卡（code=0/null）、攻守缺失等协议问题。
  @override
  String toString() {
    final buf = StringBuffer('MsgUpdateAction(flag=0x${flag.toRadixString(16)}');
    if (code != null) buf.write(' code=$code');
    if (location != null) buf.write(' loc=$location');
    if (attack != null) buf.write(' atk=$attack');
    if (defense != null) buf.write(' def=$defense');
    if (baseAttack != null) buf.write(' baseAtk=$baseAttack');
    if (baseDefense != null) buf.write(' baseDef=$baseDefense');
    if (level != null) buf.write(' lv=$level');
    if (rank != null) buf.write(' rank=$rank');
    if (type != null) buf.write(' type=$type');
    if (attribute != null) buf.write(' attr=$attribute');
    if (race != null) buf.write(' race=$race');
    if (alias != null) buf.write(' alias=$alias');
    if (reason != null) buf.write(' reason=$reason');
    if (reasonCard != null) buf.write(' reasonCard=$reasonCard');
    if (equipCard != null) buf.write(' equip=$equipCard');
    if (targetCards.isNotEmpty) buf.write(' targets=${targetCards.length}');
    if (overlayCards.isNotEmpty) buf.write(' overlay=${overlayCards.length}');
    if (counters.isNotEmpty) buf.write(' counters=$counters');
    if (owner != null) buf.write(' owner=$owner');
    if (status != null) buf.write(' status=$status');
    if (lscale != null) buf.write(' lscale=$lscale');
    if (rscale != null) buf.write(' rscale=$rscale');
    if (link != null) buf.write(' link=$link');
    buf.write(')');
    return buf.toString();
  }
}
