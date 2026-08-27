import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ygo_deck_server/http_utils.dart';
import 'package:ygo_deck_server/services/deck_store.dart';

/// GET /decks/:key/ydk —— 导出 YDK（text/plain；IDeckService.exportToYdk）
/// POST /decks/:key/ydk —— 导入 YDK 纯文本并保存（IDeckService.importFromYdk）
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
      return Response(
        body: store.exportYdk(deck),
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    case HttpMethod.post:
      final content = await context.request.body();
      if (content.trim().isEmpty) {
        return jsonError(HttpStatus.badRequest, '请求体必须是 YDK 纯文本');
      }
      final deck = await store.save(store.importYdk(content, name));
      return Response.json(body: deck.toJson());
    default:
      return jsonError(HttpStatus.methodNotAllowed, 'Method not allowed');
  }
}
