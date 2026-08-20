import 'dart:developer' as console;

import 'package:service_loader/service_loader.dart';
import 'package:ygo_card_ygoprodeck/src/ygoprodeck_card_service.dart';

export 'src/ocg_strings.dart';
export 'src/ygoprodeck_api_client.dart' show YgoprodeckApiClient;

@Service(YgoprodeckCardService)
class YgoprodeckCardService extends CardService {}

@OnServiceRegister()
void onServiceRegister() {
  console.log('ygo_card_ygoprodeck onServiceRegister');
}
