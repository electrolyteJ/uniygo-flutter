import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ygo_deck_server/services/deck_store.dart';
import 'package:ygo_deck_server/services/meta_store.dart';

/// POST /api/mdpro3/deck/like/{id} —— 卡组点赞（MDPro3 兼容）。
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  final meta = context.read<MetaStore>();
  final likes = await meta.addLike(DeckStore.decodeRouteKey(id));
  return Response.json(body: {'success': true, 'likes': likes});
}
