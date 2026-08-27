import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ygo_deck_server/http_utils.dart';
import 'package:ygo_deck_server/models/deck_dto.dart';
import 'package:ygo_deck_server/services/deck_store.dart';
import 'package:ygo_deck_server/services/meta_store.dart';

/// POST /api/mdpro3/sync/single —— 上传/发布卡组（MDPro3 兼容）。
/// body: {userId, contributor, deck: {deckId, name, main, extra, side, ...}}
/// DELETE /api/mdpro3/sync/single —— 删除云端卡组（query: deckId）。
Future<Response> onRequest(RequestContext context) async {
  final store = context.read<DeckStore>();
  final meta = context.read<MetaStore>();
  switch (context.request.method) {
    case HttpMethod.post:
      return _upload(context, store, meta);
    case HttpMethod.delete:
      final deckId = context.request.uri.queryParameters['deckId'] ?? '';
      if (deckId.isEmpty) {
        return jsonError(HttpStatus.badRequest, 'deckId 缺失');
      }
      final ok = await store.delete(DeckStore.decodeRouteKey(deckId));
      return ok ? jsonSuccess() : jsonError(HttpStatus.notFound, '卡组不存在');
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

Future<Response> _upload(
  RequestContext context,
  DeckStore store,
  MetaStore meta,
) async {
  final Object? body;
  try {
    body = await context.request.json();
  } on FormatException {
    return jsonError(HttpStatus.badRequest, '请求体不是合法 JSON');
  }
  if (body is! Map<String, dynamic>) {
    return jsonError(HttpStatus.badRequest, '请求体必须是 JSON 对象');
  }
  final deckJson = body['deck'];
  if (deckJson is! Map<String, dynamic>) {
    return jsonError(HttpStatus.badRequest, 'deck 缺失');
  }
  // MDPro3 协议：deck 内的键是 name/main/extra/side
  final name = (deckJson['name'] ?? deckJson['deckId'] ?? '') as String;
  if (name.isEmpty) {
    return jsonError(HttpStatus.badRequest, '卡组名缺失');
  }
  final deck = DeckDto.fromJson({
    'deckName': name,
    'mainDeck': deckJson['main'],
    'extraDeck': deckJson['extra'],
    'sideDeck': deckJson['side'],
  });
  await store.save(deck);
  final contributor = (body['contributor'] ?? '') as String;
  await meta.setContributor(name, contributor);
  return jsonSuccess({'deckId': name});
}
