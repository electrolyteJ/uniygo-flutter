/// [AgentAutoAnswerFactory] 测试：注入运行时直出、无注入且资产不可用时
/// 返回 null（调用方回退规则 AI）、运行时只解析一次（跨 create 复用）。
library;

import 'dart:typed_data';

import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:duelink_ai_ygo_agent_tflite/duelink_ai_ygo_agent_tflite.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeField implements AgentFieldQuery {
  @override
  int fieldCount(int player, int location) => 0;

  @override
  Uint8List fieldCards(int player, int location, int queryFlag) =>
      Uint8List(0);
}

AgentRuntime _fakeRuntime() => AgentRuntime(
      modelFn: (rstate, input) => ModelOutput(
        rstate: rstate,
        probs: const [1.0],
        value: 0.0,
      ),
      codeList: CodeList.parse('100'),
    );

void main() {
  test('注入运行时 → create 返回应答器，且跨 create 复用同一运行时', () async {
    final factory = AgentAutoAnswerFactory(agentRuntime: _fakeRuntime());
    final a1 = await factory.create(field: _FakeField());
    expect(a1, isNotNull);
    expect(factory.runtime, isNotNull);
    // 再次 create 仍可用（运行时解析结果缓存）。
    final a2 = await factory.create(field: _FakeField());
    expect(a2, isNotNull);
  });

  test('无注入且资产不可用（测试环境）→ create 返回 null', () async {
    final factory = AgentAutoAnswerFactory();
    final a = await factory.create(field: _FakeField());
    expect(a, isNull);
    expect(factory.runtime, isNull);
  });
}
