import 'dart:typed_data';

import '../../constants.dart';

/// MSG_REVERSE_DECK (0x25) — 卡组显示朝向翻转通知。
class MsgReverseDeck {
  const MsgReverseDeck();

  int get funcId => MSG_REVERSE_DECK;

  Uint8List encode() => Uint8List(0);

  static MsgReverseDeck decode(Uint8List data) => const MsgReverseDeck();

  @override
  String toString() => 'MsgReverseDeck()';
}
