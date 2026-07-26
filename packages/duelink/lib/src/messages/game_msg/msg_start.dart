import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Duel start notification. Complex format.
/// playerType bits 7-4: isObserver, bits 3-0: 0=first/1=second.
/// If data >= 18 bytes, masterRule is at offset 1.
class MsgStart {
  final int playerType;
  final int? masterRule;
  final int life1;
  final int life2;
  final int deckSize1;
  final int extraSize1;
  final int deckSize2;
  final int extraSize2;

  const MsgStart({
    required this.playerType,
    this.masterRule,
    required this.life1,
    required this.life2,
    required this.deckSize1,
    required this.extraSize1,
    required this.deckSize2,
    required this.extraSize2,
  });

  int get funcId => MSG_START;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(playerType);
    if (masterRule != null) {
      w.writeUint8(masterRule!);
    }
    w.writeInt32(life1);
    w.writeInt32(life2);
    w.writeInt16(deckSize1);
    w.writeInt16(extraSize1);
    w.writeInt16(deckSize2);
    w.writeInt16(extraSize2);
    return w.toBytes();
  }

  static MsgStart decode(Uint8List data) {
    final r = BufferReader(data);
    final playerType = r.readUint8();
    final int? masterRule;
    if (data.length >= 18) {
      masterRule = r.readUint8();
    } else {
      masterRule = null;
    }
    return MsgStart(
      playerType: playerType,
      masterRule: masterRule,
      life1: r.readInt32(),
      life2: r.readInt32(),
      deckSize1: r.readInt16(),
      extraSize1: r.readInt16(),
      deckSize2: r.readInt16(),
      extraSize2: r.readInt16(),
    );
  }

  @override
  String toString() =>
      'MsgStart(playerType:$playerType masterRule:$masterRule life1:$life1 life2:$life2 deckSize1:$deckSize1 extraSize1:$extraSize1 deckSize2:$deckSize2 extraSize2:$extraSize2)';
}
