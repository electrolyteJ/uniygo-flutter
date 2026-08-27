import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ygo_deck_server/http_utils.dart';
import 'package:ygo_deck_server/models/deck_dto.dart';
import 'package:ygo_deck_server/services/deck_store.dart';

/// GET /decks/:key —— 卡组详情（IDeckService.loadDeck，不存在 404）
/// PUT /decks/:key —— 保存卡组（body 为卡组 JSON，key 为准）
/// DELETE /decks/:key —— 删除卡组（IDeckService.deleteDeck）
Future<Response> onRequest(RequestContext context, String key) async {
  final store = context.read<DeckStore>();
  // dart_frog 路由参数不做 URL 解码，这里统一解码（中文卡组名）。
  final name = DeckStore.decodeRouteKey(key);
  try {
    DeckStore.validateKey(name);
  } on InvalidDeckKeyException {
    return jsonError(HttpStatus.badRequest, '卡组 key 非法');
  }

  switch (context.request.method) {
    case HttpMethod.get:
      final deck = await store.read(name);
      if (deck == null) {
        return jsonError(HttpStatus.notFound, '卡组不存在: $name');
      }
      return Response.json(body: deck.toJson());
    case HttpMethod.put:
      return _save(context, store, name);
    case HttpMethod.delete:
      final existed = await store.delete(name);
      if (!existed) {
        return jsonError(HttpStatus.notFound, '卡组不存在: $name');
      }
      return jsonSuccess();
    default:
      return jsonError(HttpStatus.methodNotAllowed, 'Method not allowed');
  }
}

Future<Response> _save(
  RequestContext context,
  DeckStore store,
  String key,
) async {
  final Object? body;
  try {
    body = await context.request.json();
  } on FormatException {
    return jsonError(HttpStatus.badRequest, '请求体不是合法 JSON');
  }
  if (body is! Map<String, dynamic>) {
    return jsonError(HttpStatus.badRequest, '请求体必须是卡组 JSON 对象');
  }
  final deck = DeckDto.fromJson(body)..deckName = key; // 路径 key 为权威名
  await store.save(deck);
  return jsonSuccess();
}
