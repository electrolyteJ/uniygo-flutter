/// 远端 predict 会话：neos-ts `YgoAgent` 中序号状态管理的移植。
///
/// 只负责会话簿记（duelId / index / prevActionIdx），不做动作选择与
/// 引擎应答序列化——那是集成层（如 duelink_ai 的自动应答）的职责。
///
/// 典型用法（对应 neos-ts `sendAIPredictAsResponse` 的单步分支）：
/// ```dart
/// final session = RemotePredictSession(client: client);
/// await session.start();                       // createDuel
/// final resp = await session.predict(input);   // predictDuel
/// final chosen = argmax(resp.actionPreds);     // 集成层选动作
/// session.recordChoice(chosen);                // 供下一次请求携带
/// ```
///
/// 多选消息（select_card/tribute/sum）与 neos-ts 一致：每选一张更新
/// `msg.selected` 后再次调用 [predict]，直到 AI 返回 response == -1 /
/// 达到 max / canFinish。
library;

import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';

import 'agent_client.dart';

class RemotePredictSession {
  // ignore: prefer_initializing_formals — 参数名 client 比 _client 更适合公开 API
  RemotePredictSession({required YgoAgentClient client}) : _client = client;

  final YgoAgentClient _client;

  String? _duelId;

  /// 下一次请求要携带的序号（= 上一次响应的 index）。
  int _index = 0;

  /// 上一步所选动作的响应空间下标（neos-ts `prevActionIndex`）。
  int _prevActionIdx = 0;

  /// 当前会话 id；[start] 之前为 null。
  String? get duelId => _duelId;

  int get index => _index;
  int get prevActionIdx => _prevActionIdx;

  /// 创建对局会话（neos-ts `YgoAgent.init` 的 createDuel 部分）。
  Future<void> start() async {
    final created = await _client.createDuel();
    _duelId = created.duelId;
    _index = created.index;
    _prevActionIdx = 0;
  }

  /// 请求一步决策。调用前必须先 [start]。
  Future<MsgResponse> predict(Input input) async {
    final duelId = _duelId;
    if (duelId == null) {
      throw StateError('RemotePredictSession not started');
    }
    final resp = await _client.predictDuel(
      duelId,
      index: _index,
      input: input,
      prevActionIdx: _prevActionIdx,
    );
    _index = resp.index;
    return resp.predictResults;
  }

  /// 记录本步所选动作（响应空间下标），供下一次 [predict] 携带。
  ///
  /// 对应 neos-ts `sendRequest` 末尾的 `prevActionIndex = actionIdx`。
  void recordChoice(int actionIdx) => _prevActionIdx = actionIdx;
}
