/// 内置模型资产加载：从打包资产读取 tflite 模型与训练码表，
/// 组装端侧推理运行时 [AgentRuntime]。
library;

import 'dart:developer' as console;

import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart' show CodeList;
import 'package:flutter/services.dart' show rootBundle;

import 'agent_auto_answer.dart';
import 'src/tflite_model.dart';

/// 从 app 资产加载内置 ygo-agent 模型（tflite + 训练码表）。
///
/// 资产声明在本包内（pubspec `assets/ygo_agent/`，符号链接指向
/// tools/ygo_agent_golden/models）。App 打包后依赖包资产 key 带
/// `packages/duelink_ai_ygo_agent_tflite/` 前缀；同时保留无前缀 key 探测，
/// 兼容 app 自行声明资产的路径。任一文件缺失 / 模型契约校验失败时返回
/// null，调用方退回规则 AI。
Future<AgentRuntime?> loadAssetRuntime() async {
  const modelKey = 'assets/ygo_agent/0546_26550M.tflite';
  const codeListKey = 'assets/ygo_agent/code_list.txt';
  for (final prefix in const ['', 'packages/duelink_ai_ygo_agent_tflite/']) {
    try {
      final modelBytes =
          (await rootBundle.load('$prefix$modelKey')).buffer.asUint8List();
      final codeListText = await rootBundle.loadString('$prefix$codeListKey');
      final model = TfliteYgoModel.fromBytes(modelBytes);
      console.log('loadAssetRuntime: ygo-agent model loaded '
          '(${modelBytes.length} bytes, code_list ${codeListText.length} chars)');
      return AgentRuntime(
        modelFn: model.modelFn,
        codeList: CodeList.parse(codeListText),
        dispose: model.close,
      );
    } catch (e) {
      console.log('loadAssetRuntime: ygo-agent asset miss at '
          '"$prefix$modelKey": $e');
    }
  }
  console.log('loadAssetRuntime: ygo-agent model unavailable, '
      'falling back to rule AI');
  return null;
}
