import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ygo_deck_server/http_utils.dart';
import 'package:ygo_deck_server/models/deck_dto.dart';
import 'package:ygo_deck_server/services/deck_store.dart';

/// GET /decks —— 卡组列表（IDeckService.loadDeckList）
/// POST /decks —— 保存卡组（body 为卡组 JSON，deckName 为 key）
Future<Response> onRequest(RequestContext context) async {
  final store = context.read<DeckStore>();
  switch (context.request.method) {
    case HttpMethod.get:
      final decks = await store.list();
      return Response.json(body: decks.map((d) => d.toJson()).toList());
    case HttpMethod.post:
      return _save(context, store);
    default:
      return jsonError(HttpStatus.methodNotAllowed, 'Method not allowed');
  }
}

Future<Response> _save(RequestContext context, DeckStore store) async {
  final Object? body;
  try {
    body = await context.request.json();
  } on FormatException {
    return jsonError(HttpStatus.badRequest, '请求体不是合法 JSON');
  }
  if (body is! Map<String, dynamic>) {
    return jsonError(HttpStatus.badRequest, '请求体必须是卡组 JSON 对象');
  }
  final deck = DeckDto.fromJson(body);
  try {
    DeckStore.validateKey(deck.deckName);
  } on InvalidDeckKeyException {
    return jsonError(HttpStatus.badRequest, 'deckName 缺失或非法');
  }
  await store.save(deck);
  return jsonSuccess();
}
