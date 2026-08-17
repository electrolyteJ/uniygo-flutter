/// [RemoteAgentAutoAnswerFactory] 测试：默认装配可用；clientOverride
/// 注入时走 mock 服务（resetDuel 触发 createDuel）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:duelink_ai_ygo_agent_http/duelink_ai_ygo_agent_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeField implements AgentFieldQuery {
  @override
  int fieldCount(int player, int location) => 0;

  @override
  Uint8List fieldCards(int player, int location, int queryFlag) =>
      Uint8List(0);
}

void main() {
  test('默认装配：create 返回可用的应答器', () {
    final factory = RemoteAgentAutoAnswerFactory();
    final answerer =
        factory.create(field: _FakeField());
    expect(answerer, isA<RemoteAgentAutoAnswer>());
    expect(answerer.broken, isFalse);
  });

  test('clientOverride：resetDuel 经注入客户端创建服务端会话', () async {
    var createCalls = 0;
    final mock = MockClient((req) async {
      expect(req.url.path.endsWith('/v0/duels'), isTrue);
      createCalls++;
      return http.Response(jsonEncode({'duelId': 'd1', 'index': 0}), 200);
    });
    final factory = RemoteAgentAutoAnswerFactory(
      clientOverride:
          YgoAgentClient(server: 'https://fake.test/agent', httpClient: mock),
    );
    final answerer =
        factory.create(field: _FakeField());
    await answerer.resetDuel();
    expect(createCalls, 1);
  });
}
