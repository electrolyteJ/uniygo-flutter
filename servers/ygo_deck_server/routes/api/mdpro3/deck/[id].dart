import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ygo_deck_server/http_utils.dart';
import 'package:ygo_deck_server/services/deck_store.dart';
import 'package:ygo_deck_server/services/meta_store.dart';

/// GET /api/mdpro3/deck/{id} —— 卡组详情（MDPro3 兼容）。
/// 特例：id = "deckId" 时生成新卡组 ID（MDPro3 的 id 生成端点）。
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  // MDPro3 协议特例：/deck/deckId 返回新 ID
  if (id == 'deckId') {
    return Response.json(body: {
      'deckId': DateTime.now().microsecondsSinceEpoch.toString(),
    });
  }
  final store = context.read<DeckStore>();
  final meta = context.read<MetaStore>();
  final deck = await store.read(DeckStore.decodeRouteKey(id));
  if (deck == null) {
    return jsonError(HttpStatus.notFound, '卡组不存在');
  }
  return Response.json(
    body: {
      'deckId': deck.deckName,
      'name': deck.deckName,
      'contributor': meta.contributorOf(deck.deckName),
      'userId': 0,
      'mainDeck': deck.mainDeck.map((c) => c.toJson()).toList(),
      'extraDeck': deck.extraDeck.map((c) => c.toJson()).toList(),
      'sideDeck': deck.sideDeck.map((c) => c.toJson()).toList(),
      'likeCount': meta.likesOf(deck.deckName),
      'isPublic': true,
      'rank': 0,
      'updatedAt': deck.updatedAt,
      'description': '',
      'coverCode':
          deck.mainDeck.isEmpty ? null : deck.mainDeck.first.code,
    },
  );
}
