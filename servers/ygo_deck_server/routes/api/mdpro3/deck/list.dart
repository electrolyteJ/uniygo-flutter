import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ygo_deck_server/models/deck_dto.dart';
import 'package:ygo_deck_server/services/deck_store.dart';
import 'package:ygo_deck_server/services/meta_store.dart';

/// GET /api/mdpro3/deck/list —— MDPro3 卡组广场兼容接口。
///
/// 查询参数：page / size / keyWord / sortLike / sortRank / contributor。
/// 返回 DeckListPage JSON：{decks: [...], page, size, total}。
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  final store = context.read<DeckStore>();
  final meta = context.read<MetaStore>();
  final params = context.request.uri.queryParameters;
  final page = int.tryParse(params['page'] ?? '') ?? 1;
  final size = int.tryParse(params['size'] ?? '') ?? 20;
  final keyword = (params['keyWord'] ?? '').trim();
  final sortLike = params['sortLike'] == 'true';
  final contributor = (params['contributor'] ?? '').trim();

  var decks = await store.list();
  if (keyword.isNotEmpty) {
    decks = decks
        .where((d) => d.deckName.contains(keyword))
        .toList();
  }
  if (contributor.isNotEmpty) {
    decks = decks
        .where((d) => meta.contributorOf(d.deckName) == contributor)
        .toList();
  }
  if (sortLike) {
    decks.sort((a, b) =>
        meta.likesOf(b.deckName).compareTo(meta.likesOf(a.deckName)));
  } else {
    // 默认按更新时间倒序（最新）
    decks.sort((a, b) => (b.updatedAt ?? '').compareTo(a.updatedAt ?? ''));
  }

  final total = decks.length;
  final start = (page - 1) * size;
  final items = start >= total ? <DeckDto>[] : decks.sublist(
        start,
        (start + size).clamp(0, total),
      );

  return Response.json(
    body: {
      'decks': [
        for (final deck in items)
          {
            'deckId': deck.deckName,
            'name': deck.deckName,
            'contributor': meta.contributorOf(deck.deckName),
            'likeCount': meta.likesOf(deck.deckName),
            'isPublic': true,
            'rank': 0,
            'coverCode': deck.mainDeck.isEmpty
                ? null
                : deck.mainDeck.first.code,
            'updatedAt': deck.updatedAt,
            'description': '',
          },
      ],
      'page': page,
      'size': size,
      'total': total,
    },
  );
}
