import 'dart:async';

import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:duelink_ai_ygo_agent_http/duelink_ai_ygo_agent_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// 永不完成的 http client：模拟服务端接受连接但永不响应（丢包/挂死）。
class _HangClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Completer<http.StreamedResponse>().future;
  }
}

Input _minimalInput() => Input(
      global: Global(
        myLp: 8000,
        opLp: 8000,
        turn: 1,
        phase: Phase.draw,
        isFirst: false,
        isMyTurn: true,
      ),
      cards: const [],
      actionMsg: ActionMsg(data: MsgSelectYesNo(effectDescription: 0)),
    );

void main() {
  group('YgoAgentClient 超时', () {
    test('createDuel 服务端挂死时按超时失败（不永久等待）', () async {
      final client = YgoAgentClient(
        server: 'https://example.com',
        httpClient: _HangClient(),
        timeout: const Duration(milliseconds: 300),
      );
      await expectLater(
        client.createDuel(),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('predictDuel 服务端挂死时按超时失败（不永久等待）', () async {
      final client = YgoAgentClient(
        server: 'https://example.com',
        httpClient: _HangClient(),
        timeout: const Duration(milliseconds: 300),
      );
      await expectLater(
        client.predictDuel(
          'duel-id',
          index: 0,
          input: _minimalInput(),
          prevActionIdx: 0,
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
