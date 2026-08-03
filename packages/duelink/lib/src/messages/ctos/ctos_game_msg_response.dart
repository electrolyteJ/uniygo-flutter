import 'dart:typed_data';
import '../../constants.dart';
import '../../model/card.dart';
import '../../protocol/buffer_io.dart';

/// CTOS_RESPONSE (1)
///
/// 回复服务端的各种游戏内交互请求。
///
/// 一个 [CtosGameMsgResponse] 只包含一种响应类型的字段（互斥），
/// 编码时根据具体的响应类型构造对应的二进制数据：
///
/// - [selectIdleCmd]   → uint32: 选择的指令序号
/// - [selectPlace]     → controller(u8) + zone(u8) + sequence(u8)
/// - [selectMulti]     → count(u8) + [ptrs; count] (u8 each)
/// - [selectSingle]    → int32: 指针序号
/// - [selectEffectYn]  → uint32: 是否发动 (1=是, 0=否)
/// - [selectPosition]  → uint32: 表示形式
/// - [selectOption]    → uint32: 选项序号
/// - [selectBattleCmd] → uint32: 战斗指令
/// - [selectCounter]   → [int16; N]: 各计数器值
/// - [sortCard]        → [u8; N]: 排序索引
///
/// 参考 neos-ts 中 ctosGameMsgResponse/ 目录下的各响应类型定义。

class CtosSelectPlace {
  final int player;
  final int zone;
  final int sequence;

  const CtosSelectPlace({
    required this.player,
    required this.zone,
    required this.sequence,
  });

  /// 原始协议中的区域数字值。
  int get rawZone => zone;

  /// [rawZone] 的别名，便于与其他协议结构的 helper getter 保持一致。
  int get zoneCode => zone;

  /// 语义化的区域枚举，适合大多数消费场景。
  CardZone get zoneValue => zoneEnum;

  /// [zoneValue] 的别名，便于与其他协议结构保持一致。
  CardZone get zoneEnum => CardZone.of(zone);
}

class CtosGameMsgResponse {
  final int? selectIdleCmdCode;
  final CtosSelectPlace? selectPlace;
  final List<int>? selectMultiPtrs;
  final int? selectSinglePtr;
  final int? selectEffectYnResult;
  final int? selectPositionPos;
  final int? selectOptionCode;
  final int? selectBattleCmdValue;
  final List<int>? selectCounterValues;
  final List<int>? sortCardIndices;

  const CtosGameMsgResponse._({
    this.selectIdleCmdCode,
    this.selectPlace,
    this.selectMultiPtrs,
    this.selectSinglePtr,
    this.selectEffectYnResult,
    this.selectPositionPos,
    this.selectOptionCode,
    this.selectBattleCmdValue,
    this.selectCounterValues,
    this.sortCardIndices,
  });

  /// 选择空闲阶段指令（MSG_SELECT_IDLE_CMD 响应）。
  factory CtosGameMsgResponse.selectIdleCmd(int code) =>
      CtosGameMsgResponse._(selectIdleCmdCode: code);
  /// 选择放置位置（MSG_SELECT_PLACE 响应）。
  factory CtosGameMsgResponse.selectPlace(CtosSelectPlace p) =>
      CtosGameMsgResponse._(selectPlace: p);
  /// 多选卡牌（MSG_SELECT_CARD / MSG_SELECT_TRIBUTE / MSG_SELECT_UNSELECT_CARD 响应）。
  factory CtosGameMsgResponse.selectMulti(List<int> ptrs) =>
      CtosGameMsgResponse._(selectMultiPtrs: ptrs);
  /// 单选卡牌（MSG_CONFIRM_CARDS 等多交互响应）。
  factory CtosGameMsgResponse.selectSingle(int ptr) =>
      CtosGameMsgResponse._(selectSinglePtr: ptr);
  /// 是否发动效果（MSG_SELECT_EFFECTYN 响应）。
  factory CtosGameMsgResponse.selectEffectYn(int result) =>
      CtosGameMsgResponse._(selectEffectYnResult: result);
  /// 选择表示形式（MSG_SELECT_POSITION 响应）。
  factory CtosGameMsgResponse.selectPosition(int pos) =>
      CtosGameMsgResponse._(selectPositionPos: pos);
  /// 选择选项（MSG_SELECT_OPTION 响应）。
  factory CtosGameMsgResponse.selectOption(int code) =>
      CtosGameMsgResponse._(selectOptionCode: code);
  /// 选择战斗指令（MSG_SELECT_BATTLE_CMD 响应）。
  factory CtosGameMsgResponse.selectBattleCmd(int cmd) =>
      CtosGameMsgResponse._(selectBattleCmdValue: cmd);
  /// 选择计数器（MSG_SELECT_COUNTER 响应）。
  factory CtosGameMsgResponse.selectCounter(List<int> values) =>
      CtosGameMsgResponse._(selectCounterValues: values);
  /// 排卡序（MSG_SORT_CARD 响应）。
  factory CtosGameMsgResponse.sortCard(List<int> indices) =>
      CtosGameMsgResponse._(sortCardIndices: indices);

  int get protoId => CTOS_RESPONSE;

  /// 原始协议中的 position 数字值，仅在 `selectPosition` 变体下有意义。
  int? get rawPosition => selectPositionPos;

  /// [rawPosition] 的别名，便于与其他协议结构保持一致。
  int? get positionCode => selectPositionPos;

  /// 语义化的表示形式枚举。
  CardPosition? get cardPosition =>
      selectPositionPos == null ? null : CardPosition.of(selectPositionPos!);

  /// [cardPosition] 的别名，便于与其他 message 的 helper getter 保持一致。
  CardPosition? get positionValue =>
      cardPosition;

  /// 是否发动效果的语义化布尔值，仅在 `selectEffectYn` 变体下有意义。
  bool? get effectYnValue =>
      selectEffectYnResult == null ? null : selectEffectYnResult != 0;

  bool get isSelectIdleCmd => selectIdleCmdCode != null;

  bool get isSelectPlace => selectPlace != null;

  bool get isSelectMulti => selectMultiPtrs != null;

  bool get isSelectSingle => selectSinglePtr != null;

  bool get isSelectEffectYn => selectEffectYnResult != null;

  bool get isSelectPosition => selectPositionPos != null;

  bool get isSelectOption => selectOptionCode != null;

  bool get isSelectBattleCmd => selectBattleCmdValue != null;

  bool get isSelectCounter => selectCounterValues != null;

  bool get isSortCard => sortCardIndices != null;

  String get variantType {
    if (isSelectIdleCmd) return 'selectIdleCmd';
    if (isSelectPlace) return 'selectPlace';
    if (isSelectMulti) return 'selectMulti';
    if (isSelectSingle) return 'selectSingle';
    if (isSelectEffectYn) return 'selectEffectYn';
    if (isSelectPosition) return 'selectPosition';
    if (isSelectOption) return 'selectOption';
    if (isSelectBattleCmd) return 'selectBattleCmd';
    if (isSelectCounter) return 'selectCounter';
    if (isSortCard) return 'sortCard';
    return 'unknown';
  }

  Uint8List encode() {
    final w = BufferWriter();
    if (selectIdleCmdCode != null) {
      w.writeUint32(selectIdleCmdCode!);
    } else if (selectPlace != null) {
      w.writeUint8(selectPlace!.player);
      w.writeUint8(selectPlace!.zone);
      w.writeUint8(selectPlace!.sequence);
    } else if (selectMultiPtrs != null) {
      w.writeUint8(selectMultiPtrs!.length);
      for (final p in selectMultiPtrs!) w.writeUint8(p);
    } else if (selectSinglePtr != null) {
      w.writeInt32(selectSinglePtr!);
    } else if (selectEffectYnResult != null) {
      w.writeUint32(selectEffectYnResult!);
    } else if (selectPositionPos != null) {
      w.writeUint32(selectPositionPos!);
    } else if (selectOptionCode != null) {
      w.writeUint32(selectOptionCode!);
    } else if (selectBattleCmdValue != null) {
      w.writeUint32(selectBattleCmdValue!);
    } else if (selectCounterValues != null) {
      for (final v in selectCounterValues!) w.writeInt16(v);
    } else if (sortCardIndices != null) {
      for (final i in sortCardIndices!) w.writeUint8(i);
    }
    return w.toBytes();
  }

  static CtosGameMsgResponse decode(Uint8List data) {
    if (data.length >= 4) {
      final r = BufferReader(data);
      return CtosGameMsgResponse._(selectSinglePtr: r.readInt32());
    }
    return CtosGameMsgResponse._();
  }

  @override
  String toString() => 'CtosGameMsgResponse($variantType)';
}
