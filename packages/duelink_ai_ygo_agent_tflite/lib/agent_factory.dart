/// 端侧模型应答器工厂：封装模型运行时的解析与缓存
/// （注入 → 资产加载），供连接层（如 duelink_ai AiConnection）
/// 在每次 connect 时一键装配 [AgentAutoAnswer]。
library;

import 'dart:typed_data';

import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:ocgcore/ocgcore.dart' show CardData;

import 'agent_auto_answer.dart';
import 'asset_runtime.dart';

/// [AgentAutoAnswer] 工厂。
///
/// 运行时只解析一次（首次 [create]），跨 connect 复用、不随断线释放；
/// 解析失败（无注入且资产不可用）时 [create] 返回 null，由调用方
/// 回退规则 AI。
class AgentAutoAnswerFactory {
  AgentAutoAnswerFactory({AgentRuntime? agentRuntime})
      : _injectedRuntime = agentRuntime;

  /// 显式注入的模型运行时（测试/自定义加载路径）。
  final AgentRuntime? _injectedRuntime;

  AgentRuntime? _runtime;
  bool _runtimeResolved = false;

  /// 已解析的运行时（未解析前为 null；解析失败也为 null）。
  AgentRuntime? get runtime => _runtime;

  /// 装配一个 [AgentAutoAnswer]；模型不可用（首次解析失败）时返回 null。
  ///
  /// 参数语义与 [AgentAutoAnswer] 构造一致；[startLp] 应取房间选项的
  /// 初始 LP。
  Future<AgentAutoAnswer?> create({
    required AgentFieldQuery field,
    CardData? Function(int code)? cardData,
    int startLp = 8000,
  }) async {
    if (!_runtimeResolved) {
      _runtimeResolved = true;
      _runtime = _injectedRuntime ?? await loadAssetRuntime();
    }
    final runtime = _runtime;
    if (runtime == null) return null;
    return AgentAutoAnswer(
      runtime: runtime,
      field: field,
      cardData: cardData,
      startLp: startLp,
    );
  }
}
