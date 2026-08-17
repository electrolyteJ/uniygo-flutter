/// 远端模型应答器工厂：封装 predict 客户端的创建（默认公共服务地址）
/// 与 [RemoteAgentAutoAnswer] 的装配，供连接层（如 duelink_ai
/// AiConnection）在 connect 时一键创建。
library;

import 'dart:typed_data';

import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:ocgcore/ocgcore.dart' show CardData;

import 'remote_agent_auto_answer.dart';
import 'src/agent_client.dart';
import 'src/remote_predict_session.dart';

/// [RemoteAgentAutoAnswer] 工厂。
///
/// 无状态；每次 [create] 生成新的应答器（内部携带新的会话，
/// 对局会话由 [RemoteAgentAutoAnswer.resetDuel] 按局在服务端创建）。
class RemoteAgentAutoAnswerFactory {
  RemoteAgentAutoAnswerFactory({YgoAgentClient? clientOverride})
      : _clientOverride = clientOverride;

  /// 客户端覆盖（测试注入 mock HTTP）；为 null 时用
  /// [kDefaultAgentServer] 创建。
  final YgoAgentClient? _clientOverride;

  /// 装配一个 [RemoteAgentAutoAnswer]。参数语义与其构造一致。
  RemoteAgentAutoAnswer create({
    required AgentFieldQuery field,
    CardData? Function(int code)? cardData,
    int startLp = 8000,
  }) {
    return RemoteAgentAutoAnswer(
      session: RemotePredictSession(
        client: _clientOverride ?? YgoAgentClient(server: kDefaultAgentServer),
      ),
      field: field,
      cardData: cardData,
      startLp: startLp,
    );
  }
}
