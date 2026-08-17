/// On-device LiteRT runtime wrapper for the ygo-agent 0546_26550M model,
/// plus the model-driven auto-answerer ([AgentAutoAnswer]) wired to the
/// ocgcore [DuelEngine] auto-answer hook.
library;

export 'src/agent_auto_answer.dart';
export 'src/tflite_model.dart';
import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:ocgcore/ocgcore.dart' show CardData;

import 'src/agent_auto_answer.dart';
import 'dart:developer' as console;

import 'package:flutter/services.dart' show rootBundle;

import 'src/tflite_model.dart';

AgentRuntime? _runtime;
bool _runtimeResolved = false;

/// 已解析的运行时（未解析前为 null；解析失败也为 null）。
AgentRuntime? get runtime => _runtime;

Future<AgentAutoAnswer?> createYgoAgentLocal({
  required AgentFieldQuery field,
  CardData? Function(int code)? cardData,
  int startLp = 8000,
}) async {
  if (!_runtimeResolved) {
    _runtimeResolved = true;
    _runtime = await _loadAssetRuntime();
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

/// 从 app 资产加载内置 ygo-agent 模型（tflite + 训练码表）。
///
/// 资产声明在本包内（pubspec `assets/ygo_agent/`，符号链接指向
/// tools/ygo_agent_golden/models）。App 打包后依赖包资产 key 带
/// `packages/duelink_ai_ygo_agent_tflite/` 前缀；同时保留无前缀 key 探测，
/// 兼容 app 自行声明资产的路径。任一文件缺失 / 模型契约校验失败时返回
/// null，调用方退回规则 AI。
Future<AgentRuntime?> _loadAssetRuntime() async {
  const modelKey = 'assets/ygo_agent/0546_26550M.tflite';
  const codeListKey = 'assets/ygo_agent/code_list.txt';
  for (final prefix in const ['', 'packages/duelink_ai_ygo_agent_tflite/']) {
    try {
      final modelBytes = (await rootBundle.load(
        '$prefix$modelKey',
      )).buffer.asUint8List();
      final codeListText = await rootBundle.loadString('$prefix$codeListKey');
      final model = TfliteYgoModel.fromBytes(modelBytes);
      console.log(
        'loadAssetRuntime: ygo-agent model loaded '
        '(${modelBytes.length} bytes, code_list ${codeListText.length} chars)',
      );
      return AgentRuntime(
        modelFn: model.modelFn,
        codeList: CodeList.parse(codeListText),
        dispose: model.close,
      );
    } catch (e) {
      console.log(
        'loadAssetRuntime: ygo-agent asset miss at '
        '"$prefix$modelKey": $e',
      );
    }
  }
  console.log(
    'loadAssetRuntime: ygo-agent model unavailable, '
    'falling back to rule AI',
  );
  return null;
}
