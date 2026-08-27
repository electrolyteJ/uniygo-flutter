import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  return Response.json(
    body: {
      'service': 'ygo_deck_server',
      'endpoints': [
        'GET /decks',
        'POST /decks',
        'GET /decks/:key',
        'PUT /decks/:key',
        'DELETE /decks/:key',
        'GET /decks/:key/ydk',
        'POST /decks/:key/ydk',
      ],
    },
  );
}
