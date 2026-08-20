import 'dart:developer' as console;

import 'package:service_loader/service_loader.dart';
import 'package:ygo_card_yugipedia/src/yugipedia_card_service.dart';

export 'src/card_table2_parser.dart';
export 'src/yugipedia_api_client.dart' show YugipediaApiClient;

@Service(YugipediaCardService)
class YugipediaCardService extends CardService {}

@OnServiceRegister()
void onServiceRegister() {
  console.log('ygo_card_yugipedia onServiceRegister');
}
