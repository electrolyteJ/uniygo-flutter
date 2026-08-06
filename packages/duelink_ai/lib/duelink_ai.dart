library duelink_ai;

export 'src/ai_connection.dart';

import 'dart:ffi' as ffi;

import 'package:duelink/duelink.dart';
import 'package:service_loader/service_loader.dart';

import 'duelink_ai.dart';

/// AI 本地决斗服务实现 — 只需提供 ocgcore 连接，其余由 [BaseDuelService] 承担。
///
/// [lib] 用于显式指定 ocgcore 动态库（测试环境传入；为 null 时按平台默认
/// 规则查找 libocgcore）。保持可无参构造以满足 `@Service` 注册要求。
@Service(AiDuelService)
class AiDuelService extends BaseDuelService {
  AiDuelService({ffi.DynamicLibrary? lib}) : super(AiConnection(lib: lib));
}

@OnServiceRegister()
onServiceRegister() {
  print("onServiceRegister");
}
