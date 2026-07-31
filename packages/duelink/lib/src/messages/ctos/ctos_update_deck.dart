import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// CTOS_UPDATE_DECK (2)
///
/// 更新对局的卡组信息。
///
/// 协议格式:
/// - main:  unsigned int — 主卡组数目（含 extra）
/// - extra: unsigned int — 副卡组数目
/// - mainCards: [unsigned int; main] — 主卡组 + 额外卡组卡密列表
/// - sideCards: [unsigned int; extra] — 副卡组卡密列表
///
/// 参考 neos-ts 的 ctosUpdateDeck.ts 定义。
class CtosUpdateDeck {
  final List<int> mainDeck;
  final List<int> extraDeck;
  final List<int> sideDeck;

  const CtosUpdateDeck({
    required this.mainDeck,
    required this.extraDeck,
    required this.sideDeck,
  });

  int get protoId => CTOS_UPDATE_DECK;

  Uint8List encode() {
    final w = BufferWriter();
    final mainLen = mainDeck.length + extraDeck.length;
    final sideLen = sideDeck.length;
    w.writeInt32(mainLen);
    w.writeInt32(sideLen);
    for (final c in mainDeck) w.writeInt32(c);
    for (final c in extraDeck) w.writeInt32(c);
    for (final c in sideDeck) w.writeInt32(c);
    return w.toBytes();
  }

  static CtosUpdateDeck decode(Uint8List data) {
    final r = BufferReader(data);
    final mainLen = r.readInt32();
    final sideLen = r.readInt32();
    final allMain = <int>[];
    for (int i = 0; i < mainLen; i++) allMain.add(r.readInt32());
    final side = <int>[];
    for (int i = 0; i < sideLen; i++) side.add(r.readInt32());
    return CtosUpdateDeck(mainDeck: allMain, extraDeck: [], sideDeck: side);
  }

  @override
  String toString() => 'CtosUpdateDeck(main:${mainDeck.length} extra:${extraDeck.length} side:${sideDeck.length})';
}
