import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ygo_deck_server/services/deck_store.dart';

/// 注入卡组存储（目录可用环境变量 DECK_DATA_DIR 覆盖，默认 data/decks）。
Handler middleware(Handler handler) {
  return handler.use(
    provider<DeckStore>(
      (_) => DeckStore(Platform.environment['DECK_DATA_DIR'] ?? 'data/decks'),
    ),
  );
}
