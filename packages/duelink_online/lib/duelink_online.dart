library duelink_online;

import 'package:duelink/duelink.dart';
import 'package:duelink_online/src/online_connection.dart';
import 'package:service_loader/service_loader.dart';

/// 在线决斗服务实现 — 只需提供 WebSocket 连接，其余由 [BaseDuelService] 承担。
@Service(OnlineDuelService)
class OnlineDuelService extends BaseDuelService {
  OnlineDuelService() : super(OnlineConnection());
}

@OnServiceRegister()
onServiceRegister() {
  print("onServiceRegister");
}
