/// YgoAgentClient / RemotePredictSession 的 mock HTTP 测试。
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:duelink_ai_ygo_agent_http/duelink_ai_ygo_agent_http.dart';

const server = 'https://example.com/neos-ai-agent';

Input _sampleInput() => Input(
      global: Global(
        myLp: 8000,
        opLp: 7400,
        turn: 3,
        phase: Phase.main1,
        isFirst: true,
        isMyTurn: true,
      ),
      cards: [
        Card(
          code: 89631139,
          location: Location.hand,
          sequence: 0,
          controller: Controller.me,
          position: Position.facedown,
          overlaySequence: -1,
          attribute: Attribute.light,
          race: Race.dragon,
          level: 8,
          counter: 0,
          negated: false,
          attack: 3000,
          defense: 2500,
          types: [CardType.monster, CardType.normal],
        ),
      ],
      actionMsg: ActionMsg(
        data: MsgSelectYesNo(effectDescription: 123),
      ),
    );

Map<String, dynamic> _predictResponseBody(int index) => {
      'index': index,
      'predict_results': {
        'action_preds': [
          {'prob': 0.8, 'response': 1, 'can_finish': false},
          {'prob': 0.2, 'response': 0, 'can_finish': false},
        ],
        'win_rate': 0.65,
      },
    };

void main() {
  group('YgoAgentClient', () {
    test('createDuel POST v0/duels 并解析响应', () async {
      final mock = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.toString(), '$server/v0/duels');
        return http.Response(
            jsonEncode({'duelId': 'duel-1', 'index': 7}), 200);
      });
      final client = YgoAgentClient(server: server, httpClient: mock);
      final created = await client.createDuel();
      expect(created.duelId, 'duel-1');
      expect(created.index, 7);
    });

    test('predictDuel 序列化请求体并解析 action_preds', () async {
      final mock = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.toString(), '$server/v0/duels/duel-1/predict');
        expect(req.headers['Content-Type'], 'application/json');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['index'], 7);
        expect(body['prev_action_idx'], 2);
        final input = body['input'] as Map<String, dynamic>;
        expect(input['global'], {
          'my_lp': 8000,
          'op_lp': 7400,
          'turn': 3,
          'phase': 'main1',
          'is_first': true,
          'is_my_turn': true,
        });
        expect((input['cards'] as List).single, {
          'code': 89631139,
          'location': 'hand',
          'sequence': 0,
          'controller': 'me',
          'position': 'facedown',
          'overlay_sequence': -1,
          'attribute': 'light',
          'race': 'dragon',
          'level': 8,
          'counter': 0,
          'negated': false,
          'attack': 3000,
          'defense': 2500,
          'types': ['monster', 'normal'],
        });
        expect(input['action_msg'], {
          'data': {'msg_type': 'select_yesno', 'effect_description': 123},
        });
        return http.Response(jsonEncode(_predictResponseBody(8)), 200);
      });
      final client = YgoAgentClient(server: server, httpClient: mock);
      final resp = await client.predictDuel(
        'duel-1',
        index: 7,
        input: _sampleInput(),
        prevActionIdx: 2,
      );
      expect(resp.index, 8);
      expect(resp.predictResults.winRate, 0.65);
      expect(resp.predictResults.actionPreds, hasLength(2));
      expect(resp.predictResults.actionPreds[0].prob, 0.8);
      expect(resp.predictResults.actionPreds[0].response, 1);
      expect(resp.predictResults.actionPreds[0].canFinish, isFalse);
    });

    test('server 末尾斜杠会被剥掉', () async {
      final mock = MockClient((req) async {
        expect(req.url.toString(), '$server/v0/duels');
        return http.Response(jsonEncode({'duelId': 'd', 'index': 0}), 200);
      });
      final client = YgoAgentClient(server: '$server/', httpClient: mock);
      await client.createDuel();
    });

    test('非 200 响应抛 YgoAgentApiException（含状态码）', () async {
      final mock = MockClient((req) async => http.Response('boom', 500));
      final client = YgoAgentClient(server: server, httpClient: mock);
      await expectLater(
        client.createDuel(),
        throwsA(isA<YgoAgentApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('响应体非法 JSON 抛 YgoAgentApiException', () async {
      final mock = MockClient((req) async => http.Response('not json', 200));
      final client = YgoAgentClient(server: server, httpClient: mock);
      await expectLater(
        client.createDuel(),
        throwsA(isA<YgoAgentApiException>()),
      );
    });
  });

  group('RemotePredictSession', () {
    test('start → predict 串行推进 index / prevActionIdx', () async {
      final seen = <Map<String, dynamic>>[];
      final mock = MockClient((req) async {
        if (req.url.path.endsWith('/v0/duels')) {
          return http.Response(jsonEncode({'duelId': 'd1', 'index': 0}), 200);
        }
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        seen.add(body);
        final next = (body['index'] as int) + 1;
        return http.Response(jsonEncode(_predictResponseBody(next)), 200);
      });
      final session = RemotePredictSession(
        client: YgoAgentClient(server: server, httpClient: mock),
      );

      expect(() => session.predict(_sampleInput()), throwsStateError);

      await session.start();
      expect(session.duelId, 'd1');
      expect(session.index, 0);

      await session.predict(_sampleInput());
      expect(session.index, 1);
      expect(seen[0]['index'], 0);
      expect(seen[0]['prev_action_idx'], 0);

      session.recordChoice(1);
      await session.predict(_sampleInput());
      expect(session.index, 2);
      expect(seen[1]['index'], 1);
      expect(seen[1]['prev_action_idx'], 1);
    });
  });
}
