library duelink_online;

import 'package:duelink_online/src/online_service_impl.dart';
import 'package:service_loader/service_loader.dart';

/// 注册在线连接到工厂
void registerOnlineService() {
  ServiceFactory.register(ServiceType.duelink_online, () => OnlineDuelServiceImpl());
}
