library duelink_online;

import 'package:duelink/duelink.dart';
import 'package:duelink_online/src/online_service_impl.dart';

/// 注册在线连接到工厂
void registerOnlineService() {
  ServiceFactory.register(ServiceType.default_, () => OnlineDuelServiceImpl());
}
