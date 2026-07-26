// =============================================================================
//     ygo_card_deck — Card CDN + Deck Square API
// =============================================================================
//
//   Usage:
//   ```dart
//   import 'package:ygo_card_deck/ygo_card_deck.dart';
//
//   // 卡片 CDN 接口
//   final cardSvc = CardService();
//   final lflist = await cardSvc.fetchLflist();
//   final db = await cardSvc.downloadDatabase();
//   final imageUrl = cardSvc.getCardImageUrl(89631139);
//
//   // 卡组广场接口
//   final deckSvc = DeckService();
//   final page = await deckSvc.fetchDeckList(page: 1, size: 20);
//   final detail = await deckSvc.fetchDeckDetail(page.decks.first.deckId);
//   ```
// 模型
export 'models/card_info.dart';
export 'models/deck_info.dart';
export 'models/deck_list_page.dart';
export 'models/lflist_info.dart';

// 配置
export 'config/ygo_card_deck_config.dart';

// 客户端 (供需要自定义 http.Client 的场景)
export 'clients/card_api_client.dart';
export 'clients/deck_api_client.dart';

// 服务
export 'services/card_service.dart';
export 'services/deck_service.dart';

// 异常
export 'exceptions/ygo_card_deck_exception.dart';
