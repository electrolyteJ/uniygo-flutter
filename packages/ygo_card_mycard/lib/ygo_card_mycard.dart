// =============================================================================
//     ygo_card_mycard — Card CDN + Deck Square API
// =============================================================================
//
//   Usage:
//   ```dart
//   import 'package:ygo_card_mycard/ygo_card_mycard.dart';
//
//   // 卡片 CDN 接口
//   final cardSvc = CardService();
//   final lflist = await cardSvc.fetchLflist();
//   final imageUrl = cardSvc.getCardImageUrl(89631139);
//   ```
//
//   服务实例统一通过 `registerAllServices()` 编译期注册后，
//   由 ServiceFactory 创建（见 service_loader 包）。
import 'dart:developer' as console;

import 'package:service_loader/service_loader.dart';
import 'package:ygo_card_mycard/src/card_service.dart';
import 'package:ygo_card_mycard/ygo_card_mycard.dart';

export 'src/env_config.dart';


/// 生产环境卡片服务工厂。
///
/// [CardService] 需要 [EnvConfig] 构造参数，无法直接无参构造，
/// 因此以顶层函数形式标注 [ServiceRegister]。
@ServiceRegister(CardService)
CardService createMyCardCardService() {
  return CardService(config: EnvConfig.production);
}



class CardService extends BaseCardService {
  CardService({required EnvConfig config}) : super(config: config);
}
