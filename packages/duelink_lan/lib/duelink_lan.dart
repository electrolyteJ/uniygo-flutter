library duelink_lan;

import 'package:duelink/duelink.dart';
import 'package:duelink_lan/src/lan_connection.dart';
import 'package:service_loader/service_loader.dart';

/// 局域网决斗服务实现 — 只需提供 TCP 连接，其余由 [BaseDuelService] 承担。
@Service(LanDuelService)
class LanDuelService extends BaseDuelService {
  LanDuelService() : super(LanConnection());
}
