/// [RemoteAgentAutoAnswer] 测试：mock HTTP predict 服务（受控
/// action_preds 队列），验证单步/多选/选格子应答字节、序号 threading
/// （index / prev_action_idx / selected 回写）与断裂回退语义。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:duelink/duelink.dart' show BufferReader, BufferWriter;
import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:duelink_ai_ygo_agent_http/duelink_ai_ygo_agent_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ocgcore/ocgcore.dart';

// ───────────────────────── 假场态（同 agent_auto_answer_test） ─────────

class FakeField implements AgentFieldQuery {
  final Map<(int, int), Uint8List> buffers = {};

  @override
  int fieldCount(int player, int location) => 0;

  @override
  Uint8List fieldCards(int player, int location, int queryFlag) =>
      buffers[(player, location)] ?? Uint8List(0);
}

// ───────────────────────── 载荷构造 ─────────────────────────

Uint8List idleCmdPayload() {
  final w = BufferWriter();
  w.writeUint8(1); // player
  w.writeUint8(1); // summon ×1
  w.writeUint32(100);
  w.writeUint8(1);
  w.writeUint8(LOCATION_MZONE);
  w.writeUint8(2);
  for (var i = 0; i < 5; i++) {
    w.writeUint8(0); // sp_summon/repos/mset/set/activate 计数
  }
  w.writeUint8(1); // to_bp
  w.writeUint8(0); // to_ep
  w.writeUint8(1); // can_shuffle
  return w.toBytes();
}

Uint8List selectCardPayload({int min = 1, int max = 2, int count = 3}) {
  final w = BufferWriter();
  w.writeUint8(1); // player
  w.writeUint8(0); // cancelable
  w.writeUint8(min);
  w.writeUint8(max);
  w.writeUint8(count);
  for (var i = 0; i < count; i++) {
    w.writeUint32(500 + i);
    w.writeUint8(1);
    w.writeUint8(LOCATION_MZONE);
    w.writeUint8(i);
    w.writeUint8(POS_FACEUP_ATTACK);
  }
  return w.toBytes();
}

Uint8List sumPayload() {
  final w = BufferWriter();
  w.writeUint8(0); // mode → 非 overflow
  w.writeUint8(1); // player
  w.writeInt32(4); // level sum
  w.writeUint8(1); // min
  w.writeUint8(2); // max
  w.writeUint8(0); // must count
  w.writeUint8(3); // selectable count：level1 = 4 / 2 / 2
  final levels = [4, 2, 2];
  for (var i = 0; i < 3; i++) {
    w.writeUint32(800 + i);
    w.writeUint8(1);
    w.writeUint8(LOCATION_MZONE);
    w.writeUint8(i);
    w.writeUint32(levels[i]);
  }
  return w.toBytes();
}

Uint8List placePayload() {
  final w = BufferWriter();
  w.writeUint8(1); // player
  w.writeUint8(0); // count → 1
  // byte0 我方怪兽区 bit0 清除（m1）；byte2 对方怪兽区 bit2 清除（om3）
  final flag = 0xfe | (0xff << 8) | (0xfb << 16) | (0xff << 24);
  w.writeUint32(flag);
  return w.toBytes();
}

Uint8List unselectPayload() {
  final w = BufferWriter();
  w.writeUint8(1); // player
  w.writeUint8(1); // finishable
  w.writeUint8(0); // cancelable
  w.writeUint8(1); // min
  w.writeUint8(1); // max
  w.writeUint8(2); // selectable count
  for (var i = 0; i < 2; i++) {
    w.writeUint32(700 + i);
    w.writeUint8(1);
    w.writeUint8(LOCATION_HAND);
    w.writeUint8(i);
    w.writeUint8(POS_FACEDOWN);
  }
  w.writeUint8(0); // selected count
  return w.toBytes();
}

// ───────────────────────── mock predict 服务 ─────────────────────────

/// 一条 action_preds 简写：(prob, response, canFinish)。
typedef PredSpec = (double, int, bool);

class FakeAgentServer {
  FakeAgentServer();

  /// 每次 predict 调用依次消费的 preds 队列。
  final predictQueue = <List<PredSpec>>[];

  /// 收到的 predict 请求体（按序）。
  final predictRequests = <Map<String, dynamic>>[];

  int createCalls = 0;
  int nextIndex = 0;
  bool failPredict = false;

  http.Client client() => MockClient((req) async {
        if (req.url.path.endsWith('/v0/duels')) {
          createCalls++;
          nextIndex = 0;
          return http.Response(
              jsonEncode({'duelId': 'd$createCalls', 'index': 0}), 200);
        }
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        predictRequests.add(body);
        if (failPredict) {
          return http.Response('server boom', 500);
        }
        final preds = predictQueue.removeAt(0);
        nextIndex = (body['index'] as int) + 1;
        return http.Response(
          jsonEncode({
            'index': nextIndex,
            'predict_results': {
              'action_preds': [
                for (final p in preds)
                  {'prob': p.$1, 'response': p.$2, 'can_finish': p.$3},
              ],
              'win_rate': 0.5,
            },
          }),
          200,
        );
      });
}

class Harness {
  Harness(this.server) {
    autoAnswer = RemoteAgentAutoAnswer(
      session: RemotePredictSession(
        client: YgoAgentClient(server: 'https://fake.test/agent',
            httpClient: server.client()),
      ),
      field: field,
    );
  }

  final FakeAgentServer server;
  final FakeField field = FakeField();
  late final RemoteAgentAutoAnswer autoAnswer;

  Future<void> start() => autoAnswer.resetDuel();
}

int int32Of(Uint8List bytes) => BufferReader(bytes).readInt32();

/// predict 请求体 action_msg.data 的便捷访问。
Map<String, dynamic> actionDataOf(Map<String, dynamic> req) =>
    ((req['input'] as Map<String, dynamic>)['action_msg']
        as Map<String, dynamic>)['data'] as Map<String, dynamic>;

void main() {
  group('RemoteAgentAutoAnswer 单步消息', () {
    test('idlecmd：argmax 选 to_bp → int32 = response；序号 threading', () async {
      final server = FakeAgentServer();
      server.predictQueue.add([
        (0.3, 0, false), // summon
        (0.7, 6, false), // to_bp
      ]);
      final h = Harness(server);
      await h.start();
      expect(server.createCalls, 1);

      final resp = await h.autoAnswer.answer(MSG_SELECT_IDLECMD,
          idleCmdPayload());
      expect(int32Of(resp!), 6);

      // 请求体：index 0（create 返回）、prev_action_idx 0（首步）。
      final req = server.predictRequests.single;
      expect(req['index'], 0);
      expect(req['prev_action_idx'], 0);
      expect(actionDataOf(req)['msg_type'], 'select_idlecmd');
    });

    test('place：argmax 选对方怪兽区 om3 → [plr=0][MZONE][seq2]', () async {
      final server = FakeAgentServer();
      server.predictQueue.add([
        (0.4, 0, false), // m1（我方 mzone seq0）
        (0.6, 1, false), // om3（对方 mzone seq2）
      ]);
      final h = Harness(server);
      await h.start();

      final resp =
          await h.autoAnswer.answer(MSG_SELECT_PLACE, placePayload());
      expect(resp, [0, LOCATION_MZONE, 2]);
    });

    test('unselect：response -1 → int32(-1)；否则 [1][response]', () async {
      final server = FakeAgentServer();
      server.predictQueue.add([
        (0.9, -1, false), // finish
        (0.1, 0, false),
        (0.2, 1, false),
      ]);
      server.predictQueue.add([
        (0.1, -1, false),
        (0.9, 1, false), // 选第二张
        (0.2, 0, false),
      ]);
      final h = Harness(server);
      await h.start();

      final r1 =
          await h.autoAnswer.answer(MSG_SELECT_UNSELECT_CARD, unselectPayload());
      expect(int32Of(r1!), -1);

      final r2 =
          await h.autoAnswer.answer(MSG_SELECT_UNSELECT_CARD, unselectPayload());
      expect(r2, [1, 1]);
    });
  });

  group('RemoteAgentAutoAnswer 多选驱动', () {
    test('select_card：选一张后 response -1 结束；selected 回写进下一请求',
        () async {
      final server = FakeAgentServer();
      server.predictQueue.add([
        (0.1, 0, false),
        (0.8, 1, false), // 选卡 1
        (0.1, 2, false),
        (0.0, -1, false),
      ]);
      server.predictQueue.add([
        (0.1, 0, false),
        (0.1, 1, false),
        (0.1, 2, false),
        (0.9, -1, false), // finish
      ]);
      final h = Harness(server);
      await h.start();

      final resp = await h.autoAnswer.answer(
          MSG_SELECT_CARD, selectCardPayload());
      expect(resp, [1, 1]); // [count=1][response=1]

      // 第二次请求的 msg.selected 记录了第一次所选的 preds 下标（= 卡 1）。
      final second = server.predictRequests[1];
      expect(actionDataOf(second)['selected'], [1]);
      // prev_action_idx 是第一次所选的 preds 下标。
      expect(second['prev_action_idx'], 1);
    });

    test('select_card：达到 max 强制结束', () async {
      final server = FakeAgentServer();
      for (final pick in [0, 2]) {
        server.predictQueue.add([
          (0.9, pick, false),
          (0.05, 1, false),
          (0.05, pick == 0 ? 2 : 0, false),
          (0.0, -1, false),
        ]);
      }
      final h = Harness(server);
      await h.start();

      final resp = await h.autoAnswer.answer(
          MSG_SELECT_CARD, selectCardPayload(max: 2));
      expect(resp, [2, 0, 2]);
      expect(server.predictRequests, hasLength(2));
    });

    test('select_sum：canFinish 即结束，[must+n][must 占位][idx...]', () async {
      final server = FakeAgentServer();
      server.predictQueue.add([
        (0.7, 1, true), // 选 level2 卡 1，完成组合
        (0.2, 2, false),
        (0.1, 0, false),
      ]);
      final h = Harness(server);
      await h.start();

      final resp =
          await h.autoAnswer.answer(MSG_SELECT_SUM, sumPayload());
      expect(resp, [1, 1]); // must=0，选 1 张（response=1）
    });
  });

  group('RemoteAgentAutoAnswer 确定性与回退', () {
    test('sort_card：直接 [0xff]，不发起 HTTP', () async {
      final server = FakeAgentServer();
      final h = Harness(server);
      await h.start();

      final sortPayload = BufferWriter()
        ..writeUint8(1) // player
        ..writeUint8(2) // count
        ..writeUint32(1)
        ..writeUint32(0);
      final resp =
          await h.autoAnswer.answer(MSG_SORT_CARD, sortPayload.toBytes());
      expect(resp, [0xff]);
      expect(server.predictRequests, isEmpty);
    });

    test('HTTP 失败 → 返回 null 且本局熔断（后续不再请求）', () async {
      final server = FakeAgentServer()..failPredict = true;
      final h = Harness(server);
      await h.start();

      final r1 = await h.autoAnswer.answer(
          MSG_SELECT_IDLECMD, idleCmdPayload());
      expect(r1, isNull);
      expect(h.autoAnswer.broken, isTrue);
      expect(server.predictRequests, hasLength(1));

      // 熔断后不再请求远端，直接返回 null。
      final r2 = await h.autoAnswer.answer(
          MSG_SELECT_IDLECMD, idleCmdPayload());
      expect(r2, isNull);
      expect(server.predictRequests, hasLength(1));
    });

    test('resetDuel 重建会话：重新 createDuel 并解除熔断', () async {
      final server = FakeAgentServer()..failPredict = true;
      final h = Harness(server);
      await h.start();
      await h.autoAnswer.answer(MSG_SELECT_IDLECMD, idleCmdPayload());
      expect(h.autoAnswer.broken, isTrue);

      server.failPredict = false;
      server.predictQueue.add([
        (0.7, 6, false),
        (0.3, 0, false),
      ]);
      await h.autoAnswer.resetDuel();
      expect(server.createCalls, 2);
      expect(h.autoAnswer.broken, isFalse);

      final resp = await h.autoAnswer.answer(
          MSG_SELECT_IDLECMD, idleCmdPayload());
      expect(int32Of(resp!), 6);
    });
  });
}
