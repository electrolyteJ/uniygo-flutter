import '../messages/ygo_ctos_msg.dart';
import '../messages/ygo_stoc_msg.dart';
import 'packet.dart';

/// 协议适配层。
///
/// 负责 ygopro 协议消息对象与网络数据包之间的相互转换：
///
/// - [adaptCtos]: 将 CtoS 消息对象序列化为网络数据包（[YgoProPacket]）
/// - [adaptStoc]: 将网络数据包反序列化为 StoC 消息对象（[YgoStocMsg]）
///
/// 参考 neos-ts 的 adapter.ts 定义。

/// 将 CtoS 消息对象编码为线路上发送的网络数据包。
YgoProPacket adaptCtos(YgoCtosMsg msg) {
  return YgoProPacket.create(msg.protoId, msg.encode());
}

/// 将线路上接收的网络数据包解码为 StoC 消息对象。
YgoStocMsg adaptStoc(YgoProPacket packet) {
  return YgoStocMsg.decode(packet.proto, packet.exData);
}
