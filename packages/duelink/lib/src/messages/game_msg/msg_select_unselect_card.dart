import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SELECT_UNSELECT_CARD (0x1A) — 反选卡交互。
///
/// 当前已结构化解析可选卡和已选卡两段列表，同时保留 [rawData] 以兼容未来变化。
///
/// [rawData] 仍然会保留完整负载，因为交互消息常被上层直接缓存或重放；即使当前字段
/// 已足够驱动 UI，也不应在解码阶段丢失尚未显式建模的原始字节。
class MsgSelectUnselectCard {
  final int player;
  final bool finishable;
  final bool cancelable;
  final int min;
  final int max;
  final List<MsgSelectUnselectCardInfo> selectableCards;
  final List<MsgSelectUnselectCardInfo> selectedCards;
  final Uint8List rawData;

  const MsgSelectUnselectCard({
    required this.player,
    required this.finishable,
    required this.cancelable,
    required this.min,
    required this.max,
    required this.selectableCards,
    required this.selectedCards,
    required this.rawData,
  });

  int get funcId => MSG_SELECT_UNSELECT_CARD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(finishable ? 1 : 0);
    w.writeUint8(cancelable ? 1 : 0);
    w.writeUint8(min);
    w.writeUint8(max);
    w.writeUint8(selectableCards.length);
    for (final item in selectableCards) {
      _writeInfo(w, item);
    }
    w.writeUint8(selectedCards.length);
    for (final item in selectedCards) {
      _writeInfo(w, item);
    }
    return w.toBytes();
  }

  static void _writeInfo(BufferWriter w, MsgSelectUnselectCardInfo info) {
    w.writeUint32(info.code);
    w.writeCardLocation(info.location);
  }

  static MsgSelectUnselectCard decode(Uint8List data) {
    final rawData = Uint8List.fromList(data);
    final r = BufferReader(data);
    final player = r.readUint8();
    final finishable = r.readUint8() != 0;
    final cancelable = r.readUint8() != 0;
    final min = r.readUint8();
    final max = r.readUint8();

    final selectableCount = r.readUint8();
    final selectableCards = <MsgSelectUnselectCardInfo>[];
    for (var i = 0; i < selectableCount; i++) {
      selectableCards.add(MsgSelectUnselectCardInfo(
        code: r.readUint32(),
        location: r.readCardLocation(),
        response: i,
      ));
    }

    final selectedCount = r.readUint8();
    final selectedCards = <MsgSelectUnselectCardInfo>[];
    for (var i = 0; i < selectedCount; i++) {
      selectedCards.add(MsgSelectUnselectCardInfo(
        code: r.readUint32(),
        location: r.readCardLocation(),
        response: selectableCount + i,
      ));
    }

    return MsgSelectUnselectCard(
      player: player,
      finishable: finishable,
      cancelable: cancelable,
      min: min,
      max: max,
      selectableCards: selectableCards,
      selectedCards: selectedCards,
      rawData: rawData,
    );
  }

  @override
  String toString() =>
      'MsgSelectUnselectCard(player:$player selectable:${selectableCards.length} selected:${selectedCards.length})';
}

class MsgSelectUnselectCardInfo {
  final int code;
  final CardLocation location;
  final int response;

  const MsgSelectUnselectCardInfo({
    required this.code,
    required this.location,
    required this.response,
  });
}
