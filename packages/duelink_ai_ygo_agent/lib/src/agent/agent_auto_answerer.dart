/// 模型自动应答器的统一接口：本地（duelink_ai_ygo_agent_tflite
/// [AgentAutoAnswer]）与远端（duelink_ai_ygo_agent_http
/// [RemoteAgentAutoAnswer]）推理共用同一生命周期。
///
/// 方法返回 `FutureOr`：同步实现（本地模型）直接返回值即可，
/// 异步实现（远端 HTTP）返回 Future；调用方一律 await。
library;

import 'dart:async';
import 'dart:typed_data';

/// 模型驱动的引擎自动应答器。
///
/// 生命周期：
/// 1. 连接建立后挂到 `DuelEngine.setAutoAnswer(answer)`；
/// 2. 每局开始前调用 [resetDuel] 重置簿记与模型/会话状态；
/// 3. 引擎下发的每条对局消息经 [observe] 记账（LP/回合/阶段/revealed）；
/// 4. AI 玩家的待应答消息经 [answer] 推理；返回 null 表示无法应答
///    （打日志，引擎停住等待）。
abstract interface class AgentAutoAnswerer {
  /// 场态簿记入口：引擎下发的每条对局消息（payload 不含 func 头）。
  void observe(int func, Uint8List payload);

  /// 新局开始：重建簿记与模型/会话状态。
  FutureOr<void> resetDuel({int? startLp});

  /// 自动应答入口。返回 null = 无法应答（引擎停住）。
  FutureOr<Uint8List?> answer(int func, Uint8List payload);
}
