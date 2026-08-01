import 'dart:typed_data';
import '../../constants.dart';

/// CTOS_HS_TO_DUELIST (32)
///
/// 告知 ygopro 服务端当前玩家进入决斗者行列。
///
/// 命名说明：原始 ygopro/旧前端通常称为 `HsToDuelist`，而 `ocgcore.proto`
/// / `neos-ts` 的 protobuf 语义名对应 `CtosHsToDuelList`。两者协议号相同，
/// 都是等待房间里“切回决斗席”的动作。
///
/// 无负载数据。
///
/// 参考 neos-ts 的 ctosHsToDuelList.ts 定义。
class CtosHsToDuelist {
  const CtosHsToDuelist();
  int get protoId => CTOS_HS_TO_DUELIST;
  Uint8List encode() => Uint8List(0);
  static CtosHsToDuelist decode(Uint8List data) => const CtosHsToDuelist();
  @override
  String toString() => 'CtosHsToDuelist';
}
