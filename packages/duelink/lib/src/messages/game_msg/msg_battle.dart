import 'dart:typed_data';

import '../../constants.dart';

/// MSG_BATTLE (0x6F) — 战斗结算数据。
///
/// 原始协议负载固定为 26 字节，但字段含义在不同前端实现中消费方式较重。
/// 当前先保留原始字节，避免误解码。
///
/// 这里没有提供半成品字段，是刻意选择：一旦只解出其中一部分而剩余字节被丢弃，
/// 上层既无法完整透传原协议，也难以在后续补充解码时复现原始上下文。
/// 因此 [rawData] 会完整保留当前消息体，供录像、调试、协议比对和未来结构化升级使用。
/// 如需进一步结构化，应先对照 ygopro 客户端里战斗动画和 LP 结算的消费逻辑。
class MsgBattle {
  final Uint8List rawData;

  const MsgBattle({required this.rawData});

  int get funcId => MSG_BATTLE;

  Uint8List encode() => rawData;

  static MsgBattle decode(Uint8List data) => MsgBattle(rawData: data);

  @override
  String toString() => 'MsgBattle(rawDataLen:${rawData.length})';
}
