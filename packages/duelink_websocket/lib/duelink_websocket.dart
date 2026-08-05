library duelink_websocket;

import 'package:duelink/duelink.dart';
import 'package:duelink_websocket/src/websocket_connection.dart';
import 'package:service_loader/service_loader.dart';

/// WebSocket 决斗服务实现 — 只需提供 WebSocket 连接，其余由 [BaseDuelService] 承担。
@Service(WebSocketDuelService)
class WebSocketDuelService extends BaseDuelService {
  WebSocketDuelService() : super(WebSocketConnection());
}

@OnServiceRegister()
onServiceRegister() {
  print("onServiceRegister");
}
