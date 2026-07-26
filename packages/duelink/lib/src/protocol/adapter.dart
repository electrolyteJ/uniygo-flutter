import '../messages/ygo_ctos_msg.dart';
import '../messages/ygo_stoc_msg.dart';
import 'packet.dart';

/// Convert a CTOS message to a wire-level packet.
YgoProPacket adaptCtos(YgoCtosMsg msg) {
  return YgoProPacket.create(msg.protoId, msg.encode());
}

/// Convert a wire-level packet to a STOC message.
YgoStocMsg adaptStoc(YgoProPacket packet) {
  return YgoStocMsg.decode(packet.proto, packet.exData);
}
