library duelink_ai;

export 'src/ai_connection.dart';
export 'src/ai_service_impl.dart';

import 'package:duelink/duelink.dart';
import 'src/ai_connection.dart';
import 'src/ai_service_impl.dart';

/// 注册AI连接到工厂
void registerAiService() {
  ServiceFactory.register(ServiceType.ai, () => AiDuelServiceImpl());
}
