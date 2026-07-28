// =============================================================================
//     ygo_card_deck — Card CDN + Deck Square API
// =============================================================================
//
//   Usage:
//   ```dart
//   import 'package:ygo_card_deck/ygo_card_mycard.dart';
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
import 'package:service_loader/service_loader.dart';
import 'package:ygo_card/ygo_card.dart';
import 'package:ygo_card_mycard/src/card_database.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';
import 'src/card_service.dart';
export 'src/env_config.dart';


void registerMyCardCardService() {
  var cardService = CardService(config: EnvConfig.production);
  registerCardService(ServiceType.mycard, () => cardService);

}