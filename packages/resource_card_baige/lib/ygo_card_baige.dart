import 'package:applog/console.dart' as console;

import 'package:service_loader/service_loader.dart';
import 'package:resource_card_baige/src/baige_card_service.dart';

export 'src/baige_api_client.dart' show BaigeApiClient, CardImageCdn;
export 'src/baige_card_service.dart' show BaigeCardService;

@Service(BaigeCardService)
class BaigeCardService extends CardService {}

@OnServiceRegister()
void onServiceRegister() {
  console.log('ygo_card_baige.dart onServiceRegister');
}
