/// ygo-agent 核心包：特征编码与动作选择逻辑的 Dart 移植（与上游 Python
/// 实现的 golden 张量逐位对齐），以及本地/远端推理共用的 agent 层
/// （场态簿记、消息解码、Input 构建、应答字节工具）。
///
/// 推理后端见 `duelink_ai_ygo_agent_tflite`（端侧）与
/// `duelink_ai_ygo_agent_http`（远端 predict 服务）。
library;

export 'src/agent/action_msg_decoder.dart';
export 'src/agent/agent_auto_answerer.dart';
export 'src/agent/agent_answer_utils.dart';
export 'src/agent/agent_input_builder.dart';
export 'src/agent/duel_field_tracker.dart';
export 'src/agent/field_query.dart';
export 'src/agent/raw_field_cards.dart';
export 'src/agent/raw_maps.dart';
export 'src/code_list.dart';
export 'src/constants.dart';
export 'src/enums.dart';
export 'src/features.dart';
export 'src/legal_actions.dart' show getLegalActions, NotSupportedException;
export 'src/models.dart';
export 'src/predict.dart';
