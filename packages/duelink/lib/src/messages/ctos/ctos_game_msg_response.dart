import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class CtosSelectPlace {
  final int player;
  final int zone;
  final int sequence;

  const CtosSelectPlace({
    required this.player,
    required this.zone,
    required this.sequence,
  });
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

  factory CtosGameMsgResponse.selectIdleCmd(int code) =>
      CtosGameMsgResponse._(selectIdleCmdCode: code);
  factory CtosGameMsgResponse.selectPlace(CtosSelectPlace p) =>
      CtosGameMsgResponse._(selectPlace: p);
  factory CtosGameMsgResponse.selectMulti(List<int> ptrs) =>
      CtosGameMsgResponse._(selectMultiPtrs: ptrs);
  factory CtosGameMsgResponse.selectSingle(int ptr) =>
      CtosGameMsgResponse._(selectSinglePtr: ptr);
  factory CtosGameMsgResponse.selectEffectYn(int result) =>
      CtosGameMsgResponse._(selectEffectYnResult: result);
  factory CtosGameMsgResponse.selectPosition(int pos) =>
      CtosGameMsgResponse._(selectPositionPos: pos);
  factory CtosGameMsgResponse.selectOption(int code) =>
      CtosGameMsgResponse._(selectOptionCode: code);
  factory CtosGameMsgResponse.selectBattleCmd(int cmd) =>
      CtosGameMsgResponse._(selectBattleCmdValue: cmd);
  factory CtosGameMsgResponse.selectCounter(List<int> values) =>
      CtosGameMsgResponse._(selectCounterValues: values);
  factory CtosGameMsgResponse.sortCard(List<int> indices) =>
      CtosGameMsgResponse._(sortCardIndices: indices);

  int get protoId => CTOS_RESPONSE;

  String get variantType {
    if (selectIdleCmdCode != null) return 'selectIdleCmd';
    if (selectPlace != null) return 'selectPlace';
    if (selectMultiPtrs != null) return 'selectMulti';
    if (selectSinglePtr != null) return 'selectSingle';
    if (selectEffectYnResult != null) return 'selectEffectYn';
    if (selectPositionPos != null) return 'selectPosition';
    if (selectOptionCode != null) return 'selectOption';
    if (selectBattleCmdValue != null) return 'selectBattleCmd';
    if (selectCounterValues != null) return 'selectCounter';
    if (sortCardIndices != null) return 'sortCard';
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
