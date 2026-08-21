library duelink_ai;

export 'src/ai_connection.dart';
export 'src/card_data_loader.dart';

import 'dart:developer' as console;

import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart'
    show AgentAutoAnswerer;
import 'package:ocgcore/ocgcore.dart' show ScriptLoader;
import 'package:service_loader/service_loader.dart';
import 'duelink_ai.dart';
import 'package:ygo_data/card_info.dart';
/// AI 本地决斗服务实现 — 只需提供 ocgcore 连接，其余由 [BaseDuelService] 承担。
///
/// [lib] 用于显式指定 ocgcore 动态库（测试环境传入；为 null 时按平台默认
/// 规则查找 libocgcore）。[scriptLoader] 用于显式指定 lua 脚本加载器
/// （测试环境 rootBundle 资产不可用时传入文件系统加载器）。
/// 保持可无参构造以满足 `@Service` 注册要求。
@Service(AiDuelService)
class AiDuelService extends BaseDuelService {
  AiDuelService({Object? lib, ScriptLoader? scriptLoader})
      : super(AiConnection(lib: lib, scriptLoader: scriptLoader));

  void setCardConverter(CardConverter converter) {
    (connection as AiConnection).setCardConverter(converter);
  }

  /// 诊断/测试钩子：当前生效的模型应答器（规则 AI 时为 null）。
  /// 远端应答器（RemoteAgentAutoAnswer）可读取 broken/successCount。
  AgentAutoAnswerer? get agentAnswerer =>
      (connection as AiConnection).agentAnswerer;

  /// 测试钩子：固定 AI 猜拳出拳（1=剪刀 2=石头 3=布），null 恢复随机。
  ///
  /// AI 猜拳赢时不会下发 SELECT_TP（直接由 AI 决定先后攻开局），
  /// 因此「人类赢 → 选先攻」的 UI/协议流程测试需要确定性出拳。
  set fixedAiHandChoice(int? value) {
    (connection as AiConnection).fixedAiHandChoice = value;
  }
}

@OnServiceRegister()
onServiceRegister() {
  console.log('duelink_ai.dart onServiceRegister');
}
typedef CardConverter = Future<CardInfo?> Function(int code);
