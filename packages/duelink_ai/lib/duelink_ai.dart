library duelink_ai;

export 'src/ai_connection.dart';

import 'package:duelink/duelink.dart';
import 'package:service_loader/service_loader.dart';

import 'duelink_ai.dart';

/// AI 本地决斗服务实现 — 只需提供 ocgcore 连接，其余由 [BaseDuelService] 承担。
@Service(AiDuelService)
class AiDuelService extends BaseDuelService {
  AiDuelService({DuelConnection? connection})
    : super(connection ?? AiConnection());
}

@OnServiceRegister()
onServiceRegister() {
  print("onServiceRegister");
}
