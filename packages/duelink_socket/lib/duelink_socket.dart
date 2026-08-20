library duelink_socket;

import 'package:duelink/duelink.dart';
import 'package:duelink_socket/src/socket_connection.dart';
import 'package:service_loader/service_loader.dart';

export 'package:duelink_socket/src/socket_connection.dart'
    show SocketConnection;

/// TCP Socket 决斗服务实现 — 只需提供 TCP 连接，其余由 [BaseDuelService] 承担。
///
/// TIME_LIMIT 自动确认（CTOS_TIME_CONFIRM）已上移到 [BaseDuelService]，
/// 覆盖全部传输层（ws/tcp/ai/puzzle），此处不再重复。
@Service(SocketDuelService)
class SocketDuelService extends BaseDuelService {
  SocketDuelService() : super(SocketConnection());
}
