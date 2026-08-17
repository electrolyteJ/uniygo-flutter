/// 远端 ygo-agent predict 服务的 HTTP 客户端。
///
/// 协议移植自 neos-ts `src/api/ygoAgent/`（create.ts / predict.ts）：
///  - `POST {server}/v0/duels`              创建对局会话
///  - `POST {server}/v0/duels/{id}/predict` 请求一步决策
///
/// 服务端按 duelId + index 维护循环状态（rstate / 历史动作），客户端
/// 只需携带完整局面快照 [Input] 与上一步动作索引，无需本地模型。
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';

import 'input_serializer.dart';

/// 默认 predict 服务地址（moecube 公共服务，neos-ts 同款）。
const kDefaultAgentServer = 'https://sapi.moecube.com:444/neos-ai-agent';

/// `createDuel` 的响应：对局会话句柄 + 初始序号。
class CreatedDuel {
  CreatedDuel({required this.duelId, required this.index});

  final String duelId;
  final int index;
}

/// `predictDuel` 的响应：下一序号 + 决策结果。
class PredictResponse {
  PredictResponse({required this.index, required this.predictResults});

  /// 恒等于请求的 index + 1。
  final int index;
  final MsgResponse predictResults;
}

/// 服务返回非 200 或响应体无法解析时抛出。
class YgoAgentApiException implements Exception {
  YgoAgentApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'YgoAgentApiException: $message'
      : 'YgoAgentApiException($statusCode): $message';
}

/// neos-ts `predictDuel` / `createDuel` 的 Dart 等价物。
class YgoAgentClient {
  YgoAgentClient({required String server, http.Client? httpClient})
      : _server = server.endsWith('/')
            ? server.substring(0, server.length - 1)
            : server,
        _http = httpClient ?? http.Client();

  /// 服务根地址，如 `https://sapi.moecube.com:444/neos-ai-agent`。
  final String _server;
  final http.Client _http;

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  /// 创建对局会话（neos-ts `createDuel`，`POST v0/duels`）。
  Future<CreatedDuel> createDuel() async {
    final resp = await _http.post(Uri.parse('$_server/v0/duels'));
    final body = _decode(resp, 'v0/duels');
    return CreatedDuel(
      duelId: body['duelId'] as String,
      index: body['index'] as int,
    );
  }

  /// 请求一步决策（neos-ts `predictDuel`，`POST v0/duels/{duelId}/predict`）。
  ///
  /// [index] 必须等于同一会话上一次响应的 index；[prevActionIdx] 是上一
  /// 步所选动作在响应空间的下标（首步传 0，与 neos-ts 初始值一致）。
  Future<PredictResponse> predictDuel(
    String duelId, {
    required int index,
    required Input input,
    required int prevActionIdx,
  }) async {
    final path = 'v0/duels/$duelId/predict';
    final resp = await _http.post(
      Uri.parse('$_server/$path'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'index': index,
        'input': input.toJson(),
        'prev_action_idx': prevActionIdx,
      }),
    );
    final body = _decode(resp, path);
    return PredictResponse(
      index: body['index'] as int,
      predictResults:
          _msgResponseFromJson(body['predict_results'] as Map<String, dynamic>),
    );
  }
}

Map<String, dynamic> _decode(http.Response resp, String path) {
  if (resp.statusCode != 200) {
    throw YgoAgentApiException(
      'POST $path failed: ${resp.body}',
      statusCode: resp.statusCode,
    );
  }
  try {
    return jsonDecode(resp.body) as Map<String, dynamic>;
  } on FormatException catch (e) {
    throw YgoAgentApiException('POST $path invalid JSON: $e');
  }
}

MsgResponse _msgResponseFromJson(Map<String, dynamic> json) {
  final preds = (json['action_preds'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map((p) => ActionPredict(
            prob: (p['prob'] as num).toDouble(),
            response: p['response'] as int,
            canFinish: p['can_finish'] as bool,
          ))
      .toList();
  return MsgResponse(
    actionPreds: preds,
    winRate: (json['win_rate'] as num).toDouble(),
  );
}
