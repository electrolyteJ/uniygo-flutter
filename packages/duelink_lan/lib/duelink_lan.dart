library duelink_lan;

import 'package:duelink/duelink.dart';
import 'package:duelink_lan/src/lan_service_impl.dart';
import 'package:service_loader/service_loader.dart';

/// 注册局域网连接到工厂
void registerLanService() {
  ServiceFactory.register(ServiceType.duelink_lan, () => LanDuelServiceImpl());
}
