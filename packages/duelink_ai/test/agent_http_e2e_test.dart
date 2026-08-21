// 远端 ygo-agent predict 链路（createYgoAgentHttp）的端到端测试。
//
// 公共服务 `sapi.moecube.com:444/neos-ai-agent` 历史上出现过不可用
// （后端挂起无响应）。本测试用本地 mock 服务器实现 neos-ai-agent 协议
// （POST /v0/duels 建会话、POST /v0/duels/{id}/predict 出决策），
// 验证「HTTP 客户端 → 会话簿记 → 远端自动应答 → 引擎接受」整条链路。
//
// mock 的决策策略是「被动但合法」：优先召唤/攻击（走通核心路径），
// 连锁/发动一律放弃；所有应答值直接取自请求 input 里携带的合法
// response 字段（与真实模型服务同一语义空间）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:duelink_ai/duelink_ai.dart';
import 'package:duelink_ai_ygo_agent_http/duelink_ai_ygo_agent_http.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test 默认拦截所有 HttpClient（返回 400 假响应），
  // 本测试需要真实访问本地 mock 服务，恢复真实 HttpClient。
  HttpOverrides.global = _RealHttpOverrides();

  test(
    '远端 predict 链路 E2E：mock 服务驱动 AI 完成整局对击败人类',
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      // ---- 启动 mock neos-ai-agent 服务 ----
      final mock = _MockAgentServer();
      final port = await mock.start();
      addTearDown(mock.stop);

      final service = AiDuelService(
        lib: loadCoreLib(),
        scriptLoader: FileScriptLoader(),
      );
      injectTestCards(service);
      // AI 固定出剪刀(1)，人类石头必胜 → 确定性走 SELECT_TP 分支
      service.fixedAiHandChoice = 1;
      final allMsgs = <YgoStocMsg>[];
      final cursor = MsgCursor(allMsgs);
      final msgSub = service.onServerMessage.listen(allMsgs.add);

      addTearDown(() async {
        await msgSub.cancel();
        await service.disconnect();
      });

      // ---- agent=1 + 自定义 agentServer → 走 mock 远端 ----
      final uri = Uri(
        scheme: 'ai',
        host: 'localhost',
        port: 8080,
        queryParameters: {
          'agent': '1',
          'agentServer': 'http://127.0.0.1:$port/neos-ai-agent',
        },
      );
      await service.connect(uri);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.connectionState, ConnectionState.connected);

      final answerer = service.agentAnswerer;
      expect(
        answerer,
        isA<RemoteAgentAutoAnswer>(),
        reason: 'agent=1 应装配远端模型应答器',
      );
      final remote = answerer! as RemoteAgentAutoAnswer;

      // ---- 房间流程：进房 → 提交卡组 → 准备 → 开局 → 猜拳 → 先攻 ----
      service.setPlayerName('HttpE2E');
      service.enterRoom(RoomPassword.encodeJoin());
      service.submitDeck(encodeDeck(buildTestDeck()), Uint8List(0));
      service.ready();
      service.startDuel();

      final selectHand = await cursor.waitFor(
        (m) => m.protoId == STOC_SELECT_HAND,
        timeout: const Duration(seconds: 5),
      );
      expect(selectHand, isNotNull, reason: 'startDuel 后应进入猜拳');
      service.chooseHand(HandType.rock);

      await cursor.waitFor(
        (m) => m.protoId == STOC_SELECT_TP,
        timeout: const Duration(seconds: 5),
      );
      service.chooseTurnOrder(true);

      // ---- 人类自动驾驶（被动结束回合），AI 由远端 mock 驱动 ----
      final ended = await autopilotUntilDuelEnd(
        service,
        cursor,
        timeout: const Duration(minutes: 2),
      );

      // ---- 断言 ----
      expect(
        mock.createDuelCount,
        1,
        reason: '开局前应创建一次远端对局会话（resetDuel → createDuel）',
      );
      expect(
        mock.predictCount,
        greaterThan(0),
        reason: 'AI 回合应产生远端 predict 请求',
      );
      expect(
        remote.successCount,
        greaterThan(0),
        reason: '远端模型应至少成功应答一次（未落入规则兜底）',
      );
      expect(
        remote.broken,
        isFalse,
        reason: '整局下来远端链路不应断裂（broken=true 说明有应答失败）',
      );
      expect(
        ended,
        isTrue,
        reason: '对局应正常结束（AI 持续攻击直至 LP 归零）',
      );
      // AI（player 1）确实行动过：mock 至少收到过 idle/battle 指令的 predict。
      expect(
        mock.predictedMsgTypes,
        contains(anyOf('select_idlecmd', 'select_battlecmd')),
        reason: '远端应实际驱动过 AI 的回合级指令',
      );

      print(
        '远端 E2E 统计: createDuel=${mock.createDuelCount} '
        'predict=${mock.predictCount} 成功应答=${remote.successCount} '
        '消息类型=${mock.predictedMsgTypes.toSet().toList()}',
      );
    },
  );
}

/// 恢复 flutter_test 拦截前的真实 HttpClient 行为。
class _RealHttpOverrides extends HttpOverrides {}

/// 本地 mock neos-ai-agent 服务：实现 createDuel/predict 两个端点，
/// 应答值取自请求 input 中的合法 response（被动策略）。
class _MockAgentServer {
  HttpServer? _server;

  int createDuelCount = 0;
  int predictCount = 0;

  /// 收到过 predict 的消息类型（msg_type），按到达顺序记录。
  final List<String> predictedMsgTypes = [];

  Future<int> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle);
    return server.port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }

  Future<void> _handle(HttpRequest req) async {
    final body = await utf8.decoder.bind(req).join();
    try {
      if (req.method == 'POST' && req.uri.path.endsWith('/v0/duels')) {
        createDuelCount++;
        await _json(req.response, {'duelId': 'mock-duel-1', 'index': 0});
      } else if (req.method == 'POST' && req.uri.path.endsWith('/predict')) {
        predictCount++;
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        await _json(req.response, _mockPredict(decoded));
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    } catch (e) {
      req.response.statusCode = 500;
      await req.response.close();
    }
  }

  Future<void> _json(HttpResponse resp, Map<String, dynamic> data) async {
    resp
      ..statusCode = 200
      ..headers.contentType = ContentType.json;
    resp.write(jsonEncode(data));
    await resp.close();
  }

  /// 为请求的 input 构造「被动但合法」的 action_preds。
  Map<String, dynamic> _mockPredict(Map<String, dynamic> req) {
    final input = req['input'] as Map<String, dynamic>;
    final data = input['action_msg']['data'] as Map<String, dynamic>;
    final type = data['msg_type'] as String;
    predictedMsgTypes.add(type);
    return {
      'index': (req['index'] as int) + 1,
      'predict_results': {
        'action_preds': _predsFor(type, data),
        'win_rate': 0.5,
      },
    };
  }

  List<Map<String, dynamic>> _predsFor(String type, Map<String, dynamic> d) {
    Map<String, dynamic> pred(int response, {double prob = 1.0}) =>
        {'prob': prob, 'response': response, 'can_finish': true};

    switch (type) {
      case 'select_idlecmd':
        final cmds = d['idle_cmds'] as List;
        final preds = <Map<String, dynamic>>[];
        var preferred = -1;
        for (var i = 0; i < cmds.length; i++) {
          final c = cmds[i] as Map<String, dynamic>;
          final data = c['data'];
          final response = data != null
              ? data['response'] as int
              // to_bp / to_ep 无 data，协议固定值 6 / 7
              : (c['cmd_type'] == 'to_bp' ? 6 : 7);
          final isCardCmd = data != null;
          if (isCardCmd && preferred < 0) preferred = i;
          preds.add(pred(response, prob: isCardCmd ? 0.6 : 0.4));
        }
        // 优先出第一张卡指令（召唤/盖放/发动），无卡可出才转阶段
        if (preferred >= 0) preds[preferred]['prob'] = 0.9;
        return preds;

      case 'select_battlecmd':
        final cmds = d['battle_cmds'] as List;
        final preds = <Map<String, dynamic>>[];
        for (var i = 0; i < cmds.length; i++) {
          final c = cmds[i] as Map<String, dynamic>;
          final data = c['data'];
          final response = data != null
              ? data['response'] as int
              // to_m2 / to_ep 无 data，协议固定值 2 / 3
              : (c['cmd_type'] == 'to_m2' ? 2 : 3);
          preds.add(pred(response, prob: data != null ? 0.9 : 0.4));
        }
        return preds;

      case 'select_chain':
        // 被动：可放弃时一律不连锁；强制连锁选第一项。
        final forced = d['forced'] as bool;
        final chains = d['chains'] as List;
        if (!forced || chains.isEmpty) return [pred(-1)];
        return [pred(chains.first['response'] as int)];

      case 'select_effectyn':
        return [pred(0)]; // 不发动
      case 'select_yesno':
        return [pred(1)]; // 是

      case 'select_position':
        final positions = d['positions'] as List;
        return [pred(positions.first as int)];

      case 'select_option':
        final options = d['options'] as List;
        return [pred(options.first['response'] as int)];

      case 'select_place':
      case 'select_disfield':
        // preds 与 places 一一对应，客户端按命中下标回查 places。
        final places = d['places'] as List;
        return [
          for (var i = 0; i < places.length; i++)
            pred(0, prob: i == 0 ? 1.0 : 0.0),
        ];

      case 'select_card':
      case 'select_tribute':
        // 多选驱动：preds 与 cards 一一对应（pred 下标即卡下标），
        // 末位追加「完成」动作（response -1）。未选过的卡给正概率
        // （argmax 跳过 prob == -1），选够 min 后完成动作给最高概率。
        final cards = d['cards'] as List;
        final selected = (d['selected'] as List).cast<int>();
        final min = d['min'] as int;
        final preds = <Map<String, dynamic>>[
          for (var i = 0; i < cards.length; i++)
            {
              'prob': selected.contains(i) ? -1.0 : 0.3,
              'response': cards[i]['response'] as int,
              'can_finish': false,
            },
        ];
        preds.add({
          'prob': selected.length >= min ? 0.9 : -1.0,
          'response': -1,
          'can_finish': true,
        });
        return preds;

      case 'select_sum':
        // 贪心首卡即完成（测试卡组不会走到这；走了也有规则兜底）。
        final cards = d['cards'] as List;
        return [
          for (var i = 0; i < cards.length; i++)
            {
              'prob': i == 0 ? 1.0 : -1.0,
              'response': cards[i]['response'] as int,
              'can_finish': i == 0,
            },
        ];

      case 'select_unselect_card':
        final finishable = d['finishable'] as bool;
        final selectable = d['selectable_cards'] as List;
        if (finishable || selectable.isEmpty) return [pred(-1)];
        return [pred(selectable.first['response'] as int)];

      case 'announce_attrib':
        final attrs = d['attributes'] as List;
        return [pred(attrs.first['response'] as int)];
      case 'announce_number':
        final numbers = d['numbers'] as List;
        return [pred(numbers.first['response'] as int)];
    }
    throw StateError('mock server: unhandled msg_type $type');
  }
}
