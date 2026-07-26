library duelink_lan;

import 'package:duelink/duelink.dart';
import 'package:duelink_lan/src/lan_service_impl.dart';

/// 注册局域网连接到工厂
void registerLanService() {
  ServiceFactory.register(ServiceType.lan, () => LanDuelServiceImpl());
}
