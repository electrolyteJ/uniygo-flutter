/// Input 序列化 golden 往返测试：golden `*_input.json`（上游 Python
/// 产出的 wire 格式）经 `Input.fromJson` → `toJson` 必须逐字节等价。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:duelink_ai_ygo_agent_http/duelink_ai_ygo_agent_http.dart';

const goldenRoot = '../../tools/ygo_agent_golden/golden';

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  // 覆盖每种 action_msg 判别分支各至少一个样例。
  final cases = {
    'idlecmd_rich': 'step_00_input.json',
    'battlecmd_rich': 'step_00_input.json',
    'chain_forced_single': 'step_00_input.json',
    'select_card': 'step_00_input.json',
    'announce_attrib': 'step_00_input.json',
    'announce_number': 'step_00_input.json',
    'seq_defense_opponent_turn': 'step_00_input.json',
  };

  for (final entry in cases.entries) {
    test('${entry.key}/${entry.value} round-trips', () {
      final path = '$goldenRoot/${entry.key}/${entry.value}';
      final file = File(path);
      if (!file.existsSync()) {
        fail('missing $path; run tools/ygo_agent_golden first');
      }
      final original = _readJson(path);
      final input = Input.fromJson(original);
      final serialized = input.toJson();
      expect(serialized, equals(original));
    });
  }

  test('golden 目录覆盖到的 action_msg 类型齐全', () {
    final dir = Directory(goldenRoot);
    if (!dir.existsSync()) {
      fail('missing $goldenRoot; run tools/ygo_agent_golden first');
    }
    // 至少保证上述样例目录存在，防止路径写错静默跳过。
    for (final name in cases.keys) {
      expect(Directory('$goldenRoot/$name').existsSync(), isTrue,
          reason: 'golden case dir $name');
    }
  });
}
