import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_TAG_SWAP (0xA1) — Tag Duel 换人同步数据。
///
/// 原始协议会携带当前上场玩家更新后的卡组/手牌/额外卡组快照。
class MsgTagSwap {
  final int player;
  final int mainCount;
  final int extraCount;
  final int extraFaceUpPendulumCount;
  final int handCount;
  final int topCode;
  final List<int> handCodes;
  final List<int> extraCodes;

  const MsgTagSwap({
    required this.player,
    required this.mainCount,
    required this.extraCount,
    required this.extraFaceUpPendulumCount,
    required this.handCount,
    required this.topCode,
    required this.handCodes,
    required this.extraCodes,
  });

  bool get hasTopCardCode => topCode != 0;
  bool get hasHandCodes => handCodes.isNotEmpty;
  bool get hasExtraCodes => extraCodes.isNotEmpty;
  int get faceUpPendulumCount => extraFaceUpPendulumCount;

  int get funcId => MSG_TAG_SWAP;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(mainCount);
    w.writeUint8(extraCount);
    w.writeUint8(extraFaceUpPendulumCount);
    w.writeUint8(handCount);
    w.writeInt32(topCode);
    w.writeUint32List(handCodes);
    w.writeUint32List(extraCodes);
    return w.toBytes();
  }

  static MsgTagSwap decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final mainCount = r.readUint8();
    final extraCount = r.readUint8();
    final extraFaceUpPendulumCount = r.readUint8();
    final handCount = r.readUint8();
    final topCode = r.readInt32();
    final handCodes = r.readUint32List(handCount);
    final extraCodes = r.readUint32List(extraCount);
    return MsgTagSwap(
      player: player,
      mainCount: mainCount,
      extraCount: extraCount,
      extraFaceUpPendulumCount: extraFaceUpPendulumCount,
      handCount: handCount,
      topCode: topCode,
      handCodes: handCodes,
      extraCodes: extraCodes,
    );
  }

  @override
  String toString() =>
      'MsgTagSwap(player:$player mainCount:$mainCount extraCount:$extraCount extraFaceUpPendulumCount:$extraFaceUpPendulumCount handCount:$handCount topCode:$topCode handCodes:${handCodes.length} extraCodes:${extraCodes.length})';
}
