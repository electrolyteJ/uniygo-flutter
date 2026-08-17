/// Remote ygo-agent predict service client (neos-ts `neos-ai-agent`
/// protocol): HTTP createDuel + predict, with per-duel session bookkeeping.
///
/// 端侧推理见 `duelink_ai_ygo_agent`（+ `duelink_ai_ygo_agent_tflite`）；本包是不带本地模型、
/// 把局面快照发给远端服务决策的替代路径。
library;

export 'src/remote_agent_auto_answer.dart';
export 'src/agent_client.dart';
export 'src/input_serializer.dart';
export 'src/remote_predict_session.dart';

import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:ocgcore/ocgcore.dart' show CardData;

import 'src/remote_agent_auto_answer.dart';
import 'src/agent_client.dart';
import 'src/remote_predict_session.dart';

RemoteAgentAutoAnswer createYgoAgentHttp({
  required AgentFieldQuery field,
  CardData? Function(int code)? cardData,
  int startLp = 8000,
}) {
  return RemoteAgentAutoAnswer(
    session: RemotePredictSession(
      client: YgoAgentClient(server: kDefaultAgentServer),
    ),
    field: field,
    cardData: cardData,
    startLp: startLp,
  );
}
