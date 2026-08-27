import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ygo_deck_server/services/deck_store.dart';
import 'package:ygo_deck_server/services/meta_store.dart';

/// 为 /api/mdpro3/* 路由注入 DeckStore 与市场元数据 MetaStore。
Handler middleware(Handler handler) {
  final dataDir = Platform.environment['DECK_DATA_DIR'] ?? 'data/decks';
  return handler
      .use(provider<DeckStore>((_) => DeckStore(dataDir)))
      .use(provider<MetaStore>((_) => MetaStore('$dataDir/../deck_meta.json')));
}
