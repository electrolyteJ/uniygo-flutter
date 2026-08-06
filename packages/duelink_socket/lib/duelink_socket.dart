library duelink_socket;

import 'package:duelink/duelink.dart';
import 'package:duelink_socket/src/socket_connection.dart';
import 'package:service_loader/service_loader.dart';

export 'package:duelink_socket/src/socket_connection.dart'
    show SocketConnection;

/// TCP Socket 决斗服务实现 — 只需提供 TCP 连接，其余由 [BaseDuelService] 承担。
///
/// mercury233（s1.ygo233.com）等 srvpro 系服务器在每个玩家交互前下发
/// STOC_TIME_LIMIT，并等待 CTOS_TIME_CONFIRM 后才处理后续对局响应
/// （未确认则静默挂起）。收到 TIME_LIMIT 即自动确认，对其他服务器无害
/// （CTOS_TIME_CONFIRM 本就用于计时同步）。
@Service(SocketDuelService)
class SocketDuelService extends BaseDuelService {
  SocketDuelService() : super(SocketConnection()) {
    onServerMessage.listen((msg) {
      if (msg.protoId == STOC_TIME_LIMIT &&
          connectionState == ConnectionState.connected) {
        confirmTime();
      }
    });
  }
}
