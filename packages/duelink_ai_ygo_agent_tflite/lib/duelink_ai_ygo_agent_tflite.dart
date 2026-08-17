/// On-device LiteRT runtime wrapper for the ygo-agent 0546_26550M model,
/// plus the model-driven auto-answerer ([AgentAutoAnswer]) wired to the
/// ocgcore [DuelEngine] auto-answer hook.
library;

export 'agent_auto_answer.dart';
export 'agent_factory.dart';
export 'asset_runtime.dart';
export 'src/tflite_model.dart';
