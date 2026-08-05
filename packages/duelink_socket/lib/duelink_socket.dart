library duelink_socket;

import 'package:duelink/duelink.dart';
import 'package:duelink_socket/src/socket_connection.dart';
import 'package:service_loader/service_loader.dart';

export 'package:duelink_socket/src/socket_connection.dart'
    show SocketConnection;

/// TCP Socket 决斗服务实现 — 只需提供 TCP 连接，其余由 [BaseDuelService] 承担。
@Service(SocketDuelService)
class SocketDuelService extends BaseDuelService {
  SocketDuelService() : super(SocketConnection());
}
